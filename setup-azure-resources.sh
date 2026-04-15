#!/bin/bash
set -e

# =============================================================================
# Setup Azure Resources for Legacy Monolith / Microservices Demo
# =============================================================================
# Deploys:
#   - ca-monolith-jvm     (monolith, JVM build)       — external ingress
#   - ca-monolith-native  (monolith, native build)     — external ingress
#   - ca-user-service     (microservice)               — external ingress
#   - ca-order-service    (microservice, calls user)   — external ingress
#
# Microservices communicate via internal FQDN within the Container Apps Environment.
# =============================================================================

# ========================== CONFIGURATION ==========================

RG_NAME="GlobalAzurePuglia-RG"
LOCATION="italynorth"
ACR_NAME="acrglobalazurepuglia"
KV_NAME="kv-globalazure-puglia"
DB_SERVER_NAME="pg-globalazure-puglia"
DB_ADMIN_USER="GlobalAzurePugliaRG2026"
DB_PASSWORD="P@ssw0rd2026!"
CONTAINER_APP_ENV_NAME="cae-globalazure-puglia"

# Database names
DB_MONOLITH="legacymonolith"
DB_USERS="usersdb"
DB_ORDERS="ordersdb"

# Container App names
CA_MONOLITH_JVM="ca-monolith-jvm"
CA_MONOLITH_NATIVE="ca-monolith-native"
CA_USER_SERVICE="ca-user-service"
CA_ORDER_SERVICE="ca-order-service"

# Networking
VNET_NAME="vnet-globalazure-puglia"
VNET_CIDR="10.0.0.0/16"
SUBNET_APPS="snet-container-apps"
SUBNET_APPS_CIDR="10.0.0.0/23"
SUBNET_DB="snet-postgresql"
SUBNET_DB_CIDR="10.0.2.0/24"
DNS_ZONE_NAME="privatelink.postgres.database.azure.com"

# ========================== 0. RESOURCE PROVIDERS ==========================

echo "=========================================="
echo "0. Registrazione Resource Providers necessari"
echo "=========================================="
for PROVIDER in "Microsoft.OperationalInsights" "Microsoft.App" "Microsoft.ContainerRegistry" "Microsoft.Network"; do
    STATUS=$(az provider show --namespace "$PROVIDER" --query registrationState -o tsv 2>/dev/null)
    if [ "$STATUS" == "Registered" ]; then
        echo "   $PROVIDER già registrato. Skip."
    else
        echo "   Registrazione $PROVIDER..."
        az provider register -n "$PROVIDER" --wait
        echo "   $PROVIDER registrato."
    fi
done

# ========================== 1. RESOURCE GROUP ==========================

echo ""
echo "=========================================="
echo "1. Creazione Resource Group: $RG_NAME"
echo "=========================================="
if az group show --name "$RG_NAME" &>/dev/null; then
    echo "   Resource Group '$RG_NAME' esiste già. Skip."
else
    az group create --name "$RG_NAME" --location "$LOCATION"
    echo "   Resource Group '$RG_NAME' creato in $LOCATION."
fi

# ========================== 2. VIRTUAL NETWORK ==========================

echo ""
echo "=========================================="
echo "2. Creazione VNet e Subnet: $VNET_NAME"
echo "=========================================="
if az network vnet show --name "$VNET_NAME" --resource-group "$RG_NAME" &>/dev/null; then
    echo "   VNet '$VNET_NAME' esiste già. Skip."
else
    az network vnet create \
        --resource-group "$RG_NAME" \
        --name "$VNET_NAME" \
        --location "$LOCATION" \
        --address-prefix "$VNET_CIDR"
    echo "   VNet '$VNET_NAME' creata."
fi

# Subnet per Container Apps
if az network vnet subnet show --resource-group "$RG_NAME" --vnet-name "$VNET_NAME" --name "$SUBNET_APPS" &>/dev/null; then
    echo "   Subnet '$SUBNET_APPS' esiste già. Skip."
else
    az network vnet subnet create \
        --resource-group "$RG_NAME" \
        --vnet-name "$VNET_NAME" \
        --name "$SUBNET_APPS" \
        --address-prefix "$SUBNET_APPS_CIDR" \
        --delegations Microsoft.App/environments
    echo "   Subnet '$SUBNET_APPS' creata con delega a Container Apps."
fi

# Subnet per PostgreSQL (delegata a Microsoft.DBforPostgreSQL/flexibleServers)
if az network vnet subnet show --resource-group "$RG_NAME" --vnet-name "$VNET_NAME" --name "$SUBNET_DB" &>/dev/null; then
    echo "   Subnet '$SUBNET_DB' esiste già. Skip."
else
    az network vnet subnet create \
        --resource-group "$RG_NAME" \
        --vnet-name "$VNET_NAME" \
        --name "$SUBNET_DB" \
        --address-prefix "$SUBNET_DB_CIDR" \
        --delegations Microsoft.DBforPostgreSQL/flexibleServers
    echo "   Subnet '$SUBNET_DB' creata con delega a PostgreSQL."
fi

SUBNET_APPS_ID=$(az network vnet subnet show --resource-group "$RG_NAME" --vnet-name "$VNET_NAME" --name "$SUBNET_APPS" --query id -o tsv)
SUBNET_DB_ID=$(az network vnet subnet show --resource-group "$RG_NAME" --vnet-name "$VNET_NAME" --name "$SUBNET_DB" --query id -o tsv)
DNS_ZONE_ID=$(az network private-dns zone show --resource-group "$RG_NAME" --name "$DNS_ZONE_NAME" --query id -o tsv 2>/dev/null || echo "")

# ========================== 3. PRIVATE DNS ZONE ==========================

echo ""
echo "=========================================="
echo "3. Creazione Private DNS Zone per PostgreSQL"
echo "=========================================="
if az network private-dns zone show --resource-group "$RG_NAME" --name "$DNS_ZONE_NAME" &>/dev/null; then
    echo "   Private DNS Zone '$DNS_ZONE_NAME' esiste già. Skip."
else
    az network private-dns zone create \
        --resource-group "$RG_NAME" \
        --name "$DNS_ZONE_NAME"
    echo "   Private DNS Zone '$DNS_ZONE_NAME' creata."
fi

# Link della DNS Zone alla VNet
if az network private-dns link vnet show --resource-group "$RG_NAME" --zone-name "$DNS_ZONE_NAME" --name "${VNET_NAME}-link" &>/dev/null; then
    echo "   DNS Zone link esiste già. Skip."
else
    az network private-dns link vnet create \
        --resource-group "$RG_NAME" \
        --zone-name "$DNS_ZONE_NAME" \
        --name "${VNET_NAME}-link" \
        --virtual-network "$VNET_NAME" \
        --registration-enabled false
    echo "   DNS Zone linkata a '$VNET_NAME'."
fi

# Refresh DNS Zone ID (potrebbe essere stato creato sopra)
DNS_ZONE_ID=$(az network private-dns zone show --resource-group "$RG_NAME" --name "$DNS_ZONE_NAME" --query id -o tsv)

# ========================== 4. CONTAINER REGISTRY ==========================

echo ""
echo "=========================================="
echo "4. Creazione Azure Container Registry: $ACR_NAME"
echo "=========================================="
if az acr show --name "$ACR_NAME" --resource-group "$RG_NAME" &>/dev/null; then
    echo "   ACR '$ACR_NAME' esiste già. Skip."
else
    az acr create \
        --resource-group "$RG_NAME" \
        --name "$ACR_NAME" \
        --sku Basic \
        --admin-enabled true
    echo "   ACR '$ACR_NAME' creato con admin abilitato."
fi

ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --resource-group "$RG_NAME" --query loginServer -o tsv)
echo "   Login Server: $ACR_LOGIN_SERVER"

# ========================== 5. POSTGRESQL FLEXIBLE SERVER ==========================

echo ""
echo "=========================================="
echo "5. Creazione Azure Database for PostgreSQL: $DB_SERVER_NAME"
echo "=========================================="
if az postgres flexible-server show --name "$DB_SERVER_NAME" --resource-group "$RG_NAME" &>/dev/null; then
    echo "   PostgreSQL Server '$DB_SERVER_NAME' esiste già. Skip."
else
    az postgres flexible-server create \
        --resource-group "$RG_NAME" \
        --name "$DB_SERVER_NAME" \
        --location "$LOCATION" \
        --admin-user "$DB_ADMIN_USER" \
        --admin-password "$DB_PASSWORD" \
        --sku-name Standard_B1ms \
        --tier Burstable \
        --storage-size 32 \
        --version 16 \
        --subnet "$SUBNET_DB_ID" \
        --private-dns-zone "$DNS_ZONE_ID" \
        --yes
    echo "   PostgreSQL Server '$DB_SERVER_NAME' creato con accesso privato."
fi

DB_FQDN=$(az postgres flexible-server show --name "$DB_SERVER_NAME" --resource-group "$RG_NAME" --query fullyQualifiedDomainName -o tsv)
echo "   FQDN: $DB_FQDN"

# Crea i database per ogni applicazione
for DB in "$DB_MONOLITH" "$DB_USERS" "$DB_ORDERS"; do
    if az postgres flexible-server db show \
        --resource-group "$RG_NAME" \
        --server-name "$DB_SERVER_NAME" \
        --database-name "$DB" &>/dev/null; then
        echo "   Database '$DB' esiste già. Skip."
    else
        echo "   Creazione database '$DB'..."
        az postgres flexible-server db create \
            --resource-group "$RG_NAME" \
            --server-name "$DB_SERVER_NAME" \
            --database-name "$DB"
        echo "   Database '$DB' creato."
    fi
done

JDBC_MONOLITH="jdbc:postgresql://${DB_FQDN}:5432/${DB_MONOLITH}?sslmode=require"
JDBC_USERS="jdbc:postgresql://${DB_FQDN}:5432/${DB_USERS}?sslmode=require"
JDBC_ORDERS="jdbc:postgresql://${DB_FQDN}:5432/${DB_ORDERS}?sslmode=require"
echo "   JDBC Monolith: $JDBC_MONOLITH"
echo "   JDBC Users:    $JDBC_USERS"
echo "   JDBC Orders:   $JDBC_ORDERS"

# ========================== 6. KEY VAULT ==========================

echo ""
echo "=========================================="
echo "6. Creazione Azure Key Vault: $KV_NAME"
echo "=========================================="
if az keyvault show --name "$KV_NAME" --resource-group "$RG_NAME" &>/dev/null; then
    echo "   Key Vault '$KV_NAME' esiste già. Skip."
else
    az keyvault create \
        --resource-group "$RG_NAME" \
        --name "$KV_NAME" \
        --location "$LOCATION" \
        --enable-rbac-authorization false
    echo "   Key Vault '$KV_NAME' creato."
fi

if az keyvault secret show --vault-name "$KV_NAME" --name "db-password" &>/dev/null; then
    echo "   Segreto 'db-password' esiste già. Skip."
else
    echo "   Inserimento segreto 'db-password'..."
    for i in 1 2 3; do
        if az keyvault secret set \
            --vault-name "$KV_NAME" \
            --name "db-password" \
            --value "$DB_PASSWORD" \
            --output none 2>/dev/null; then
            echo "   Segreto 'db-password' inserito."
            break
        else
            echo "   Tentativo $i fallito (SSL error?). Attendo 5s e riprovo..."
            sleep 5
        fi
    done
fi

# ========================== 7. CONTAINER APP ENVIRONMENT (VNet) ==========================

echo ""
echo "=========================================="
echo "7. Creazione Container Apps Environment: $CONTAINER_APP_ENV_NAME"
echo "=========================================="
if az containerapp env show --name "$CONTAINER_APP_ENV_NAME" --resource-group "$RG_NAME" &>/dev/null; then
    echo "   Container Apps Environment '$CONTAINER_APP_ENV_NAME' esiste già. Skip."
else
    az containerapp env create \
        --resource-group "$RG_NAME" \
        --name "$CONTAINER_APP_ENV_NAME" \
        --location "$LOCATION" \
        --infrastructure-subnet-resource-id "$SUBNET_APPS_ID"
    echo "   Container Apps Environment '$CONTAINER_APP_ENV_NAME' creato nella VNet."
fi

# ========================== HELPER FUNCTIONS ==========================

create_container_app() {
    local APP_NAME=$1
    local INGRESS_TYPE=$2    # "external" or "internal"
    local TARGET_PORT=$3
    local IMAGE=$4           # ACR image (e.g. acr.azurecr.io/group/name:tag)

    echo ""
    echo "   Creazione/Aggiornamento Container App: $APP_NAME (ingress: $INGRESS_TYPE, image: $IMAGE)"
    local ACR_PASSWORD
    ACR_PASSWORD=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" -o tsv)

    if az containerapp show --name "$APP_NAME" --resource-group "$RG_NAME" &>/dev/null; then
        echo "   '$APP_NAME' esiste già. Configurazione registry e aggiornamento immagine..."
        az containerapp registry set \
            --resource-group "$RG_NAME" \
            --name "$APP_NAME" \
            --server "$ACR_LOGIN_SERVER" \
            --username "$ACR_NAME" \
            --password "$ACR_PASSWORD" \
            --output none
        az containerapp update \
            --resource-group "$RG_NAME" \
            --name "$APP_NAME" \
            --image "$IMAGE" \
            --output none
        echo "   Immagine aggiornata a '$IMAGE'."
    else
        az containerapp create \
            --resource-group "$RG_NAME" \
            --name "$APP_NAME" \
            --environment "$CONTAINER_APP_ENV_NAME" \
            --image "$IMAGE" \
            --registry-server "$ACR_LOGIN_SERVER" \
            --registry-username "$ACR_NAME" \
            --registry-password "$ACR_PASSWORD" \
            --target-port "$TARGET_PORT" \
            --ingress "$INGRESS_TYPE" \
            --min-replicas 0 \
            --max-replicas 1
        echo "   '$APP_NAME' creato con immagine '$IMAGE'."
    fi

    # Abilita System-Assigned Managed Identity
    echo "   Abilitazione Managed Identity per '$APP_NAME'..."
    az containerapp identity assign \
        --resource-group "$RG_NAME" \
        --name "$APP_NAME" \
        --system-assigned \
        --output none

    # Assegna ruolo RBAC "Key Vault Secrets User" sulla Managed Identity
    local PRINCIPAL_ID
    PRINCIPAL_ID=$(az containerapp identity show \
        --resource-group "$RG_NAME" \
        --name "$APP_NAME" \
        --query principalId -o tsv)
    echo "   Principal ID ($APP_NAME): $PRINCIPAL_ID"

    local KV_ID
    KV_ID=$(az keyvault show --name "$KV_NAME" --resource-group "$RG_NAME" --query id -o tsv)

    az role assignment create \
        --role "Key Vault Secrets User" \
        --assignee-object-id "$PRINCIPAL_ID" \
        --assignee-principal-type ServicePrincipal \
        --scope "$KV_ID" \
        --output none 2>/dev/null || echo "   Ruolo già assegnato."
    echo "   Ruolo 'Key Vault Secrets User' assegnato per '$APP_NAME'."

    # Configura Health Probes (SmallRye Health endpoints)
    echo "   Configurazione health probes per '$APP_NAME'..."
    local CONTAINER_NAME
    CONTAINER_NAME=$(az containerapp show \
        --resource-group "$RG_NAME" \
        --name "$APP_NAME" \
        --query "properties.template.containers[0].name" -o tsv)

    local YAML_FILE="/tmp/${APP_NAME}-probes.yaml"
    cat > "$YAML_FILE" <<EOF
properties:
  template:
    containers:
      - name: ${CONTAINER_NAME}
        image: ${IMAGE}
        probes:
          - type: Liveness
            httpGet:
              path: /q/health/live
              port: ${TARGET_PORT}
            initialDelaySeconds: 5
            periodSeconds: 10
            failureThreshold: 3
          - type: Readiness
            httpGet:
              path: /q/health/ready
              port: ${TARGET_PORT}
            initialDelaySeconds: 5
            periodSeconds: 10
            failureThreshold: 3
          - type: Startup
            httpGet:
              path: /q/health/started
              port: ${TARGET_PORT}
            initialDelaySeconds: 3
            periodSeconds: 5
            failureThreshold: 10
EOF

    az containerapp update \
        --resource-group "$RG_NAME" \
        --name "$APP_NAME" \
        --yaml "$YAML_FILE" \
        --output none
    rm -f "$YAML_FILE"
    echo "   Health probes configurate (liveness: /q/health/live, readiness: /q/health/ready, startup: /q/health/started)."
}

configure_env_vars() {
    local APP_NAME=$1
    shift
    echo "   Configurazione variabili d'ambiente per '$APP_NAME'..."
    az containerapp update \
        --resource-group "$RG_NAME" \
        --name "$APP_NAME" \
        --set-env-vars "$@" \
        --output none
    echo "   Variabili configurate per '$APP_NAME'."
}

# ========================== 6. MONOLITH JVM ==========================

echo ""
echo "=========================================="
echo "8. Deploy Monolith (JVM): $CA_MONOLITH_JVM"
echo "=========================================="
create_container_app "$CA_MONOLITH_JVM" "external" 10990 "$ACR_LOGIN_SERVER/legacy-monolith/legacy-monolith:jvm"

KV_ENDPOINT="https://${KV_NAME}.vault.azure.net"

configure_env_vars "$CA_MONOLITH_JVM" \
    "QUARKUS_AZURE_KEYVAULT_SECRET_ENDPOINT=$KV_ENDPOINT" \
    "QUARKUS_DATASOURCE_JDBC_URL=$JDBC_MONOLITH" \
    "QUARKUS_DATASOURCE_USERNAME=$DB_ADMIN_USER" \
    "QUARKUS_DATASOURCE_PASSWORD=\${kv//db-password}"

# ========================== 7. MONOLITH NATIVE ==========================

echo ""
echo "=========================================="
echo "9. Deploy Monolith (Native): $CA_MONOLITH_NATIVE"
echo "=========================================="
create_container_app "$CA_MONOLITH_NATIVE" "external" 10990 "$ACR_LOGIN_SERVER/legacy-monolith/legacy-monolith:native"

configure_env_vars "$CA_MONOLITH_NATIVE" \
    "QUARKUS_AZURE_KEYVAULT_SECRET_ENDPOINT=$KV_ENDPOINT" \
    "QUARKUS_DATASOURCE_JDBC_URL=$JDBC_MONOLITH" \
    "QUARKUS_DATASOURCE_USERNAME=$DB_ADMIN_USER" \
    "QUARKUS_DATASOURCE_PASSWORD=\${kv//db-password}"

# ========================== 8. USER SERVICE ==========================

echo ""
echo "=========================================="
echo "10. Deploy User Service: $CA_USER_SERVICE"
echo "=========================================="
create_container_app "$CA_USER_SERVICE" "external" 8081 "$ACR_LOGIN_SERVER/microservices/user-service:latest"

configure_env_vars "$CA_USER_SERVICE" \
    "QUARKUS_AZURE_KEYVAULT_SECRET_ENDPOINT=$KV_ENDPOINT" \
    "QUARKUS_DATASOURCE_JDBC_URL=$JDBC_USERS" \
    "QUARKUS_DATASOURCE_USERNAME=$DB_ADMIN_USER" \
    "QUARKUS_DATASOURCE_PASSWORD=\${kv//db-password}"

# ========================== 9. ORDER SERVICE ==========================

echo ""
echo "=========================================="
echo "11. Deploy Order Service: $CA_ORDER_SERVICE"
echo "=========================================="
create_container_app "$CA_ORDER_SERVICE" "external" 8082 "$ACR_LOGIN_SERVER/microservices/order-service:latest"

# L'order-service comunica con user-service tramite il nome interno.
# In Container Apps, i servizi nello stesso environment si raggiungono via: http://<app-name>:<port>
USER_SERVICE_INTERNAL_URL="http://${CA_USER_SERVICE}"
echo "   User Service internal URL: $USER_SERVICE_INTERNAL_URL"

configure_env_vars "$CA_ORDER_SERVICE" \
    "QUARKUS_AZURE_KEYVAULT_SECRET_ENDPOINT=$KV_ENDPOINT" \
    "QUARKUS_DATASOURCE_JDBC_URL=$JDBC_ORDERS" \
    "QUARKUS_DATASOURCE_USERNAME=$DB_ADMIN_USER" \
    "QUARKUS_DATASOURCE_PASSWORD=\${kv//db-password}" \
    "QUARKUS_REST_CLIENT_USER_SERVICE_URL=$USER_SERVICE_INTERNAL_URL"

# ========================== 10. OUTPUT FINALE ==========================

echo ""
echo "=========================================="
echo "  12. SETUP COMPLETATO!"
echo "=========================================="

FQDN_MONOLITH_JVM=$(az containerapp show --resource-group "$RG_NAME" --name "$CA_MONOLITH_JVM" --query properties.configuration.ingress.fqdn -o tsv)
FQDN_MONOLITH_NATIVE=$(az containerapp show --resource-group "$RG_NAME" --name "$CA_MONOLITH_NATIVE" --query properties.configuration.ingress.fqdn -o tsv)
FQDN_USER_SERVICE=$(az containerapp show --resource-group "$RG_NAME" --name "$CA_USER_SERVICE" --query properties.configuration.ingress.fqdn -o tsv)
FQDN_ORDER_SERVICE=$(az containerapp show --resource-group "$RG_NAME" --name "$CA_ORDER_SERVICE" --query properties.configuration.ingress.fqdn -o tsv)

echo ""
echo "  ACR Login Server:        https://$ACR_LOGIN_SERVER"
echo "  Key Vault:               $KV_NAME"
echo "  PostgreSQL Server:       $DB_FQDN"
echo ""
echo "  ---- Container Apps ----"
echo "  Monolith (JVM):          https://$FQDN_MONOLITH_JVM"
echo "  Monolith (Native):       https://$FQDN_MONOLITH_NATIVE"
echo "  User Service:            https://$FQDN_USER_SERVICE"
echo "  Order Service:           https://$FQDN_ORDER_SERVICE"
echo "  User Service (internal): $USER_SERVICE_INTERNAL_URL"
echo ""
echo "  ---- Comandi per il deploy delle immagini ----"
echo ""
echo "  # Login ACR"
echo "  az acr login --name $ACR_NAME"
echo ""
echo "  # Build & push monolith JVM"
echo "  mvn package -Dquarkus.profile=jvm -Dquarkus.container-image.build=true -Dquarkus.container-image.push=true -pl monolith"
echo "  az containerapp update -g $RG_NAME -n $CA_MONOLITH_JVM --image $ACR_LOGIN_SERVER/legacy-monolith/legacy-monolith:jvm"
echo ""
echo "  # Build & push monolith Native (fallirà per la demo!)"
echo "  mvn package -Pnative -Dquarkus.profile=native -Dquarkus.native.container-build=true -Dquarkus.container-image.build=true -Dquarkus.container-image.push=true -pl monolith"
echo "  az containerapp update -g $RG_NAME -n $CA_MONOLITH_NATIVE --image $ACR_LOGIN_SERVER/legacy-monolith/legacy-monolith:native"
echo ""
echo "  # Build & push user-service"
echo "  mvn package -Dquarkus.container-image.build=true -Dquarkus.container-image.push=true -pl microservices/user-service"
echo "  az containerapp update -g $RG_NAME -n $CA_USER_SERVICE --image $ACR_LOGIN_SERVER/microservices/user-service:latest"
echo ""
echo "  # Build & push order-service"
echo "  mvn package -Dquarkus.container-image.build=true -Dquarkus.container-image.push=true -pl microservices/order-service"
echo "  az containerapp update -g $RG_NAME -n $CA_ORDER_SERVICE --image $ACR_LOGIN_SERVER/microservices/order-service:latest"
echo ""
