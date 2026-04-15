package com.cgm.nais.order.entity;

import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "orders")
public class Order extends PanacheEntity {

    @Column(nullable = false)
    public Long userId;

    @Column(nullable = false)
    public String product;

    @Column(nullable = false)
    public Integer quantity;

    @Column(nullable = false, precision = 10, scale = 2)
    public BigDecimal totalPrice;

    @Column(nullable = false)
    public String status;

    @Column(nullable = false)
    public LocalDateTime createdAt;
}
