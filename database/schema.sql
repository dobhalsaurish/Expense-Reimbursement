users (
	user_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100),
    email VARCHAR(100) UNIQUE,
    role ENUM('Employee', 'Accountant', 'Admin'),
    created_at TIMESTAMP
)

polcies (
	policy_id INT PRIMARY KEY AUTO_INCREMENT,
    category VARCHAR(50), -- travel, food, hotel
    max_amount DECIMAL(10,2),
    role_applicable VARCHAR(50),
    version INT,
    is_active BOOLEAN,
    created_at TIMESTAMP
)

expense_submissions (
      submission_id INT PRIMARY KEY AUTO_INCREMENT,
      user_id INT,
      status ENUM('PENDING','APPROVED','REJECTED'),
      total_amount DECIMAL(10,2),
      policy_version_used INT,
      created_at TIMESTAMP,
      FOREIGN KEY(user_id) REFERENCES users(user_id)
)

expense_items (
      item_id INT PRIMARY KEY AUTO_INCREMENT,
      submission_id INT,
      category VARCHAR(50),
      amount DECIMAL(10,2),
      description TEXT,
      FOREIGN KEY (submission_id) REFERENCES expense_submission(submision_id)
)

approvals (
      approval_id INT PRIMARY KEY AUTO_INCREMENT,
      submission_id INT,
      accountant_id INT,
      decision ENUM('APPROVED', 'REJECTED'),
      reason TEXT,
      created_at TIMESTAMP,
      FOREIGN KEY (submission_id) REFERENCES expense_submssion(submission_id)
)

audit_logs (
      lod_id INT PRIMARY KEY AUTO_INCREMENT,
      submission_id INT,
      action VARCHAR(50), -- CREATED, APPROVED, REJECTED
      performed_by INT,
      timestamp TIMESTAMP,
      details TEXT
)

CREATE TRIGGER prevent_update_expense
    BEFORE UPDATE ON expense_submssions
    FOR EACH ROW
    BEGIN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Expense cannot be modified after submission';
    END;

CREATE TRIGGER log_expense_creation
    AFTER INSERT ON expense_submissions
    FOR EACH ROW
    INSERT INTO audit_logs(submission_id, action, performed_by, timestamp)
    VALUES (NEW.submission_id, 'CREATED', NEW.user_id, NOW());


DELIMITER $$

CREATE PROCEDURE  validate_expense(IN sub_id INT)
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE item_category VARCHAR(50);
    DECLARE item_amount DECIMAL(10,2);
    DECLARE max_limit DECIMAL(10,2);

    DECLARE cur CURSOR FOR
            SELECT category, amount
            FROM expense_items
            WHERE submission_id = sub_id;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN cur;

    read_loop: LOOP
             FETCH cur INTO item_category, item_amount;

             IF done THEN
                LEAVE read_loop
             END IF;

             SELECT max_amount INTO max_limit
             FROM policies
             WHERE category = item_category AND is_active = TRUE
             LIMIT 1;

            IF item_amount > max_amount THEN
               UPDATE expense_submission
               SET status = 'REJECTED'
               WHERE submission_id = sub_id;

               INSERT INTO audit_logs(submission_id, action, timestamp, details)
               VALUES (sub_id, 'REJECTED', NOW(), CONCAT('Exceeded limit for ', item_category));

                LEAVE read_loop;
            END IF;

    END LOOP;

    CLOSE cur;

    -- if not rejected, mark as pending for approval
    UPDATE expense_submissions
    SET status = 'PENDING'
    WHERE submission_id = sub_id;

END $$

DELIMITER ;
