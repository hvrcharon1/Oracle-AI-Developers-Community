# Skill 17 — Analytical (Window) Functions

> **Capability:** Compute rankings, running totals, moving averages, lead/lag comparisons, and string aggregations across partitions of data — entirely in SQL, with no self-joins or correlated subqueries.

---

## What They Are

Analytical functions (also called **window functions**) operate on a "window" of rows related to the current row, without collapsing the result set the way `GROUP BY` does. Every row in the output retains its individual identity while also seeing aggregate or positional values across its peer group.

Syntax skeleton:
```sql
function_name(args) OVER (
  [PARTITION BY partition_cols]
  [ORDER BY order_cols]
  [ROWS | RANGE BETWEEN start AND end]
)
```

---

## Ranking Functions

```sql
SELECT
  emp_id,
  dept_id,
  salary,
  -- Gaps on ties (1,2,2,4)
  RANK()        OVER (PARTITION BY dept_id ORDER BY salary DESC) AS dept_rank,
  -- No gaps on ties (1,2,2,3)
  DENSE_RANK()  OVER (PARTITION BY dept_id ORDER BY salary DESC) AS dept_dense_rank,
  -- Unique sequential row number regardless of ties
  ROW_NUMBER()  OVER (PARTITION BY dept_id ORDER BY salary DESC) AS dept_row_num,
  -- Divide into N equal buckets
  NTILE(4)      OVER (ORDER BY salary DESC)                       AS salary_quartile
FROM employees
ORDER BY dept_id, salary DESC;
```

**Practical pattern — Top-N per group (no subquery needed in 23ai):**
```sql
-- Top 3 earners per department
SELECT *
FROM (
  SELECT e.*,
         RANK() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS rnk
  FROM   employees e
)
WHERE rnk <= 3;
```

---

## Running Totals & Cumulative Aggregates

```sql
SELECT
  txn_date,
  amount,
  -- Running total (all rows from start up to current)
  SUM(amount) OVER (
    ORDER BY txn_date
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS running_total,
  -- Running average
  ROUND(AVG(amount) OVER (
    ORDER BY txn_date
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ), 2) AS running_avg,
  -- Running max
  MAX(amount) OVER (
    ORDER BY txn_date
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS running_max
FROM transactions
ORDER BY txn_date;
```

---

## Moving / Rolling Averages

```sql
SELECT
  sale_date,
  daily_revenue,
  -- 7-day rolling average (current + 6 preceding rows)
  ROUND(AVG(daily_revenue) OVER (
    ORDER BY sale_date
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ), 2) AS ma_7day,
  -- 30-day rolling average
  ROUND(AVG(daily_revenue) OVER (
    ORDER BY sale_date
    ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
  ), 2) AS ma_30day
FROM daily_sales
ORDER BY sale_date;
```

---

## LAG & LEAD — Comparing Adjacent Rows

```sql
SELECT
  sale_date,
  daily_revenue,
  -- Value from the previous row
  LAG(daily_revenue, 1, 0) OVER (ORDER BY sale_date)       AS prev_day_revenue,
  -- Value from 2 rows ahead
  LEAD(daily_revenue, 2)   OVER (ORDER BY sale_date)       AS revenue_2days_ahead,
  -- Day-over-day change %
  ROUND(
    (daily_revenue - LAG(daily_revenue) OVER (ORDER BY sale_date))
    / NULLIF(LAG(daily_revenue) OVER (ORDER BY sale_date), 0) * 100,
    1
  ) AS dod_change_pct
FROM daily_sales
ORDER BY sale_date;
```

---

## FIRST_VALUE & LAST_VALUE

```sql
SELECT
  dept_id,
  emp_id,
  salary,
  -- Highest salary in the department
  FIRST_VALUE(salary) OVER (
    PARTITION BY dept_id
    ORDER BY salary DESC
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
  ) AS dept_max_salary,
  -- Lowest salary in the department
  LAST_VALUE(salary) OVER (
    PARTITION BY dept_id
    ORDER BY salary DESC
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
  ) AS dept_min_salary,
  -- Difference from dept max
  FIRST_VALUE(salary) OVER (
    PARTITION BY dept_id ORDER BY salary DESC
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
  ) - salary AS gap_from_top
FROM employees;
```

---

## LISTAGG — String Aggregation

```sql
-- Comma-separated list of employees per department
SELECT
  dept_id,
  COUNT(*)                                                      AS headcount,
  LISTAGG(last_name, ', ')
    WITHIN GROUP (ORDER BY last_name)                           AS members,
  -- LISTAGG with OVERFLOW clause (23ai) — truncates instead of error
  LISTAGG(last_name, ', ' ON OVERFLOW TRUNCATE '...' WITH COUNT)
    WITHIN GROUP (ORDER BY last_name)                           AS members_safe
FROM employees
GROUP BY dept_id
ORDER BY dept_id;

-- LISTAGG as window function (no GROUP BY needed)
SELECT
  emp_id,
  dept_id,
  LISTAGG(last_name, ', ') WITHIN GROUP (ORDER BY last_name)
    OVER (PARTITION BY dept_id) AS dept_members
FROM employees;
```

---

## Percent & Cumulative Distribution

```sql
SELECT
  product_id,
  revenue,
  -- What fraction of rows have a lower value
  ROUND(PERCENT_RANK() OVER (ORDER BY revenue), 4) AS pct_rank,
  -- Cumulative distribution (fraction of rows <= current)
  ROUND(CUME_DIST()    OVER (ORDER BY revenue), 4) AS cume_dist
FROM product_sales
ORDER BY revenue DESC;
```

---

## Performance Notes

| Technique | When to Prefer |
|---|---|
| `PARTITION BY` | Always scope to the smallest meaningful group |
| `ROWS` vs `RANGE` | Use `ROWS` for moving windows; `RANGE` for date intervals |
| Avoid re-partitioning | Reuse the same OVER() clause in a CTE; optimizer may cache |
| Index on ORDER BY column | Critical for large partitions — reduces sort cost |

---

## References

- [Oracle SQL Functions — Analytic](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/Analytic-Functions.html)
- [Oracle SQL Language Reference — Window Functions](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/SELECT.html)
