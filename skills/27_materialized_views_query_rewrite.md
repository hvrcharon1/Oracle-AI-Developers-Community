# Skill 27 — Materialized Views & Query Rewrite

> **Capability:** Pre-compute and cache expensive aggregations or joins as a Materialized View, then let Oracle transparently redirect incoming queries to the cached result — delivering 10×–1000× speedups on analytical workloads with zero application code changes.

---

## What It Is

A **Materialized View (MV)** stores the *result* of a query as a physical table. Unlike a regular view (which re-executes every time), an MV is refreshed on a schedule or on-commit. **Query Rewrite** lets Oracle's CBO automatically substitute an MV when it can satisfy an incoming query — transparently, without changing application SQL.

---

## Quick Start

### 1 — Create a fast-refresh aggregation MV

```sql
-- A Materialized View Log is required on the source table for FAST refresh
CREATE MATERIALIZED VIEW LOG ON orders
WITH PRIMARY KEY, ROWID, SEQUENCE
INCLUDING NEW VALUES;

-- Create the MV: refreshes incrementally after every COMMIT
CREATE MATERIALIZED VIEW mv_daily_sales
BUILD IMMEDIATE
REFRESH FAST ON COMMIT
ENABLE QUERY REWRITE
AS
SELECT
    TRUNC(order_date)   AS sale_day,
    product_id,
    SUM(total_amount)   AS revenue,
    COUNT(*)            AS order_count
FROM orders
GROUP BY TRUNC(order_date), product_id;
```

### 2 — Verify query rewrite fired

```sql
-- A plain query against the base table ...
SELECT TRUNC(order_date), SUM(total_amount)
FROM   orders
GROUP BY TRUNC(order_date);

-- ... should show the MV in the execution plan, not a FULL scan of ORDERS:
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(FORMAT => 'BASIC'));
-- Look for:  MAT_VIEW REWRITE ACCESS FULL | MV_DAILY_SALES
```

### 3 — Manual and scheduled refresh

```sql
-- Complete refresh (truncate-and-reload) — works with any query complexity
EXEC DBMS_MVIEW.REFRESH('MV_DAILY_SALES', 'C');

-- Fast (incremental) refresh — uses the MV log
EXEC DBMS_MVIEW.REFRESH('MV_DAILY_SALES', 'F');

-- Schedule nightly refresh at 02:00 with DBMS_SCHEDULER
BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
      job_name        => 'REFRESH_MV_DAILY_SALES',
      job_type        => 'PLSQL_BLOCK',
      job_action      => 'BEGIN DBMS_MVIEW.REFRESH(''MV_DAILY_SALES'', ''F''); END;',
      repeat_interval => 'CRON:0 2 * * *',
      enabled         => TRUE
  );
END;
/
```

---

## Refresh Modes Compared

| Mode | Trigger | Speed | Requirements |
|---|---|---|---|
| `FAST ON COMMIT` | After every DML commit | Fastest overall | MV log; simple aggregations |
| `FAST ON DEMAND` | Manual / scheduled | Flexible | MV log on all base tables |
| `COMPLETE ON DEMAND` | Manual / scheduled | Slowest; always works | None |
| `FORCE ON DEMAND` | Tries fast, falls back to complete | Safe default | MV log preferred |

---

## Pre-Built Feature Store for ML Workloads

MVs are ideal as **offline feature stores** — compute expensive aggregations once, score fast:

```sql
CREATE MATERIALIZED VIEW mv_customer_features
REFRESH COMPLETE ON DEMAND
ENABLE QUERY REWRITE
AS
SELECT
    customer_id,
    COUNT(*)                                              AS total_orders,
    SUM(total_amount)                                     AS lifetime_value,
    ROUND(AVG(total_amount), 2)                           AS avg_order_value,
    MAX(order_date)                                       AS last_order_date,
    TRUNC(SYSDATE) - TRUNC(MAX(order_date))              AS days_since_last_order,
    COUNT(DISTINCT product_id)                            AS distinct_products
FROM orders
GROUP BY customer_id;

-- ML model scores against pre-computed features — zero real-time aggregation cost
SELECT f.customer_id,
       f.lifetime_value,
       PREDICTION(churn_model USING f.*) AS churn_probability
FROM   mv_customer_features f
WHERE  f.days_since_last_order BETWEEN 30 AND 90;
```

---

## Multi-Table Join MV (Complete Refresh)

```sql
CREATE MATERIALIZED VIEW mv_order_detail_summary
REFRESH COMPLETE ON DEMAND
ENABLE QUERY REWRITE
AS
SELECT
    o.order_id,
    c.customer_name,
    p.product_name,
    o.total_amount,
    o.order_date,
    r.region_name
FROM  orders     o
JOIN  customers  c  ON c.customer_id  = o.customer_id
JOIN  products   p  ON p.product_id   = o.product_id
JOIN  regions    r  ON r.region_id    = c.region_id;
```

> **Note:** Fast refresh on joins requires `WITH ROWID` in the MV logs, and the MV must include the `ROWID` of each joined table. Use `COMPLETE` refresh for complex joins to avoid these constraints.

---

## Diagnostics

```sql
-- Check MV freshness and state
SELECT mview_name, last_refresh_date, last_refresh_type, staleness, compile_state
FROM   user_mviews
ORDER BY mview_name;

-- Understand why query rewrite did NOT fire
ALTER SESSION SET QUERY_REWRITE_ENABLED   = TRUE;
ALTER SESSION SET QUERY_REWRITE_INTEGRITY = TRUSTED;

-- Explain rewrite eligibility
BEGIN
  DBMS_MVIEW.EXPLAIN_REWRITE(
      query     => q'[SELECT TRUNC(order_date), SUM(total_amount)
                      FROM orders GROUP BY TRUNC(order_date)]',
      mv_name   => 'MV_DAILY_SALES',
      statement_id => 'QR_TEST'
  );
END;
/
SELECT message FROM rewrite_table WHERE statement_id = 'QR_TEST';
```

---

## Key Tips

- `ENABLE QUERY REWRITE` requires the `QUERY REWRITE` system privilege and `QUERY_REWRITE_ENABLED = TRUE` at session or system level.
- Fast refresh only works with **simple** query structures (single table, or star schema with specific constraints). Use `COMPLETE` for complex joins.
- For AI feature stores, `ON DEMAND` + a nightly `DBMS_SCHEDULER` job is the most practical pattern.
- Partition an MV that mirrors a partitioned base table to enable partition-level refresh, dramatically reducing refresh time on large datasets.
- A `STALE` MV can still be used for query rewrite when `QUERY_REWRITE_INTEGRITY = STALE_TOLERATED` — useful during refresh windows.

---

## References

- [Oracle Docs — CREATE MATERIALIZED VIEW](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/CREATE-MATERIALIZED-VIEW.html)
- [Oracle Docs — DBMS_MVIEW](https://docs.oracle.com/en/database/oracle/oracle-database/23/arpls/DBMS_MVIEW.html)
- [Oracle Docs — Query Rewrite](https://docs.oracle.com/en/database/oracle/oracle-database/23/dwhsg/basic-query-rewrite.html)
