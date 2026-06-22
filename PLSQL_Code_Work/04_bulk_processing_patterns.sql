-- =============================================================
-- Oracle Bulk PL/SQL: BULK COLLECT + FORALL Patterns
-- Skill 18 | Oracle AI Developers Community
-- Compatible: Oracle Database 19c, 21c, 23ai
-- =============================================================

-- -------------------------------------------------------
-- 1. BASIC BULK COLLECT (entire result set)
-- -------------------------------------------------------
DECLARE
  TYPE t_emp IS TABLE OF employees%ROWTYPE;
  l_emps t_emp;
BEGIN
  SELECT * BULK COLLECT INTO l_emps
  FROM   employees
  WHERE  dept_id = 10;

  DBMS_OUTPUT.PUT_LINE('Fetched: ' || l_emps.COUNT || ' rows');
END;
/

-- -------------------------------------------------------
-- 2. BULK COLLECT WITH LIMIT (memory-safe chunking)
-- -------------------------------------------------------
DECLARE
  CURSOR c_orders IS
    SELECT order_id, cust_id, total_amount
    FROM   orders
    WHERE  status = 'PENDING';

  TYPE t_orders IS TABLE OF c_orders%ROWTYPE;
  l_orders t_orders;
  c_limit  CONSTANT PLS_INTEGER := 1000;
  l_total  PLS_INTEGER := 0;
BEGIN
  OPEN c_orders;
  LOOP
    FETCH c_orders BULK COLLECT INTO l_orders LIMIT c_limit;
    EXIT WHEN l_orders.COUNT = 0;

    -- Process the batch
    FOR i IN 1 .. l_orders.COUNT LOOP
      -- business logic placeholder
      l_total := l_total + 1;
    END LOOP;
  END LOOP;
  CLOSE c_orders;
  DBMS_OUTPUT.PUT_LINE('Total processed: ' || l_total);
END;
/

-- -------------------------------------------------------
-- 3. FORALL — BULK UPDATE
-- -------------------------------------------------------
DECLARE
  TYPE t_ids    IS TABLE OF orders.order_id%TYPE;
  TYPE t_status IS TABLE OF orders.status%TYPE;

  l_ids    t_ids    := t_ids(101,102,103,104,105);
  l_status t_status := t_status('SHIPPED','SHIPPED','CANCELLED','SHIPPED','PENDING');
BEGIN
  FORALL i IN 1 .. l_ids.COUNT
    UPDATE orders
    SET    status     = l_status(i),
           updated_at = SYSTIMESTAMP
    WHERE  order_id   = l_ids(i);

  DBMS_OUTPUT.PUT_LINE('Rows updated: ' || SQL%ROWCOUNT);
  COMMIT;
END;
/

-- -------------------------------------------------------
-- 4. FORALL WITH SAVE EXCEPTIONS
-- -------------------------------------------------------
DECLARE
  dml_errors EXCEPTION;
  PRAGMA EXCEPTION_INIT(dml_errors, -24381);

  TYPE t_ids IS TABLE OF NUMBER;
  -- 99999 and 88888 don't exist — should fail gracefully
  l_ids t_ids := t_ids(1, 2, 99999, 3, 88888);
BEGIN
  FORALL i IN 1 .. l_ids.COUNT SAVE EXCEPTIONS
    DELETE FROM orders WHERE order_id = l_ids(i);

  COMMIT;

EXCEPTION
  WHEN dml_errors THEN
    FOR i IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
      DBMS_OUTPUT.PUT_LINE(
        'Index ' || SQL%BULK_EXCEPTIONS(i).ERROR_INDEX ||
        ' Error: ' || SQLERRM(-SQL%BULK_EXCEPTIONS(i).ERROR_CODE)
      );
    END LOOP;
    COMMIT;  -- commit successful deletes
END;
/

-- -------------------------------------------------------
-- 5. FULL ETL PATTERN: BULK COLLECT + FORALL IN ONE LOOP
-- -------------------------------------------------------
CREATE OR REPLACE PROCEDURE process_daily_orders AS
  CURSOR c IS
    SELECT order_id, cust_id, total_amount, order_date
    FROM   raw_orders
    WHERE  processed = 'N';

  TYPE t_raw IS TABLE OF c%ROWTYPE;
  l_raw    t_raw;
  c_chunk  CONSTANT PLS_INTEGER := 500;

  dml_errors EXCEPTION;
  PRAGMA EXCEPTION_INIT(dml_errors, -24381);
BEGIN
  OPEN c;
  LOOP
    FETCH c BULK COLLECT INTO l_raw LIMIT c_chunk;
    EXIT WHEN l_raw.COUNT = 0;

    FORALL i IN 1 .. l_raw.COUNT SAVE EXCEPTIONS
      INSERT INTO processed_orders (order_id, cust_id, amount, order_date)
      VALUES (l_raw(i).order_id, l_raw(i).cust_id,
              l_raw(i).total_amount, l_raw(i).order_date);

    FORALL i IN 1 .. l_raw.COUNT
      UPDATE raw_orders
      SET    processed = 'Y', processed_at = SYSTIMESTAMP
      WHERE  order_id  = l_raw(i).order_id;

    COMMIT;
  END LOOP;
  CLOSE c;

EXCEPTION
  WHEN dml_errors THEN
    DBMS_OUTPUT.PUT_LINE('Batch errors: ' || SQL%BULK_EXCEPTIONS.COUNT);
    COMMIT;
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END;
/
