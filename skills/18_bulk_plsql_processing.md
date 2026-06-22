# Skill 18 — Bulk PL/SQL: BULK COLLECT & FORALL

> **Capability:** Process millions of rows in PL/SQL with 10×–100× less context-switching overhead by replacing row-by-row cursor loops with array-based bulk operations.

---

## The Problem: Row-by-Row = Slow by Slow

Every DML statement in PL/SQL crosses the boundary between the PL/SQL engine and the SQL engine. A classic cursor FOR loop pays that cost on **every row**:

```
PL/SQL Engine ──► SQL Engine   (fetch row 1)
PL/SQL Engine ──► SQL Engine   (INSERT row 1)
PL/SQL Engine ──► SQL Engine   (fetch row 2)  ... × 1,000,000
```

**Bulk operations send the entire array in a single round-trip.**

---

## BULK COLLECT — Fetch All at Once

### Basic pattern
```sql
DECLARE
  TYPE t_emp IS TABLE OF employees%ROWTYPE;
  l_emps t_emp;
BEGIN
  -- Fetches all rows into a PL/SQL collection in ONE SQL call
  SELECT * BULK COLLECT INTO l_emps
  FROM   employees
  WHERE  dept_id = 10;

  DBMS_OUTPUT.PUT_LINE('Fetched: ' || l_emps.COUNT || ' rows');
END;
/
```

### With a cursor (memory-safe LIMIT clause)

For large tables, use `LIMIT` to process in chunks to avoid exhausting PGA memory:

```sql
DECLARE
  CURSOR c_orders IS
    SELECT order_id, cust_id, total_amount
    FROM   orders
    WHERE  status = 'PENDING';

  TYPE t_orders IS TABLE OF c_orders%ROWTYPE;
  l_orders  t_orders;
  c_limit   CONSTANT PLS_INTEGER := 1000;  -- tune for your PGA
  l_count   PLS_INTEGER := 0;
BEGIN
  OPEN c_orders;
  LOOP
    FETCH c_orders BULK COLLECT INTO l_orders LIMIT c_limit;
    EXIT WHEN l_orders.COUNT = 0;

    -- Process the batch
    FOR i IN 1 .. l_orders.COUNT LOOP
      -- business logic here
      l_count := l_count + 1;
    END LOOP;

  END LOOP;
  CLOSE c_orders;
  DBMS_OUTPUT.PUT_LINE('Processed: ' || l_count || ' orders');
END;
/
```

---

## FORALL — Bulk DML

`FORALL` sends an entire array of DML statements to the SQL engine in a single round-trip:

### Bulk INSERT
```sql
DECLARE
  TYPE t_ids    IS TABLE OF orders.order_id%TYPE;
  TYPE t_status IS TABLE OF orders.status%TYPE;

  l_ids    t_ids    := t_ids(101, 102, 103, 104, 105);
  l_status t_status := t_status('SHIPPED','SHIPPED','CANCELLED','SHIPPED','PENDING');
BEGIN
  FORALL i IN 1 .. l_ids.COUNT
    UPDATE orders
    SET    status = l_status(i),
           updated_at = SYSTIMESTAMP
    WHERE  order_id = l_ids(i);

  DBMS_OUTPUT.PUT_LINE('Rows updated: ' || SQL%ROWCOUNT);
  COMMIT;
END;
/
```

### Bulk INSERT from a collection
```sql
DECLARE
  TYPE t_rec IS RECORD (
    product  VARCHAR2(100),
    qty      NUMBER,
    price    NUMBER
  );
  TYPE t_items IS TABLE OF t_rec;

  l_items t_items := t_items(
    t_rec('Widget A', 10, 9.99),
    t_rec('Widget B',  5, 24.99),
    t_rec('Widget C', 20,  4.99)
  );
BEGIN
  FORALL i IN 1 .. l_items.COUNT
    INSERT INTO staging_items (product, qty, price, loaded_at)
    VALUES (l_items(i).product, l_items(i).qty,
            l_items(i).price,  SYSTIMESTAMP);
  COMMIT;
END;
/
```

---

## SAVE EXCEPTIONS — Handle Partial Failures

Without `SAVE EXCEPTIONS`, the first failure in a `FORALL` rolls back the entire batch. With it, Oracle records each failed row and continues:

```sql
DECLARE
  dml_errors EXCEPTION;
  PRAGMA EXCEPTION_INIT(dml_errors, -24381);

  TYPE t_ids IS TABLE OF NUMBER;
  l_ids t_ids := t_ids(1, 2, 99999, 3, 88888);  -- 99999/88888 don't exist
BEGIN
  FORALL i IN 1 .. l_ids.COUNT SAVE EXCEPTIONS
    DELETE FROM orders WHERE order_id = l_ids(i);

  COMMIT;

EXCEPTION
  WHEN dml_errors THEN
    FOR i IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
      DBMS_OUTPUT.PUT_LINE(
        'Index ' || SQL%BULK_EXCEPTIONS(i).ERROR_INDEX ||
        ' failed: ' || SQLERRM(-SQL%BULK_EXCEPTIONS(i).ERROR_CODE)
      );
    END LOOP;
    -- Commit the successful rows, log failures
    COMMIT;
END;
/
```

---

## Full ETL Pattern: BULK COLLECT + FORALL in One Loop

```sql
CREATE OR REPLACE PROCEDURE process_daily_orders AS
  CURSOR c IS
    SELECT order_id, cust_id, total_amount, order_date
    FROM   raw_orders
    WHERE  processed = 'N';

  TYPE t_raw  IS TABLE OF c%ROWTYPE;
  TYPE t_ids  IS TABLE OF NUMBER;

  l_raw     t_raw;
  l_ok_ids  t_ids := t_ids();
  c_chunk   CONSTANT PLS_INTEGER := 500;
  l_errors  PLS_INTEGER := 0;

  dml_errors EXCEPTION;
  PRAGMA EXCEPTION_INIT(dml_errors, -24381);
BEGIN
  OPEN c;
  LOOP
    FETCH c BULK COLLECT INTO l_raw LIMIT c_chunk;
    EXIT WHEN l_raw.COUNT = 0;

    -- Transform: collect valid IDs and insert to target
    l_ok_ids.DELETE;
    l_ok_ids.EXTEND(l_raw.COUNT);

    FORALL i IN 1 .. l_raw.COUNT SAVE EXCEPTIONS
      INSERT INTO processed_orders (order_id, cust_id, amount, order_date)
      VALUES (l_raw(i).order_id, l_raw(i).cust_id,
              l_raw(i).total_amount, l_raw(i).order_date);

    -- Mark source as processed
    FORALL i IN 1 .. l_raw.COUNT
      UPDATE raw_orders
      SET    processed = 'Y', processed_at = SYSTIMESTAMP
      WHERE  order_id = l_raw(i).order_id;

    COMMIT;
  END LOOP;
  CLOSE c;

EXCEPTION
  WHEN dml_errors THEN
    l_errors := SQL%BULK_EXCEPTIONS.COUNT;
    DBMS_OUTPUT.PUT_LINE('Batch errors: ' || l_errors);
    COMMIT;  -- commit successful rows
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END;
/
```

---

## Performance Benchmark Reference

| Method | 100K rows (typical) | Notes |
|---|---|---|
| Row-by-row cursor FOR loop | ~45 sec | 1 SQL call per row |
| BULK COLLECT + FORALL (chunk=500) | ~2–4 sec | 1 SQL call per chunk |
| Pure SQL INSERT..SELECT | ~0.5 sec | Best when no row logic needed |

Use `LIMIT 500` as a starting point; tune up or down based on PGA.

---

## References

- [Oracle Docs — BULK COLLECT](https://docs.oracle.com/en/database/oracle/oracle-database/23/lnpls/FETCH-statement.html)
- [Oracle Docs — FORALL](https://docs.oracle.com/en/database/oracle/oracle-database/23/lnpls/FORALL-statement.html)
- [PL/SQL Language Reference — Collections](https://docs.oracle.com/en/database/oracle/oracle-database/23/lnpls/plsql-collections-and-records.html)
