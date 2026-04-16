package com.cgm.nais.order.service;

import com.cgm.nais.order.entity.Order;

import java.math.BigDecimal;
import java.util.List;

public interface OrderService {

    Order createOrder(Long userId, String product, int quantity, BigDecimal totalPrice);

    List<Order> listAll();

    List<Order> findByUser(Long userId);

    Order findById(Long id);

    Order updateStatus(Long orderId, String newStatus);

    void deleteOrder(Long id);
}
