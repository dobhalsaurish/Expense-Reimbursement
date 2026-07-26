package com.project.expensereimbursement.repository;

import com.project.expensereimbursement.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserRepository extends JpaRepository<User, Long> {

    boolean existByEmail(String email);
}
