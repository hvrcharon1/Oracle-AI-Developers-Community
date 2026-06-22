-- =============================================================
-- Oracle Analytical / Window Functions — Practical Examples
-- Skill 17 | Oracle AI Developers Community
-- Compatible: Oracle Database 19c, 21c, 23ai
-- =============================================================

-- -------------------------------------------------------
-- 1. RANKING FUNCTIONS
-- -------------------------------------------------------
SELECT
  emp_id,
  dept_id,
  salary,
  RANK()       OVER (PARTITION BY dept_id ORDER BY salary DESC) AS dept_rank,
  DENSE_RANK() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS dept_dense_rank,
  ROW_NUMBER() OVER (PARTITION BY dept_id ORDER BY salary DESC,
                                                   emp_id ASC) AS dept_row_num,
  NTILE(4)     OVER (ORDER BY salary DESC)                      AS salary_quartile
FROM employees
ORDER BY dept_id, salary DESC;

-- Top-3 earners per department
SELECT *
FROM (
  SELECT e.*,
         RANK() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS rnk
  FROM   employees e
)
WHERE rnk <= 3;

-- -------------------------------------------------------
-- 2. RUNNING TOTALS & CUMULATIVE AGGREGATES
-- -------------------------------------------------------
SELECT
  txn_date,
  amount,
  SUM(amount) OVER (
    ORDER BY txn_date
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  )                                  AS running_total,
  ROUND(AVG(amount) OVER (
    ORDER BY txn_date
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ), 2)                              AS running_avg,
  SUM(amount) OVER ()                AS grand_total,
  ROUND(amount / SUM(amount) OVER () * 100, 2) AS pct_of_total
FROM transactions
ORDER BY txn_date;

-- -------------------------------------------------------
-- 3. 7-DAY AND 30-DAY MOVING AVERAGES
-- -------------------------------------------------------
SELECT
  sale_date,
  daily_revenue,
  ROUND(AVG(daily_revenue) OVER (
    ORDER BY sale_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ), 2) AS ma_7day,
  ROUND(AVG(daily_revenue) OVER (
    ORDER BY sale_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
  ), 2) AS ma_30day
FROM daily_sales
ORDER BY sale_date;

-- -------------------------------------------------------
-- 4. LAG & LEAD — DAY-OVER-DAY CHANGE
-- -------------------------------------------------------
SELECT
  sale_date,
  daily_revenue,
  LAG(daily_revenue,  1, 0) OVER (ORDER BY sale_date) AS prev_day,
  LEAD(daily_revenue, 1)    OVER (ORDER BY sale_date) AS next_day,
  ROUND(
    (daily_revenue - LAG(daily_revenue) OVER (ORDER BY sale_date))
    / NULLIF(LAG(daily_revenue) OVER (ORDER BY sale_date), 0) * 100,
    1
  ) AS dod_change_pct
FROM daily_sales
ORDER BY sale_date;

-- -------------------------------------------------------
-- 5. FIRST_VALUE / LAST_VALUE PER PARTITION
-- -------------------------------------------------------
SELECT
  dept_id,
  emp_id,
  salary,
  FIRST_VALUE(salary) OVER (
    PARTITION BY dept_id ORDER BY salary DESC
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
  ) AS dept_max_salary,
  LAST_VALUE(salary)  OVER (
    PARTITION BY dept_id ORDER BY salary DESC
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
  ) AS dept_min_salary
FROM employees;

-- -------------------------------------------------------
-- 6. LISTAGG — STRING AGGREGATION
-- -------------------------------------------------------
-- Grouped (collapses rows)
SELECT
  dept_id,
  COUNT(*) AS headcount,
  LISTAGG(last_name, ', ')
    WITHIN GROUP (ORDER BY last_name) AS members
FROM employees
GROUP BY dept_id;

-- Windowed (preserves all rows)
SELECT
  emp_id,
  dept_id,
  LISTAGG(last_name, ', ') WITHIN GROUP (ORDER BY last_name)
    OVER (PARTITION BY dept_id) AS dept_members
FROM employees;

-- -------------------------------------------------------
-- 7. PERCENT_RANK & CUME_DIST
-- -------------------------------------------------------
SELECT
  product_id,
  revenue,
  ROUND(PERCENT_RANK() OVER (ORDER BY revenue), 4) AS pct_rank,
  ROUND(CUME_DIST()    OVER (ORDER BY revenue), 4) AS cume_dist
FROM product_sales
ORDER BY revenue DESC;
