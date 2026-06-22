-- =============================================================
-- Oracle Advanced SQL: CTEs, PIVOT, MERGE, CONNECT BY
-- Skill 21 | Oracle AI Developers Community
-- Compatible: Oracle Database 19c, 21c, 23ai
-- =============================================================

-- -------------------------------------------------------
-- 1. CTE WITH MULTIPLE STEPS
-- -------------------------------------------------------
WITH
  monthly_rev AS (
    SELECT region,
           TRUNC(txn_date, 'MM') AS month_start,
           SUM(amount)           AS revenue
    FROM   transactions
    GROUP BY region, TRUNC(txn_date, 'MM')
  ),
  with_ma AS (
    SELECT region,
           month_start,
           revenue,
           ROUND(AVG(revenue) OVER (
             PARTITION BY region
             ORDER BY month_start
             ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
           ), 2) AS ma3
    FROM monthly_rev
  )
SELECT region,
       TO_CHAR(month_start,'Mon YYYY') AS month,
       revenue,
       ma3,
       CASE WHEN revenue > ma3 THEN 'ABOVE TREND' ELSE 'BELOW TREND' END AS vs_trend
FROM with_ma
ORDER BY region, month_start;

-- -------------------------------------------------------
-- 2. RECURSIVE CTE — ORG CHART
-- -------------------------------------------------------
WITH org (emp_id, name, manager_id, lvl, path) AS (
  SELECT emp_id, name, manager_id, 1,
         CAST(name AS VARCHAR2(4000))
  FROM   employees
  WHERE  manager_id IS NULL  -- root
  UNION ALL
  SELECT e.emp_id, e.name, e.manager_id, o.lvl + 1,
         o.path || ' > ' || e.name
  FROM   employees e
  JOIN   org o ON e.manager_id = o.emp_id
)
SELECT LPAD(' ', (lvl-1)*4) || name AS org_chart, lvl, path
FROM   org
CYCLE  emp_id SET is_cycle TO '1' DEFAULT '0'
ORDER  BY path;

-- -------------------------------------------------------
-- 3. CONNECT BY — CLASSIC HIERARCHICAL QUERY
-- -------------------------------------------------------
SELECT LEVEL,
       LPAD(' ', (LEVEL-1)*2) || name     AS hierarchy,
       SYS_CONNECT_BY_PATH(name, ' / ')   AS full_path,
       CONNECT_BY_ISLEAF                  AS is_leaf,
       CONNECT_BY_ISCYCLE                 AS is_cycle
FROM   employees
START WITH  manager_id IS NULL
CONNECT BY NOCYCLE PRIOR emp_id = manager_id
ORDER SIBLINGS BY name;

-- -------------------------------------------------------
-- 4. PIVOT — QUARTERLY REVENUE CROSS-TAB
-- -------------------------------------------------------
SELECT *
FROM (
  SELECT region,
         CASE TRUNC(txn_date, 'Q')
           WHEN DATE '2024-01-01' THEN 'Q1'
           WHEN DATE '2024-04-01' THEN 'Q2'
           WHEN DATE '2024-07-01' THEN 'Q3'
           WHEN DATE '2024-10-01' THEN 'Q4'
         END AS qtr,
         amount
  FROM transactions
  WHERE EXTRACT(YEAR FROM txn_date) = 2024
)
PIVOT (
  ROUND(SUM(amount),0)
  FOR qtr IN ('Q1' AS q1, 'Q2' AS q2, 'Q3' AS q3, 'Q4' AS q4)
)
ORDER BY region;

-- -------------------------------------------------------
-- 5. UNPIVOT — CROSS-TAB BACK TO ROWS
-- -------------------------------------------------------
-- Assumes quarterly_summary(region, q1_rev, q2_rev, q3_rev, q4_rev)
SELECT region, quarter, revenue
FROM   quarterly_summary
UNPIVOT (
  revenue FOR quarter IN (
    q1_rev AS 'Q1',
    q2_rev AS 'Q2',
    q3_rev AS 'Q3',
    q4_rev AS 'Q4'
  )
)
ORDER BY region, quarter;

-- -------------------------------------------------------
-- 6. MERGE — UPSERT PATTERN
-- -------------------------------------------------------
MERGE INTO customers tgt
USING (
  SELECT customer_id, full_name, email, phone
  FROM   crm_staging
  WHERE  batch_date = TRUNC(SYSDATE)
) src
ON (tgt.customer_id = src.customer_id)
WHEN MATCHED THEN
  UPDATE SET
    tgt.full_name   = src.full_name,
    tgt.email       = src.email,
    tgt.phone       = src.phone,
    tgt.modified_at = SYSTIMESTAMP
  WHERE tgt.email != src.email
     OR tgt.phone != src.phone
WHEN NOT MATCHED THEN
  INSERT (customer_id, full_name, email, phone, created_at)
  VALUES (src.customer_id, src.full_name, src.email,
          src.phone, SYSTIMESTAMP);
COMMIT;
