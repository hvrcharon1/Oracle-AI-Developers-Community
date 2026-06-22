# Skill 25 — Reading EXPLAIN PLAN & SQL Monitoring

> **Capability:** Diagnose slow queries by reading Oracle execution plans and using SQL Monitor — the fastest path from "query is slow" to "here is exactly why and where."

---

## What It Is

Every SQL statement in Oracle goes through the **Cost-Based Optimizer (CBO)**, which selects the cheapest execution plan based on object statistics. Understanding how to read and influence that plan is the single highest-leverage performance skill an Oracle developer can have.

Oracle provides three complementary tools:

| Tool | When to Use |
|---|---|
| `EXPLAIN PLAN` + `DBMS_XPLAN.DISPLAY` | Quick offline estimate before running a query |
| `DBMS_XPLAN.DISPLAY_CURSOR` | Actual runtime plan pulled from the shared SQL area |
| SQL Monitor (`DBMS_SQLTUNE.REPORT_SQL_MONITOR`) | Real-time and post-execution analysis with actual row counts |

---

## Method A — EXPLAIN PLAN (offline estimate)

```sql
EXPLAIN PLAN FOR
SELECT c.customer_name, SUM(o.total_amount)
FROM   customers c
JOIN   orders o ON c.customer_id = o.customer_id
WHERE  o.order_date >= DATE '2025-01-01'
GROUP BY c.customer_name;

-- Pretty-print with cardinality, cost, and predicate info
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    'plan_table', NULL, 'TYPICAL +PREDICATE'
));
```

---

## Method B — DISPLAY_CURSOR (actual runtime plan)

```sql
-- 1. Run the target query first so it lands in the shared SQL area
SELECT c.customer_name, SUM(o.total_amount)
FROM   customers c JOIN orders o ON c.customer_id = o.customer_id
WHERE  o.order_date >= DATE '2025-01-01'
GROUP BY c.customer_name;

-- 2. Grab the SQL ID from the cursor cache
SELECT sql_id, child_number, sql_text
FROM   v$sql
WHERE  sql_text LIKE '%customer_name%'
  AND  sql_text NOT LIKE '%v$sql%'
FETCH FIRST 3 ROWS ONLY;

-- 3. Display the plan with actual vs. estimated row counts
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
    sql_id      => '<sql_id>',
    child_number => 0,
    format       => 'ALLSTATS LAST +PEEKED_BINDS'
));
```

> **Tip:** `ALLSTATS LAST` shows `A-Rows` (actual) alongside `E-Rows` (estimated). A large gap signals stale stats or bind-peeking issues.

---

## Method C — SQL Monitor (real-time execution)

```sql
-- Text report (works in SQL*Plus / SQLcl)
SELECT DBMS_SQLTUNE.REPORT_SQL_MONITOR(
    sql_id       => '<your_sql_id>',
    type         => 'TEXT',
    report_level => 'ALL'
) AS report
FROM dual;

-- Interactive HTML report (open in a browser)
SELECT DBMS_SQLTUNE.REPORT_SQL_MONITOR(
    sql_id => '<your_sql_id>',
    type   => 'ACTIVE'
) FROM dual;
```

SQL Monitor activates automatically for any statement running longer than **5 seconds** or executing in parallel. It requires the **Diagnostics + Tuning Pack** license on Enterprise Edition.

---

## Reading the Plan Output

```
----------------------------------------------------------------------
| Id | Operation               | Name        | E-Rows | A-Rows | Cost |
----------------------------------------------------------------------
|  0 | SELECT STATEMENT        |             |        |   1234 |  842 |
|  1 |  HASH GROUP BY          |             |   1234 |   1234 |  842 |
|* 2 |   HASH JOIN             |             |   8521 |   8521 |  810 |
|  3 |    TABLE ACCESS FULL    | CUSTOMERS   |   5000 |   5000 |   12 |
|* 4 |    TABLE ACCESS FULL    | ORDERS      | 120000 | 120000 |  790 |
----------------------------------------------------------------------
Predicate Information:
  2 - access("C"."CUSTOMER_ID"="O"."CUSTOMER_ID")
  4 - filter("O"."ORDER_DATE">=DATE '2025-01-01')
```

**Warning signs to look for:**

| Pattern | Meaning | Likely Fix |
|---|---|---|
| `TABLE ACCESS FULL` on a large table | Missing or ignored index | Add index; check bind-peeking |
| `E-Rows` ≪ `A-Rows` by 10×+ | Stale statistics | `DBMS_STATS.GATHER_TABLE_STATS` |
| `NESTED LOOPS` with millions of inner lookups | Row estimate too low | Rewrite or hint to `HASH JOIN` |
| `CARTESIAN MERGE JOIN` | Missing join predicate | Verify your WHERE clause |
| High `Temp` space in SQL Monitor | Sort/hash spill to disk | Increase `PGA_AGGREGATE_TARGET` |

---

## Gather Fresh Statistics

```sql
-- Gather stats on a single table (cascade to indexes, with histograms)
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(
      ownname    => USER,
      tabname    => 'ORDERS',
      cascade    => TRUE,
      method_opt => 'FOR ALL COLUMNS SIZE AUTO'
  );
END;
/

-- Gather stats on an entire schema
BEGIN
  DBMS_STATS.GATHER_SCHEMA_STATS(
      ownname    => USER,
      cascade    => TRUE
  );
END;
/
```

---

## Influencing the Plan with Hints (last resort)

```sql
SELECT /*+ USE_HASH(c o) INDEX(o idx_orders_date) LEADING(o c) */
       c.customer_name,
       SUM(o.total_amount)
FROM   customers c
JOIN   orders o ON c.customer_id = o.customer_id
WHERE  o.order_date >= DATE '2025-01-01'
GROUP BY c.customer_name;
```

---

## Key Tips

- Always compare **E-Rows vs. A-Rows** first — that single comparison reveals 80 % of performance problems.
- `ALLSTATS LAST` in `DISPLAY_CURSOR` is the most useful format: it shows actual rows, actual executions, elapsed time, and I/O per operation.
- Prefer fixing statistics over adding hints; hints break silently when the schema changes.
- SQL Monitor generates the richest report but requires Diagnostics + Tuning Pack — use `DISPLAY_CURSOR` on SE2 or when the license is unavailable.

---

## References

- [Oracle Docs — DBMS_XPLAN](https://docs.oracle.com/en/database/oracle/oracle-database/23/arpls/DBMS_XPLAN.html)
- [Oracle Docs — SQL Monitor](https://docs.oracle.com/en/database/oracle/oracle-database/23/tgsql/monitoring-database-operations.html)
- [Oracle Docs — DBMS_STATS](https://docs.oracle.com/en/database/oracle/oracle-database/23/arpls/DBMS_STATS.html)
