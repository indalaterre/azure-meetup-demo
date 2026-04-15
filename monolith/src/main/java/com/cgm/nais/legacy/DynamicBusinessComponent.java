package com.cgm.nais.legacy;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

/**
 * A business component that is loaded dynamically via Class.forName().
 * It is NOT annotated with @RegisterForReflection on purpose,
 * so GraalVM native-image will fail to discover it.
 */
public class DynamicBusinessComponent {

    private String componentId;
    private String status;
    private LocalDateTime initializedAt;

    public DynamicBusinessComponent() {
        this.componentId = "BIZ-" + System.currentTimeMillis();
        this.status = "INITIALIZED";
        this.initializedAt = LocalDateTime.now();
    }

    public Map<String, Object> executeBusinessLogic(String operation) {
        Map<String, Object> result = new HashMap<>();
        result.put("componentId", componentId);
        result.put("operation", operation);
        result.put("status", status);
        result.put("initializedAt", initializedAt.toString());
        result.put("message", "Legacy business logic executed for operation: " + operation);

        // Use LegacyIntrospector to deep-introspect ourselves — more reflection chaos
        Map<String, Object> introspection = LegacyIntrospector.deepIntrospect(this);
        result.put("introspection", introspection);

        return result;
    }

    public String getComponentId() {
        return componentId;
    }

    public String getStatus() {
        return status;
    }

    public LocalDateTime getInitializedAt() {
        return initializedAt;
    }
}
