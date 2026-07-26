package com.project.expensereimbursement.service.impl;

import com.project.expensereimbursement.dto.request.CreateUserRequest;
import com.project.expensereimbursement.dto.response.UserResponse;
import com.project.expensereimbursement.repository.UserRepository;
import org.springframework.stereotype.Service;

@Service
public class UserServiceImpl {

    private final UserRepository userRepository;

    public UserServiceImpl(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public UserResponse createUser(CreateUserRequest request){

        // Business logic
        return null;
    }
}
