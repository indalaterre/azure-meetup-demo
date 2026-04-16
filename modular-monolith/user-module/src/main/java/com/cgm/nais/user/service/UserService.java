package com.cgm.nais.user.service;

import com.cgm.nais.user.entity.User;

import java.util.List;

public interface UserService {

    User createUser(User user);

    List<User> listAll();

    User findById(Long id);

    User updateUser(Long id, User updated);

    void deleteUser(Long id);
}
