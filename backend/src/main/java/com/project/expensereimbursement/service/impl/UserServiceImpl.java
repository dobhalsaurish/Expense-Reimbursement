package com.project.expensereimbursement.service.impl;

import com.project.expensereimbursement.dto.request.CreateUserRequest;
import com.project.expensereimbursement.dto.response.UserResponse;
import com.project.expensereimbursement.entity.User;
import com.project.expensereimbursement.enums.Role;
import com.project.expensereimbursement.exception.EmailAlreadyExistsException;
import com.project.expensereimbursement.repository.UserRepository;
import com.project.expensereimbursement.service.UserService;
import org.springframework.stereotype.Service;

@Service
public class UserServiceImpl implements UserService {

    private final UserRepository userRepository;

    public UserServiceImpl(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Override
    public UserResponse createUser(CreateUserRequest request){

        if(userRepository.existByEmail(request.getEmail())){
            throw new EmailAlreadyExistsException(
                    "Email already exists"
            );
        }

        User user = User.builder()
                .name(request.getName())
                .email(request.getEmail())
                .role(Role.EMPLOYEE)
                .build();

        User savedUser = userRepository.save(user);

        return UserResponse.builder()
                .userId(savedUser.getUserId())
                .name(savedUser.getName())
                .email(savedUser.getEmail())
                .role(savedUser.getRole())
                .build();
    }
}
