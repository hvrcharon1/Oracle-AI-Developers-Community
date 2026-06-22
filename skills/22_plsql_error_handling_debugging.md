# Skill 22 — PL/SQL Error Handling & Debugging

> **Capability:** Write PL/SQL that fails gracefully, logs precisely, and debugs efficiently — using Oracle's full exception framework, call stack capture, and a reusable error logging infrastructure.

---

## The Exception Architecture

```
                  EXCEPTION hierarchy
                   OTHERS (catch-all)
                 /           \
       Named exceptions    User-defined
      (built-in Oracle)   (PRAGMA / RAISE)
    NO_DATA_FOUND           my_custom_err
    TOO_MANY_ROWS
    VALUE_ERROR
    DUP_VAL_ON_INDEX
    CURSOR_ALREADY_OPEN
    ...
```

---

## Built-In Exceptions — Named Correctly

```sql
DECLARE
  v_name  VARCHAR2(100);
  v_count NUMBER;
BEGIN
  -- NO_DATA_FOUND: SELECT INTO returns 0 rows
  BEGIN
    SELECT name INTO v_name FROM customers WHERE cust_id = -1;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      DBMS_OUTPUT.PUT_LINE('Customer not found — handling gracefully');
  END;

  -- TOO_MANY_ROWS: SELECT INTO returns > 1 row
  BEGIN
    SELECT name INTO v_name FROM customers WHERE region = 'APAC';
  EXCEPTION
    WHEN TOO_MANY_ROWS THEN
      DBMS_OUTPUT.PUT_LINE('Multiple rows — use a cursor instead');
  END;

  -- VALUE_ERROR: type mismatch / numeric overflow
  BEGIN
    v_count := TO_NUMBER('NOT_A_NUMBER');
  EXCEPTION
    WHEN VALUE_ERROR THEN
      DBMS_OUTPUT.PUT_LINE('Bad value: ' || SQLERRM);
  END;

END;
/
```

---

## Custom Exceptions

```sql
CREATE OR REPLACE PACKAGE order_pkg AS
  -- Declare application exceptions
  e_invalid_status   EXCEPTION;
  e_insufficient_qty EXCEPTION;
  e_credit_exceeded  EXCEPTION;

  PRAGMA EXCEPTION_INIT(e_insufficient_qty, -20001);
  PRAGMA EXCEPTION_INIT(e_credit_exceeded,  -20002);
  -- e_invalid_status is a pure PL/SQL exception (no ORA- code)

  PROCEDURE place_order(
    p_cust_id  NUMBER,
    p_prod_id  NUMBER,
    p_qty      NUMBER
  );
END;
/

CREATE OR REPLACE PACKAGE BODY order_pkg AS
  PROCEDURE place_order(
    p_cust_id NUMBER,
    p_prod_id NUMBER,
    p_qty     NUMBER
  ) AS
    v_stock  NUMBER;
    v_credit NUMBER;
    v_status VARCHAR2(20);
  BEGIN
    SELECT status INTO v_status FROM customers WHERE cust_id = p_cust_id;
    IF v_status != 'ACTIVE' THEN
      RAISE e_invalid_status;
    END IF;

    SELECT qty_on_hand INTO v_stock FROM inventory WHERE prod_id = p_prod_id;
    IF v_stock < p_qty THEN
      RAISE_APPLICATION_ERROR(-20001, 'Insufficient stock: ' ||
        v_stock || ' available, ' || p_qty || ' requested');
    END IF;

  EXCEPTION
    WHEN e_invalid_status THEN
      RAISE_APPLICATION_ERROR(-20099,
        'Cannot place order for inactive customer: ' || p_cust_id);
    WHEN e_insufficient_qty THEN
      RAISE;  -- re-raise with original -20001 message
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,
        'place_order failed: ' || DBMS_UTILITY.FORMAT_ERROR_STACK);
  END;
END;
/
```

---

## Capturing the Full Error Context

```sql
DECLARE
  PROCEDURE inner_proc AS
  BEGIN
    RAISE_APPLICATION_ERROR(-20100, 'Something went wrong inside');
  END;

  PROCEDURE outer_proc AS
  BEGIN
    inner_proc;
  END;
BEGIN
  outer_proc;
EXCEPTION
  WHEN OTHERS THEN
    -- Full error stack: every ORA- error in the chain
    DBMS_OUTPUT.PUT_LINE('=== ERROR STACK ===');
    DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_STACK);

    -- PL/SQL call stack: which procedure/line triggered the error
    DBMS_OUTPUT.PUT_LINE('=== CALL STACK ===');
    DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);

    -- UTL_CALL_STACK (12c+): structured call stack access
    DBMS_OUTPUT.PUT_LINE('=== UTL_CALL_STACK DEPTH: ' ||
      UTL_CALL_STACK.BACKTRACE_DEPTH || ' ===');
END;
/
```

---

## Reusable Error Logging Table & Procedure

```sql
-- Error log table
CREATE TABLE app_error_log (
  err_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  app_module   VARCHAR2(100),
  error_code   NUMBER,
  error_msg    VARCHAR2(4000),
  error_stack  CLOB,
  backtrace    CLOB,
  call_params  CLOB,      -- JSON of input parameters
  session_user VARCHAR2(100),
  session_id   NUMBER,
  logged_at    TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- Logging procedure (autonomous transaction — commits even if caller rolls back)
CREATE OR REPLACE PROCEDURE log_error(
  p_module     VARCHAR2,
  p_params     CLOB DEFAULT NULL  -- pass JSON_OBJECT of your parameters
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
    SYS_CONTEXT('USERENV','SESSIONID')
  );
  COMMIT;
END;
/

-- Usage in any procedure
EXCEPTION
  WHEN OTHERS THEN
    log_error(
      p_module => 'process_daily_orders',
      p_params => JSON_OBJECT(
        'cust_id'  VALUE p_cust_id,
        'order_id' VALUE p_order_id
      )
    );
    RAISE;
END;
```

---

## DBMS_OUTPUT Debugging Patterns

```sql
-- Enable in SQL*Plus / SQLcl / VS Code
SET SERVEROUTPUT ON SIZE UNLIMITED

-- Debug helper (toggle off in production via package constant)
CREATE OR REPLACE PACKAGE debug_pkg AS
  g_debug BOOLEAN := FALSE;  -- set TRUE in dev sessions

  PROCEDURE log(p_msg VARCHAR2);
END;
/

CREATE OR REPLACE PACKAGE BODY debug_pkg AS
  PROCEDURE log(p_msg VARCHAR2) AS
  BEGIN
    IF g_debug THEN
      DBMS_OUTPUT.PUT_LINE(
        TO_CHAR(SYSTIMESTAMP,'HH24:MI:SS.FF3') || ' | ' || p_msg
      );
    END IF;
  END;
END;
/

-- Usage
BEGIN
  debug_pkg.g_debug := TRUE;
  debug_pkg.log('Processing cust_id=' || p_cust_id);
END;
```

---

## Exception Handling Checklist

| Rule | Why |
|---|---|
| Never `WHEN OTHERS THEN NULL` | Silently swallows all errors — bugs disappear |
| Always re-`RAISE` or log before swallowing | Preserves diagnostic info |
| Use `AUTONOMOUS_TRANSACTION` for error logging | Log survives caller's ROLLBACK |
| Catch specific exceptions before `OTHERS` | Order matters; `OTHERS` is last resort |
| Include `DBMS_UTILITY.FORMAT_ERROR_BACKTRACE` | Gives the exact line number that failed |

---

## References

- [Oracle PL/SQL — Exception Handling](https://docs.oracle.com/en/database/oracle/oracle-database/23/lnpls/plsql-error-handling.html)
- [DBMS_UTILITY Package](https://docs.oracle.com/en/database/oracle/oracle-database/23/arpls/DBMS_UTILITY.html)
- [UTL_CALL_STACK Package](https://docs.oracle.com/en/database/oracle/oracle-database/23/arpls/UTL_CALL_STACK.html)
- [RAISE_APPLICATION_ERROR](https://docs.oracle.com/en/database/oracle/oracle-database/23/lnpls/RAISE_APPLICATION_ERROR-procedure.html)
