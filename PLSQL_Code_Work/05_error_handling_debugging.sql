-- =============================================================
-- Oracle PL/SQL Error Handling & Debugging Patterns
-- Skill 22 | Oracle AI Developers Community
-- Compatible: Oracle Database 19c, 21c, 23ai
-- =============================================================

-- -------------------------------------------------------
-- 1. BUILT-IN NAMED EXCEPTIONS
-- -------------------------------------------------------
DECLARE
  v_name  VARCHAR2(100);
BEGIN
  -- NO_DATA_FOUND
  BEGIN
    SELECT name INTO v_name FROM customers WHERE cust_id = -1;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      DBMS_OUTPUT.PUT_LINE('Not found — handled gracefully');
  END;

  -- TOO_MANY_ROWS
  BEGIN
    SELECT name INTO v_name FROM customers WHERE region = 'APAC';
  EXCEPTION
    WHEN TOO_MANY_ROWS THEN
      DBMS_OUTPUT.PUT_LINE('Multiple rows returned — use a cursor');
  END;

  -- VALUE_ERROR
  BEGIN
    v_name := TO_NUMBER('NOT_A_NUMBER');
  EXCEPTION
    WHEN VALUE_ERROR THEN
      DBMS_OUTPUT.PUT_LINE('Type conversion failed: ' || SQLERRM);
  END;
END;
/

-- -------------------------------------------------------
-- 2. CUSTOM / USER-DEFINED EXCEPTIONS
-- -------------------------------------------------------
CREATE OR REPLACE PACKAGE app_exceptions AS
  e_invalid_status   EXCEPTION;
  e_insufficient_qty EXCEPTION;
  e_credit_exceeded  EXCEPTION;

  PRAGMA EXCEPTION_INIT(e_insufficient_qty, -20001);
  PRAGMA EXCEPTION_INIT(e_credit_exceeded,  -20002);
END;
/

-- Raise a user-defined application error
CREATE OR REPLACE PROCEDURE validate_order(
  p_cust_id  NUMBER,
  p_prod_id  NUMBER,
  p_qty      NUMBER
) AS
  v_stock   NUMBER;
  v_status  VARCHAR2(20);
BEGIN
  SELECT status INTO v_status FROM customers WHERE cust_id = p_cust_id;

  IF v_status != 'ACTIVE' THEN
    RAISE app_exceptions.e_invalid_status;
  END IF;

  SELECT qty_on_hand INTO v_stock FROM inventory WHERE prod_id = p_prod_id;

  IF v_stock < p_qty THEN
    RAISE_APPLICATION_ERROR(-20001,
      'Insufficient stock: ' || v_stock || ' available, ' ||
      p_qty || ' requested for product ' || p_prod_id);
  END IF;

EXCEPTION
  WHEN app_exceptions.e_invalid_status THEN
    RAISE_APPLICATION_ERROR(-20099,
      'Cannot order for inactive customer: ' || p_cust_id);
  WHEN app_exceptions.e_insufficient_qty THEN
    RAISE;  -- re-raise to preserve the original -20001 message
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20098,
      'Customer or product not found: cust=' || p_cust_id ||
      ' prod=' || p_prod_id);
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20000,
      'validate_order failed: ' || DBMS_UTILITY.FORMAT_ERROR_STACK);
END;
/

-- -------------------------------------------------------
-- 3. ERROR STACK & BACKTRACE CAPTURE
-- -------------------------------------------------------
DECLARE
  PROCEDURE deep_proc AS
  BEGIN
    RAISE_APPLICATION_ERROR(-20100, 'Error deep inside');
  END;

  PROCEDURE mid_proc AS
  BEGIN
    deep_proc;
  END;
BEGIN
  mid_proc;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('--- ERROR STACK ---');
    DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_STACK);
    DBMS_OUTPUT.PUT_LINE('--- BACKTRACE (line that raised) ---');
    DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
END;
/

-- -------------------------------------------------------
-- 4. REUSABLE ERROR LOG TABLE
-- -------------------------------------------------------
CREATE TABLE app_error_log (
  err_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  app_module   VARCHAR2(100),
  error_code   NUMBER,
  error_msg    VARCHAR2(4000),
  error_stack  CLOB,
  backtrace    CLOB,
  call_params  CLOB,
  session_user VARCHAR2(100),
  session_id   NUMBER,
  logged_at    TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- Autonomous-transaction logger (survives caller ROLLBACK)
CREATE OR REPLACE PROCEDURE log_error(
  p_module VARCHAR2,
  p_params CLOB DEFAULT NULL
) AS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  INSERT INTO app_error_log
    (app_module, error_code, error_msg, error_stack,
     backtrace, call_params, session_user, session_id)
  VALUES (
    p_module,
    SQLCODE,
    SQLERRM,
    DBMS_UTILITY.FORMAT_ERROR_STACK,
    DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
    p_params,
    SYS_CONTEXT('USERENV','SESSION_USER'),
    TO_NUMBER(SYS_CONTEXT('USERENV','SESSIONID'))
  );
  COMMIT;
END;
/

-- Usage pattern in any procedure
/*
EXCEPTION
  WHEN OTHERS THEN
    log_error(
      p_module => 'my_procedure_name',
      p_params => JSON_OBJECT('input1' VALUE v_param1, 'input2' VALUE v_param2)
    );
    RAISE;  -- always re-raise so caller knows something went wrong
END;
*/

-- Query recent errors
SELECT err_id, app_module, error_code, error_msg, logged_at
FROM   app_error_log
WHERE  logged_at >= SYSTIMESTAMP - INTERVAL '24' HOUR
ORDER BY logged_at DESC
FETCH FIRST 50 ROWS ONLY;
