package com.cgm.nais.service;

import com.cgm.nais.entity.Order;
import com.cgm.nais.entity.User;
import com.cgm.nais.legacy.LegacyIntrospector;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

/**
 * Monolithic service that manages both Users and Orders.
 * Intentionally couples everything together — the classic legacy anti-pattern.
 */
@ApplicationScoped
public class MonolithService {

    // ========================== USER OPERATIONS ==========================

    @Transactional
    public User createUser(User user) {
        user.persist();
        return user;
    }

    public List<User> listAllUsers() {
        return User.listAll();
    }

    public User findUserById(Long id) {
        return User.findById(id);
    }

    @Transactional
    public User updateUser(Long id, User updated) {
        User existing = User.findById(id);
        if (existing == null) {
            throw new RuntimeException("User not found: " + id);
        }
        // Use legacy BeanUtils to copy properties — reflection-heavy
        LegacyIntrospector.copyBeanProperties(updated, existing);
        return existing;
    }

    @Transactional
    public void deleteUser(Long id) {
        User.deleteById(id);
    }

    // ========================== ORDER OPERATIONS ==========================

    @Transactional
    public Order createOrder(Long userId, String product, int quantity, BigDecimal totalPrice) {
        User user = User.findById(userId);
        /*if (user == null) {
            throw new RuntimeException("Cannot create order: user not found: " + userId);
        }*/

        Order order = new Order();
        order.userId = userId;
        order.product = product;
        order.quantity = quantity;
        order.totalPrice = totalPrice;
        order.status = "PENDING";
        order.createdAt = LocalDateTime.now();
        order.persist();

        // Legacy: introspect the order for "audit logging" via reflection
        Map<String, Object> audit = LegacyIntrospector.describeBean(order);
        System.out.println("[LEGACY AUDIT] Order created: " + audit);

        // Legacy: log DTO field names via Class.forName() — breaks native
        try {
            System.out.println("[LEGACY AUDIT] Looking for class: com.cgm.nais.legacy.NoReflectionExample");
            Class<?> dtoClass = Class.forName("com.cgm.nais.legacy.NoReflectionExample");
            System.out.println("[LEGACY AUDIT] Found class: " + dtoClass.getName());
            java.lang.reflect.Field[] fields = dtoClass.getDeclaredFields();
            System.out.println("[LEGACY AUDIT] Found " + fields.length + " fields");
            if(fields.length == 0) {
                throw new RuntimeException("Legacy DTO introspection failed");
            }
            System.out.println("[LEGACY AUDIT] Found " + fields.length + " fields");
            for (java.lang.reflect.Field f : fields) {
                f.setAccessible(true);
                System.out.println("[LEGACY AUDIT] DTO field: " + f.getName() + " (type=" + f.getType().getSimpleName() + ")");
            }
        } catch (Exception e) {
            System.out.println("[LEGACY AUDIT] Failed looking for class: com.cgm.nais.legacy.NoReflectionExample");
            throw new RuntimeException("Legacy DTO introspection failed: " + e.getMessage(), e);
        }

        return order;
    }

    public List<Order> listAllOrders() {
        return Order.listAll();
    }

    public List<Order> findOrdersByUser(Long userId) {
        return Order.list("userId", userId);
    }

    public Order findOrderById(Long id) {
        return Order.findById(id);
    }

    @Transactional
    public Order updateOrderStatus(Long orderId, String newStatus) {
        Order order = Order.findById(orderId);
        if (order == null) {
            throw new RuntimeException("Order not found: " + orderId);
        }
        order.status = newStatus;
        return order;
    }

    @Transactional
    public void deleteOrder(Long id) {
        Order.deleteById(id);
    }
}
