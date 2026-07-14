users (
	user_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    role ENUM('EMPLOYEE', 'ACCOUNTANT', 'ADMIN') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)

policies (
	policy_id INT PRIMARY KEY AUTO_INCREMENT,
    category VARCHAR(50), -- travel, food, hotel
    max_amount DECIMAL(10,2),
    role_applicable VARCHAR(50),
    version INT,
    effective_from DATE,
    effective_to DATE
)

expense_submissions (
      submission_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
      user_id INT NOT NULL,
      status ENUM('DRAFT','PENDING','APPROVED','REJECTED','NEEDS_REVIEW'),
      total_amount DECIMAL(10,2),
      submission_date DATE,
      policy_version_used INT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY(user_id) REFERENCES users(user_id)
)

expense_items (
      item_id INT PRIMARY KEY AUTO_INCREMENT,
      submission_id INT,
      category VARCHAR(50),
      amount DECIMAL(10,2) NOT NULL,
      description TEXT,
      FOREIGN KEY (submission_id) REFERENCES expense_submissions(submission_id)
)

approvals (
      approval_id INT PRIMARY KEY AUTO_INCREMENT,
      submission_id INT,
      accountant_id INT,
      decision ENUM('APPROVED', 'REJECTED'),
      reason_code VARCHAR(50),
      comment TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (submission_id) REFERENCES expense_submissions(submission_id),
      FOREIGN KEY (accountant_id) REFERENCES users(user_id),
      FOREIGN KEY (reason_code) REFERENCES rejection_reasons(reason_code)
)

rejection_reasons (
      reason_code VARCHAR(50) PRIMARY KEY,
      description TEXT
)

audit_logs (
      log_id INT PRIMARY KEY AUTO_INCREMENT,
      submission_id INT,
      action VARCHAR(50), -- CREATED, APPROVED, REJECTED, NEEDS_REVIEW
      performed_by INT,
      timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      details TEXT,
      FOREIGN KEY (submission_id) REFERENCES expense_submissions(submission_id)
)

CREATE INDEX idx_policies_lookup
    ON policies (category, effective_from DESC, effective_to);

CREATE INDEX idx_expense_items_submission
    ON expense_items(submission_id);

CREATE INDEX idx_audit_logs_submission
    ON audit_logs(submission_id);

DELIMITER $$

CREATE TRIGGER prevent_illegal_update
    BEFORE UPDATE ON expense_submissions
    FOR EACH ROW
    BEGIN
        IF OLD.status != 'DRAFT' THEN
        IF NEW.user_id != OLD.user_id OR
            NEW.total_amount != OLD.total_amount OR
            NEW.submission_date != OLD.submission_date THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Cannot modify submitted expense data';
            END IF;
		END IF;
    END $$

DELIMITER ;

DELIMITER $$

CREATE TRIGGER log_expense_creation
    AFTER INSERT ON expense_submissions
    FOR EACH ROW
    BEGIN
        INSERT INTO audit_logs(submission_id, action, performed_by, timestamp, details)
        VALUES (NEW.submission_id, 'CREATED', NEW.user_id, NOW(), 'Expense created');
    END $$

DELIMITER ;


DELIMITER $$

CREATE PROCEDURE  validate_expense(IN sub_id INT, IN user_id INT)
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE item_category VARCHAR(50);
    DECLARE item_amount DECIMAL(10,2);
    DECLARE max_limit DECIMAL(10,2);
    DECLARE v_status VARCHAR(20) DEFAULT 'PENDING'; 
    DECLARE v_policy_version INT;

    DECLARE cur CURSOR FOR
            SELECT category, amount
            FROM expense_items
            WHERE submission_id = sub_id;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    IF (SELECT COUNT(*) FROM expense_submissions WHERE submission_id = sub_id) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Submission not found';
    END IF;

    OPEN cur;

    read_loop: LOOP
             FETCH cur INTO item_category, item_amount;

             IF done THEN
                LEAVE read_loop;
             END IF;

             SET max_limit = NULL;
             SET v_policy_version = NULL;
             BEGIN
                DECLARE CONTINUE HANDLER FOR NOT FOUND
                        BEGIN
                        SET max_limit = NULL;
                        SET v_policy_version = NULL;
                        END;
                SELECT max_amount, version INTO max_limit, v_policy_version
                FROM policies
                WHERE category = item_category
                    AND effective_from <= CURRENT_DATE
                    AND (effective_to IS NULL OR effective_to >= CURRENT_DATE)
                ORDER BY version DESC
                LIMIT 1;
             END;

            IF max_limit IS NULL THEN

                SET v_status = 'NEEDS_REVIEW';


                INSERT INTO audit_logs(submission_id, action, performed_by, timestamp, details)
                VALUES (sub_id, 'NEEDS_REVIEW', user_id, NOW(), 'No policy found');

                LEAVE read_loop;
            END IF;

            IF item_amount > max_limit THEN

                SET v_status = 'REJECTED';

                INSERT INTO audit_logs(submission_id, action, performed_by, timestamp, details)
                VALUES (sub_id, 'REJECTED', user_id, NOW(), CONCAT('Exceeded limit for ', item_category));

                LEAVE read_loop;
            END IF;


    END LOOP;

    CLOSE cur;

    UPDATE expense_submissions
    SET status = v_status,
        policy_version_used = v_policy_version
    WHERE submission_id = sub_id;

END $$

DELIMITER ; 
