# Skill 20 — Index Mastery

> **Capability:** Select, create, and maintain the right index type for every access pattern — eliminating full table scans, reducing sort costs, and enabling index-only query plans.

---

## Index Decision Tree

```
Is the column in a WHERE / JOIN / ORDER BY?
  ├─ Equality on one column     → B-tree, consider Function-Based if transformed
  ├─ Range (BETWEEN, >, <)      → B-tree with column first
  ├─ Multiple columns filtered  → Composite B-tree (selectivity first)
  ├─ Column transformed in SQL  → Function-Based Index
  ├─ Low cardinality (<50 vals) → Bitmap (DW/reporting only; never OLTP)
  └─ Full-text keyword search   → Oracle Text / CTXSYS
```

---

## B-Tree Index Fundamentals

```sql
-- Single column
CREATE INDEX idx_orders_cust ON orders(cust_id);

-- Composite: put the most selective / equality column first
CREATE INDEX idx_orders_region_date
  ON orders(region, order_date);  -- good for WHERE region=? AND order_date BETWEEN

-- Verify the index is used
EXPLAIN PLAN FOR
  SELECT * FROM orders
  WHERE  region = 'APAC'
  AND    order_date >= DATE '2024-01-01';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- Look for: INDEX RANGE SCAN (IDX_ORDERS_REGION_DATE)
```

---

## Function-Based Indexes

Oracle only uses an index if the query predicate matches the index expression **exactly**.

```sql
-- Problem: index on email won't be used for LOWER(email)
CREATE INDEX idx_cust_email ON customers(email);  -- NOT used for:
-- WHERE LOWER(email) = 'hr@datacules.io'

-- Solution: index on the function itself
CREATE INDEX idx_cust_email_lower
  ON customers(LOWER(email));  -- IS used for:
-- WHERE LOWER(email) = 'hr@datacules.io'

-- Other useful function-based indexes:
CREATE INDEX idx_orders_year
  ON orders(EXTRACT(YEAR FROM order_date));  -- WHERE EXTRACT(YEAR FROM order_date) = 2024

CREATE INDEX idx_orders_status_upper
  ON orders(UPPER(status));  -- WHERE UPPER(status) = 'SHIPPED'
```

---

## Composite Index Column Ordering Rules

1. **Equality columns first**, range columns last.
2. **Most selective column first** among the equality columns.
3. The index supports queries on any **leading prefix** of columns.

```sql
-- Index: (dept_id, status, hire_date)
CREATE INDEX idx_emp_dept_status_hire
  ON employees(dept_id, status, hire_date);

-- USED (leading prefix matches):
SELECT * FROM employees WHERE dept_id = 10;
SELECT * FROM employees WHERE dept_id = 10 AND status = 'ACTIVE';
SELECT * FROM employees WHERE dept_id = 10 AND status = 'ACTIVE'
                          AND hire_date > DATE '2020-01-01';

-- NOT USED (leading column missing):
SELECT * FROM employees WHERE status = 'ACTIVE';  -- full scan
SELECT * FROM employees WHERE hire_date > DATE '2020-01-01';  -- full scan
```

---

## Invisible Indexes — Safe Testing

An invisible index is maintained by DML but **ignored by the optimizer** unless the session enables them. Use for zero-risk A/B testing:

```sql
-- Create invisible (no query impact yet)
CREATE INDEX idx_orders_amount ON orders(amount) INVISIBLE;

-- Test impact in your session only
ALTER SESSION SET optimizer_use_invisible_indexes = TRUE;

EXPLAIN PLAN FOR SELECT * FROM orders WHERE amount > 10000;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);  -- does the index help?

-- If good, make it visible to everyone
ALTER INDEX idx_orders_amount VISIBLE;

-- If not useful, drop with zero rollback risk
DROP INDEX idx_orders_amount;
```

---

## Index-Only Scans (Covering Indexes)

If all columns in the SELECT and WHERE are in the index, Oracle can satisfy the query entirely from the index leaf blocks — no table access:

```sql
-- Query: SELECT order_id, amount FROM orders WHERE cust_id = 42
-- A covering index makes this index-only:
CREATE INDEX idx_orders_cust_covering
  ON orders(cust_id, order_id, amount);  -- cust_id=filter, rest=payload

-- Plan shows: INDEX FAST FULL SCAN or INDEX RANGE SCAN (no TABLE ACCESS)
```

---

## Monitor Index Usage

```sql
-- Find indexes that have NEVER been used (candidates for removal)
SELECT index_name, table_name, monitoring, used, start_monitoring
FROM   v$object_usage
WHERE  used = 'NO';

-- Enable monitoring on a specific index
ALTER INDEX idx_orders_cust MONITORING USAGE;

-- After a representative workload period:
SELECT * FROM v$object_usage WHERE index_name = 'IDX_ORDERS_CUST';

-- Duplicate / redundant indexes (prefix subset of another)
SELECT a.index_name AS subset_idx,
       b.index_name AS superset_idx
FROM   user_indexes a
JOIN   user_indexes b ON a.table_name = b.table_name
                      AND a.index_name != b.index_name
WHERE  a.uniqueness = 'NONUNIQUE'
AND    b.uniqueness = 'NONUNIQUE'
AND    NOT EXISTS (
         SELECT 1 FROM user_ind_columns ac
         WHERE  ac.index_name = a.index_name
         AND    ac.column_name NOT IN (
                  SELECT bc.column_name
                  FROM   user_ind_columns bc
                  WHERE  bc.index_name = b.index_name
                )
       );
```

---

## When NOT to Index

| Situation | Reason to Skip |
|---|---|
| Column has < 50 distinct values in OLTP | Index selectivity too low; full scan cheaper |
| Tiny table (< 1000 rows) | Block I/O cheaper than index traversal |
| Heavy INSERT/UPDATE/DELETE with no reads | Index maintenance overhead outweighs benefit |
| Already covered by a composite leading prefix | Redundant; wastes space |

---

## References

- [Oracle Docs — Indexes and Index-Organized Tables](https://docs.oracle.com/en/database/oracle/oracle-database/23/cncpt/indexes-and-index-organized-tables.html)
- [Oracle SQL Tuning Guide — Access Paths](https://docs.oracle.com/en/database/oracle/oracle-database/23/tgsql/)
- [V$OBJECT_USAGE](https://docs.oracle.com/en/database/oracle/oracle-database/23/refrn/V-OBJECT_USAGE.html)
