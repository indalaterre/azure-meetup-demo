package com.cgm.nais.user.entity;

import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

@Entity
@Table(name = "users")
public class User extends PanacheEntity {

    @Column(nullable = false)
    public String username;

    @Column(nullable = false)
    public String email;

    @Column(nullable = false)
    public String fullName;

    public String address;

    public String phone;
}
