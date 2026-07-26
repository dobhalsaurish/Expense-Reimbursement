package com.project.expensereimbursement.service;

import com.project.expensereimbursement.dto.request.CreateUserRequest;
import com.project.expensereimbursement.dto.response.UserResponse;

public interface UserService {

    UserResponse createUser(CreateUserRequest request);
}
