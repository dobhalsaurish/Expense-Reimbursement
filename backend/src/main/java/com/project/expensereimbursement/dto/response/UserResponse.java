package com.project.expensereimbursement.dto.response;

import com.project.expensereimbursement.enums.Role;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class UserResponse {

    private Long userId;

    private String name;

    private String email;

    private Role role;
}
