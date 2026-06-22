# Skill 21 — Advanced SQL: CTEs, PIVOT, MERGE, CONNECT BY

> **Capability:** Write expressive, readable, and efficient SQL for hierarchical data, dynamic cross-tabulation, atomic upserts, and deeply nested transformations.

---

## Common Table Expressions (WITH Clause)

CTEs make complex SQL readable by naming intermediate results. Oracle materialises or inlines them based on cost.

```sql
-- Multi-step sales analysis with named CTEs
WITH
  -- Step 1: Monthly revenue by region
  monthly_rev AS (
    SELECT region,
           TRUNC(txn_date, 'MM')  AS month_start,
           SUM(amount)            AS revenue
    FROM   transactions
    GROUP BY region, TRUNC(txn_date, 'MM')
  ),
  -- Step 2: 3-month moving average per region
  with_ma AS (
    SELECT region,
           month_start,
           revenue,
           AVG(revenue) OVER (
             PARTITION BY region
             ORDER BY month_start
             ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
           ) AS ma3
    FROM monthly_rev
  ),
  -- Step 3: Flag months above the moving average
  flagged AS (
    SELECT *,
           CASE WHEN revenue > ma3 THEN 'ABOVE' ELSE 'BELOW' END AS vs_trend
    FROM with_ma
  )
SELECT * FROM flagged
ORDER BY region, month_start;
```

---

## Recursive CTEs — Hierarchical Data

```sql
-- Traverse an employee org chart: CEO → VP → Manager → Employee
WITH org_hierarchy (emp_id, name, manager_id, lvl, path) AS (
  -- Anchor: the root (CEO has no manager)
  SELECT emp_id,
         name,
         manager_id,
         1,
         CAST(name AS VARCHAR2(4000))
  FROM   employees
  WHERE  manager_id IS NULL

  UNION ALL

  -- Recursive: each employee's direct reports
  SELECT e.emp_id,
         e.name,
         e.manager_id,
         h.lvl + 1,
         h.path || ' > ' || e.name
  FROM   employees e
  JOIN   org_hierarchy h ON e.manager_id = h.emp_id
)
SELECT LPAD(' ', (lvl-1)*4) || name AS org_chart,
       lvl,
       path
FROM   org_hierarchy
CYCLE emp_id SET is_cycle TO '1' DEFAULT '0'  -- protect against circular refs
ORDER BY path;
```

### Classic CONNECT BY (Oracle-specific, equally powerful)

```sql
SELECT LEVEL,
       LPAD(' ', (LEVEL-1)*2) || name AS hierarchy,
       SYS_CONNECT_BY_PATH(name, ' / ') AS full_path,
       CONNECT_BY_ISLEAF AS is_leaf
FROM   employees
START WITH  manager_id IS NULL        -- root node
CONNECT BY  PRIOR emp_id = manager_id -- parent → child
ORDER SIBLINGS BY name;
```

---

## PIVOT — Rows to Columns

```sql
-- Sales by quarter, one column per quarter
SELECT *
FROM (
  SELECT region,
         TO_CHAR(txn_date, 'YYYY_Q"Q"') AS qtr,
         amount
  FROM   transactions
  WHERE  EXTRACT(YEAR FROM txn_date) = 2024
)
PIVOT (
  SUM(amount)               -- aggregate
  FOR qtr IN (
    '2024_Q1' AS q1,
    '2024_Q2' AS q2,
    '2024_Q3' AS q3,
    '2024_Q4' AS q4
  )
)
ORDER BY region;
```

### Dynamic PIVOT using XML (any number of values)

```sql
-- When you don't know the column values at query time
SELECT *
FROM (
  SELECT region, status, amount FROM transactions
)
PIVOT XML (
  SUM(amount) FOR status IN (ANY)
);
-- Returns XML; parse in application or use APEX column selector
```

---

## UNPIVOT — Columns to Rows

```sql
-- Cross-tab report table → normalised rows
SELECT region, quarter, revenue
FROM quarterly_summary
UNPIVOT (
  revenue
  FOR quarter IN (
    q1_revenue AS 'Q1',
    q2_revenue AS 'Q2',
    q3_revenue AS 'Q3',
    q4_revenue AS 'Q4'
  )
)
ORDER BY region, quarter;
```

---

## MERGE — Atomic Upsert

MERGE is the cleanest way to synchronise a target table from a source — insert new rows, update existing ones, optionally delete gone ones:

```sql
MERGE INTO customers tgt
USING (
  SELECT customer_id,
         full_name,
         email,
         phone,
         updated_at
  FROM   crm_staging
  WHERE  batch_id = :p_batch_id
) src
ON (tgt.customer_id = src.customer_id)

WHEN MATCHED THEN
  UPDATE SET
    tgt.full_name   = src.full_name,
    tgt.email       = src.email,
    tgt.phone       = src.phone,
    tgt.modified_at = SYSTIMESTAMP
  WHERE tgt.email != src.email     -- only update if something changed
     OR tgt.phone != src.phone

WHEN NOT MATCHED THEN
  INSERT (customer_id, full_name, email, phone, created_at)
  VALUES (src.customer_id, src.full_name, src.email,
          src.phone, SYSTIMESTAMP);

COMMIT;
DBMS_OUTPUT.PUT_LINE('Merged: ' || SQL%ROWCOUNT || ' rows');
```

### MERGE with DELETE (Oracle extension)

```sql
MERGE INTO active_products tgt
USING product_feed src
ON (tgt.prod_id = src.prod_id)
WHEN MATCHED THEN
  UPDATE SET tgt.price = src.price
  DELETE WHERE src.discontinued = 'Y'   -- remove discontinued rows
WHEN NOT MATCHED THEN
  INSERT (prod_id, name, price)
  VALUES (src.prod_id, src.name, src.price);
```

---

## MODEL Clause — Spreadsheet-Style Calculations

```sql
-- Project next 3 months' revenue from historical trend
SELECT month_num, revenue
FROM (
  SELECT ROWNUM AS month_num, SUM(amount) AS revenue
  FROM   transactions
  GROUP BY TRUNC(txn_date,'MM')
  ORDER BY 1
)
MODEL
  DIMENSION BY (month_num)
  MEASURES     (revenue)
  RULES (
    -- Project month N as average of prior 3
    revenue[13] = AVG(revenue)[9,10,11,12],  -- historical simple model
    revenue[14] = revenue[13] * 1.05,
    revenue[15] = revenue[14] * 1.05
  );
```

---

## References

- [Oracle SQL Language Reference — WITH](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/SELECT.html#GUID-CFA006CA-6FF1-4972-821E-6996142A51C6)
- [Oracle SQL — PIVOT and UNPIVOT](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/SELECT.html#GUID-E7BF1BA9-4523-4A14-8E36-FAA9E4BE2DC5)
- [Oracle SQL — MERGE](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/MERGE.html)
- [CONNECT BY Hierarchical Queries](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/Hierarchical-Queries.html)
