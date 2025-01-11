CREATE TABLE Employees (
    employee_id NUMBER PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    department VARCHAR2(50) NOT NULL,
    designation VARCHAR2(50) NOT NULL,
    date_of_joining DATE NOT NULL
);

CREATE TABLE Performance_Reviews (
    review_id NUMBER PRIMARY KEY,
    employee_id NUMBER NOT NULL,
    review_date DATE NOT NULL,
    kpi_score NUMBER(5, 2) NOT NULL,
    comments VARCHAR2(500),
    FOREIGN KEY (employee_id) REFERENCES Employees(employee_id)
);

CREATE TABLE Goals (
    goal_id NUMBER PRIMARY KEY,
    employee_id NUMBER NOT NULL,
    goal_description VARCHAR2(500) NOT NULL,
    start_date DATE NOT NULL,
    due_date DATE NOT NULL,
    status VARCHAR2(20) DEFAULT 'Pending',
    FOREIGN KEY (employee_id) REFERENCES Employees(employee_id)
);

CREATE TABLE Departments (
    department_id NUMBER PRIMARY KEY,
    name VARCHAR2(50) NOT NULL UNIQUE
);

CREATE SEQUENCE employee_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE review_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE goal_seq START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE PROCEDURE add_employee (
    p_name IN VARCHAR2,
    p_department IN VARCHAR2,
    p_designation IN VARCHAR2,
    p_date_of_joining IN DATE
) IS
BEGIN
    INSERT INTO Employees (employee_id, name, department, designation, date_of_joining)
    VALUES (employee_seq.NEXTVAL, p_name, p_department, p_designation, p_date_of_joining);
    COMMIT;
END;
/

CREATE OR REPLACE PROCEDURE add_review (
    p_employee_id IN NUMBER,
    p_review_date IN DATE,
    p_kpi_score IN NUMBER,
    p_comments IN VARCHAR2
) IS
BEGIN
    INSERT INTO Performance_Reviews (review_id, employee_id, review_date, kpi_score, comments)
    VALUES (review_seq.NEXTVAL, p_employee_id, p_review_date, p_kpi_score, p_comments);
    COMMIT;
END;
/

CREATE OR REPLACE PROCEDURE assign_goal (
    p_employee_id IN NUMBER,
    p_goal_description IN VARCHAR2,
    p_start_date IN DATE,
    p_due_date IN DATE
) IS
BEGIN
    INSERT INTO Goals (goal_id, employee_id, goal_description, start_date, due_date)
    VALUES (goal_seq.NEXTVAL, p_employee_id, p_goal_description, p_start_date, p_due_date);
    COMMIT;
END;
/

CREATE OR REPLACE FUNCTION generate_employee_report (
    p_employee_id IN NUMBER
) RETURN SYS_REFCURSOR IS
    employee_report SYS_REFCURSOR;
BEGIN
    OPEN employee_report FOR
    SELECT e.name, e.department, e.designation, pr.review_date, pr.kpi_score, pr.comments
    FROM Employees e
    LEFT JOIN Performance_Reviews pr ON e.employee_id = pr.employee_id
    WHERE e.employee_id = p_employee_id;
    RETURN employee_report;
END;
/

-- Insert sample departments
INSERT INTO Departments (department_id, name) VALUES (1, 'HR');
INSERT INTO Departments (department_id, name) VALUES (2, 'Engineering');
INSERT INTO Departments (department_id, name) VALUES (3, 'Marketing');

-- Insert sample employees
BEGIN
    add_employee('Alice', 'Engineering', 'Software Engineer', TO_DATE('2023-01-15', 'YYYY-MM-DD'));
    add_employee('Bob', 'Marketing', 'Marketing Specialist', TO_DATE('2023-02-01', 'YYYY-MM-DD'));
END;
/

-- Add sample performance reviews
BEGIN
    add_review(1, TO_DATE('2023-06-15', 'YYYY-MM-DD'), 85.5, 'Great work on project X');
    add_review(2, TO_DATE('2023-07-01', 'YYYY-MM-DD'), 78.0, 'Needs improvement in communication skills');
END;
/

-- Assign sample goals
BEGIN
    assign_goal(1, 'Complete training on advanced SQL', TO_DATE('2023-08-01', 'YYYY-MM-DD'), TO_DATE('2023-10-01', 'YYYY-MM-DD'));
    assign_goal(2, 'Increase social media engagement by 20%', TO_DATE('2023-08-01', 'YYYY-MM-DD'), TO_DATE('2023-09-30', 'YYYY-MM-DD'));
END;
/

CREATE OR REPLACE TRIGGER trg_add_default_goal
AFTER INSERT ON Employees
FOR EACH ROW
BEGIN
    INSERT INTO Goals (goal_id, employee_id, goal_description, start_date, due_date, status)
    VALUES (
        goal_seq.NEXTVAL,
        :NEW.employee_id,
        'Complete onboarding process',
        SYSDATE,
        SYSDATE + 30,
        'Pending'
    );
END;
/

CREATE OR REPLACE TRIGGER trg_update_goal_status
BEFORE UPDATE ON Goals
FOR EACH ROW
BEGIN
    IF :NEW.due_date < SYSDATE AND :NEW.status = 'Pending' THEN
        :NEW.status := 'Overdue';
    END IF;
END;
/

CREATE TABLE Performance_Review_Log (
    log_id NUMBER PRIMARY KEY,
    review_id NUMBER,
    old_kpi_score NUMBER(5, 2),
    new_kpi_score NUMBER(5, 2),
    change_date DATE DEFAULT SYSDATE,
    comments VARCHAR2(500)
);

INSERT INTO Performance_Review_Log (log_id, review_id, old_kpi_score, new_kpi_score, comments)
VALUES (1, 101, 85.50, 90.00, 'Improvement in communication skills observed.');

INSERT INTO Performance_Review_Log (log_id, review_id, old_kpi_score, new_kpi_score, comments)
VALUES (2, 102, 78.00, 82.50, 'Enhanced technical knowledge and problem-solving.');

INSERT INTO Performance_Review_Log (log_id, review_id, old_kpi_score, new_kpi_score, comments)
VALUES (3, 103, 88.75, 88.75, 'No changes in KPI; consistent performance.');


CREATE OR REPLACE TRIGGER trg_log_review_updates
AFTER UPDATE ON Performance_Reviews
FOR EACH ROW
BEGIN
    IF :OLD.kpi_score != :NEW.kpi_score THEN
        INSERT INTO Performance_Review_Log (
            log_id, review_id, old_kpi_score, new_kpi_score, comments
        ) VALUES (
            review_seq.NEXTVAL,
            :NEW.review_id,
            :OLD.kpi_score,
            :NEW.kpi_score,
            'KPI score updated'
        );
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_validate_department
BEFORE INSERT OR UPDATE ON Employees
FOR EACH ROW
DECLARE
    dept_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO dept_count
    FROM Departments
    WHERE name = :NEW.department;

    IF dept_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Invalid department name: ' || :NEW.department);
    END IF;
END;
/

ALTER TABLE Employees ADD avg_kpi_score NUMBER(5, 2);

CREATE OR REPLACE TRIGGER trg_update_avg_kpi_score
AFTER INSERT OR UPDATE ON Performance_Reviews
FOR EACH ROW
DECLARE
    avg_score NUMBER(5, 2);
BEGIN
    SELECT AVG(kpi_score) INTO avg_score
    FROM Performance_Reviews
    WHERE employee_id = :NEW.employee_id;

    UPDATE Employees
    SET avg_kpi_score = avg_score
    WHERE employee_id = :NEW.employee_id;
END;
/

CREATE OR REPLACE TRIGGER trg_validate_goal_dates
BEFORE INSERT OR UPDATE ON Goals
FOR EACH ROW
BEGIN
    IF :NEW.due_date < :NEW.start_date THEN
        RAISE_APPLICATION_ERROR(-20002, 'Goal due date cannot be earlier than the start date.');
    END IF;
END;
/

CREATE TABLE Notifications (
    notification_id NUMBER PRIMARY KEY,
    employee_id NUMBER,
    message VARCHAR2(200),
    created_at DATE DEFAULT SYSDATE
);

INSERT INTO Notifications (notification_id, employee_id, message)
VALUES (1, 201, 'Your performance review is scheduled for next week.');

INSERT INTO Notifications (notification_id, employee_id, message)
VALUES (2, 202, 'Please complete the mandatory compliance training by Friday.');

INSERT INTO Notifications (notification_id, employee_id, message)
VALUES (3, 203, 'You have been assigned a new project: Project Phoenix.');


CREATE OR REPLACE TRIGGER trg_notify_upcoming_reviews
AFTER INSERT OR UPDATE ON Performance_Reviews
FOR EACH ROW
BEGIN
    IF :NEW.review_date BETWEEN SYSDATE AND SYSDATE + 7 THEN
        INSERT INTO Notifications (notification_id, employee_id, message)
        VALUES (
            review_seq.NEXTVAL,
            :NEW.employee_id,
            'Performance review is due on ' || TO_CHAR(:NEW.review_date, 'YYYY-MM-DD')
        );
    END IF;
END;
/

SELECT trigger_name, table_name, status 
FROM user_triggers;

SELECT trigger_name, table_name, status 
FROM user_triggers
WHERE table_name = 'EMPLOYEES'; 

select* from Employees;
select* from Performance_Reviews;
select* from Goals;
select* from Departments;
select* from Performance_Review_Log;
select* from Notifications;


