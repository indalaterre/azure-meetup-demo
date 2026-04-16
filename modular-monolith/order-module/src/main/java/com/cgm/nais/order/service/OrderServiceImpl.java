package com.cgm.nais.order.service;

import com.cgm.nais.order.entity.Order;
import com.cgm.nais.user.service.UserService;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@ApplicationScoped
public class OrderServiceImpl implements OrderService {

    @Inject
    UserService userService;

    @Transactional
    public Order createOrder(Long userId, String product, int quantity, BigDecimal totalPrice) {
        // Validate user exists via in-process call to user-module
        if (userService.findById(userId) == null) {
            throw new RuntimeException("Cannot create order: user not found: " + userId);
        }

        Order order = new Order();
        order.userId = userId;
        order.product = product;
        order.quantity = quantity;
        order.totalPrice = totalPrice;
        order.status = "PENDING";
        order.createdAt = LocalDateTime.now();
        order.persist();
        return order;
    }

    public List<Order> listAll() {
        return Order.listAll();
    }

    public List<Order> findByUser(Long userId) {
        return Order.list("userId", userId);
    }

    public Order findById(Long id) {
        return Order.findById(id);
    }

    @Transactional
    public Order updateStatus(Long orderId, String newStatus) {
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
