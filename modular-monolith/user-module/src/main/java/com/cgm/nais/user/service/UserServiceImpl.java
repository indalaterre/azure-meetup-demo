package com.cgm.nais.user.service;

import com.cgm.nais.user.entity.User;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;

import java.util.List;

@ApplicationScoped
public class UserServiceImpl implements UserService {

    @Transactional
    public User createUser(User user) {
        user.persist();
        return user;
    }

    public List<User> listAll() {
        return User.listAll();
    }

    public User findById(Long id) {
        return User.findById(id);
    }

    @Transactional
    public User updateUser(Long id, User updated) {
        User existing = User.findById(id);
        if (existing == null) {
            throw new RuntimeException("User not found: " + id);
        }
        existing.username = updated.username;
        existing.email = updated.email;
        existing.fullName = updated.fullName;
        existing.address = updated.address;
        existing.phone = updated.phone;
        return existing;
    }

    @Transactional
    public void deleteUser(Long id) {
        User.deleteById(id);
    }
}
