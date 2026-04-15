package com.cgm.nais.legacy;

import org.apache.commons.beanutils.BeanUtils;
import org.apache.commons.beanutils.PropertyUtils;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.util.HashMap;
import java.util.Map;

/**
 * LEGACY CLASS — Intentionally breaks GraalVM native-image compilation.
 *
 * This class uses:
 *   1. Apache Commons BeanUtils (old 1.8.3, no GraalVM reachability metadata)
 *   2. Class.forName() for dynamic class loading at runtime
 *   3. Reflective field/method access without @RegisterForReflection
 *   4. Dynamic JDK Proxy creation at runtime
 *
 * All of the above are hostile to ahead-of-time compilation in GraalVM native image.
 */
public class LegacyIntrospector {

    /**
     * Copies all properties from source bean to target bean using Apache Commons BeanUtils.
     * BeanUtils internally uses heavy reflection that is NOT registered for native image.
     */
    public static void copyBeanProperties(Object source, Object target) {
        try {
            java.beans.PropertyDescriptor[] descriptors = PropertyUtils.getPropertyDescriptors(source);
            for (java.beans.PropertyDescriptor descriptor : descriptors) {
                String name = descriptor.getName();
                if ("class".equals(name)) continue;
                if (!PropertyUtils.isWriteable(target, name)) continue;
                if (!PropertyUtils.isReadable(source, name)) continue;
                Object value = PropertyUtils.getSimpleProperty(source, name);
                if (value != null) {
                    BeanUtils.setProperty(target, name, value);
                }
            }
        } catch (Exception e) {
            throw new RuntimeException("Legacy BeanUtils copy failed", e);
        }
    }

    /**
     * Dynamically reads all properties from a bean via PropertyUtils (reflection-based).
     */
    public static Map<String, Object> describeBean(Object bean) {
        try {
            @SuppressWarnings("unchecked")
            Map<String, Object> properties = PropertyUtils.describe(bean);
            return properties;
        } catch (Exception e) {
            throw new RuntimeException("Legacy bean introspection failed", e);
        }
    }

    /**
     * Loads a class by fully qualified name at runtime using Class.forName().
     * GraalVM native-image cannot resolve this at build time.
     */
    public static Object instantiateByName(String className) {
        try {
            Class<?> clazz = Class.forName(className);
            return clazz.getDeclaredConstructor().newInstance();
        } catch (Exception e) {
            throw new RuntimeException("Dynamic instantiation failed for: " + className, e);
        }
    }

    /**
     * Uses raw reflection to enumerate all declared fields and methods of a class.
     * Accesses private fields by toggling accessibility — not native-friendly.
     */
    public static Map<String, Object> deepIntrospect(Object target) {
        Map<String, Object> result = new HashMap<>();
        Class<?> clazz = target.getClass();

        for (Field field : clazz.getDeclaredFields()) {
            field.setAccessible(true);
            try {
                result.put("field:" + field.getName(), field.get(target));
            } catch (IllegalAccessException e) {
                result.put("field:" + field.getName(), "ACCESS_DENIED");
            }
        }

        for (Method method : clazz.getDeclaredMethods()) {
            result.put("method:" + method.getName(), method.getReturnType().getSimpleName());
        }

        return result;
    }

    /**
     * Creates a dynamic JDK Proxy at runtime.
     * Without explicit proxy configuration, native-image cannot handle this.
     */
    @SuppressWarnings("unchecked")
    public static <T> T createDynamicProxy(Class<T> iface, Object handler) {
        return (T) Proxy.newProxyInstance(
                iface.getClassLoader(),
                new Class<?>[]{iface},
                (proxy, method, args) -> {
                    System.out.println("[LegacyProxy] Intercepted call to: " + method.getName());
                    return method.invoke(handler, args);
                }
        );
    }
}
