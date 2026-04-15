# Aggiorniamo le variabili
RG_NAME="GlobalAzurePuglia-RG"
LOCATION="northeurope"
ACR_NAME="acrquarkusmauro76735"

# 1. Rimuoviamo il Resource Group sporco (se esiste) per evitare conflitti
az group delete --name $RG_NAME --yes --no-wait

# 2. Creazione Resource Group in North Europe
echo "Creazione Resource Group in $LOCATION..."
az group create --name $RG_NAME --location $LOCATION

# 3. Creazione del Container Registry
echo "Creazione Container Registry..."
az acr create --resource-group $RG_NAME \
  --name $ACR_NAME \
  --sku Basic \
  --admin-enabled true