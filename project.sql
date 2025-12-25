-- department table
CREATE TABLE Departments (
    dept_id NUMBER PRIMARY KEY,
    dept_name VARCHAR2(50)
);

-- employees table
CREATE TABLE Employees (
    emp_id NUMBER PRIMARY KEY,
    emp_name VARCHAR2(100),
    dept_id NUMBER,
    basic_salary NUMBER(10,2),
    hire_date DATE DEFAULT SYSDATE,
    CONSTRAINT fk_dept FOREIGN KEY (dept_id) REFERENCES Departments(dept_id)
);

-- table for salary details
CREATE TABLE Salary_details (
    emp_id NUMBER,
    salary_month VARCHAR2(20),
    hra NUMBER(10,2),
    bonus NUMBER(10,2),
    tax NUMBER(10,2),
    net_salary NUMBER(10,2),
    CONSTRAINT pk_salary PRIMARY KEY(emp_id, salary_month),
    CONSTRAINT fk_emp FOREIGN KEY (emp_id) REFERENCES Employees(emp_id)
);

-- salary audit table
CREATE TABLE Salary_audit (
    emp_id NUMBER,
    old_salary NUMBER,
    new_salary NUMBER,
    changed_on DATE
);


CREATE SEQUENCE seq_dept START WITH 1;
CREATE SEQUENCE seq_emp START WITH 101;

-- function for tax calculation
CREATE OR REPLACE FUNCTION Calculate_tax (p_basic NUMBER)
RETURN NUMBER AS 
BEGIN 
    IF p_basic <= 30000 THEN
        RETURN p_basic * 0.05;
    ELSIF p_basic <= 60000 THEN
        RETURN p_basic * 0.10;
    ELSE 
        RETURN p_basic * 0.15;
    END IF;
END;
/

-- package ( payroll )
CREATE OR REPLACE PACKAGE payroll_pkg AS 
    PROCEDURE calculate_salary (p_emp_id IN NUMBER, p_month IN VARCHAR2);

    PROCEDURE monthly_report;
END payroll_pkg;
/

-- package body
CREATE OR REPLACE PACKAGE BODY payroll_pkg AS

    PROCEDURE calculate_salary (p_emp_id IN NUMBER, p_month IN VARCHAR2) 
    AS v_basic Employees.basic_salary%TYPE;
    v_hra NUMBER;
    v_bonus NUMBER;
    v_tax NUMBER;
    v_net NUMBER;
    BEGIN
        SELECT basic_salary INTO v_basic
        FROM Employees
        WHERE emp_id = p_emp_id;

        v_hra := v_basic * 0.20;
        v_bonus := v_basic * 0.10;
        v_tax := calculate_tax(v_basic);

        v_net := v_basic + v_hra + v_bonus - v_tax;

        INSERT INTO Salary_details 
        VALUES (p_emp_id, p_month, v_hra, v_bonus, v_tax, v_net);

        DBMS_OUTPUT.PUT_LINE('Salary calculated for Employee ID : ' || p_emp_id);
    END calculate_salary;

    -- cursor for monthly report    
    PROCEDURE monthly_report AS
        CURSOR c_sal IS
            SELECT e.emp_name, d.dept_name, s.net_salary
            FROM Employees e
            JOIN Departments d ON e.dept_id = d.dept_id
            JOIN salary_details s ON e.emp_id = s.emp_id;

    BEGIN
        FOR rec IN c_sal LOOP
            DBMS_OUTPUT.PUT_LINE(rec.emp_name || ' | ' || rec.dept_name || ' | Salary : ' || rec.net_salary);

        END LOOP;
    END monthly_report;
END payroll_pkg;
/

-- Audit salary changes
CREATE OR REPLACE TRIGGER trg_salary_audit
AFTER UPDATE OF basic_salary ON Employees
FOR EACH ROW 
BEGIN
    INSERT INTO salary_audit
    VALUES (:OLD.emp_id, :OLD.basic_salary, :NEW.basic_salary, SYSDATE);
END;
/


INSERT INTO Departments VALUES (seq_dept.NEXTVAL, 'HR');
INSERT INTO Departments VALUES (seq_dept.NEXTVAL, 'IT');

INSERT INTO Employees VALUES (seq_emp.NEXTVAL, 'Ayush Chouhan', 2, 50000, SYSDATE);
INSERT INTO Employees VALUES (seq_emp.NEXTVAL, 'Rohit sharma', 1, 30000, SYSDATE);

-- testing 
BEGIN
    payroll_pkg.calculate_salary(101, 'JAN-2025');
    payroll_pkg.calculate_salary(102, 'JAN-2025');
    payroll_pkg.monthly_report;
END;
/

-- monthly payslip 
SELECT e.emp_name, s.salary_month, s.hra, s.bonus, s.tax, s.net_salary
FROM Employees e JOIN Salary_details s
ON e.emp_id = s.emp_id;

-- department-wise salary report
SELECT d.dept_name, SUM(s.net_salary) AS total_salary
FROM Departments d 
JOIN Employees e ON d.dept_id = e.dept_id
JOIN Salary_details s ON e.emp_id = s.emp_id
GROUP BY d.dept_name;
