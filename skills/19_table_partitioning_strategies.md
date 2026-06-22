# Skill 19 — Table Partitioning Strategies

> **Capability:** Split large tables into independent, maintainable segments for dramatically faster queries, efficient maintenance windows, and automated data lifecycle management.

---

## Why Partition?

| Problem | Partitioning Solution |
|---|---|
| Full table scan on 10-year table for last month | **Partition pruning** reads only 1/120 of segments |
| Nightly archive of old data takes hours | **DROP/TRUNCATE PARTITION** — instant, no undo |
| Index rebuild blocks 3 hours of prod | **LOCAL indexes** on one partition only |
| Mixed hot/cold data on same storage | **Move partition** to cheap tier without app changes |

---

## Range Partitioning (Most Common — Date-Based)

```sql
CREATE TABLE sales_transactions (
  txn_id       NUMBER         NOT NULL,
  txn_date     DATE           NOT NULL,
  cust_id      NUMBER,
  amount       NUMBER(15,2),
  region       VARCHAR2(50),
  CONSTRAINT pk_sales PRIMARY KEY (txn_id, txn_date)
)
PARTITION BY RANGE (txn_date) (
  PARTITION p_2023_q1 VALUES LESS THAN (DATE '2023-04-01'),
  PARTITION p_2023_q2 VALUES LESS THAN (DATE '2023-07-01'),
  PARTITION p_2023_q3 VALUES LESS THAN (DATE '2023-10-01'),
  PARTITION p_2023_q4 VALUES LESS THAN (DATE '2024-01-01'),
  PARTITION p_2024_q1 VALUES LESS THAN (DATE '2024-04-01'),
  PARTITION p_future  VALUES LESS THAN (MAXVALUE)  -- catch-all
);
```

### Verify partition pruning in query plan
```sql
EXPLAIN PLAN FOR
  SELECT * FROM sales_transactions
  WHERE  txn_date BETWEEN DATE '2023-07-01' AND DATE '2023-09-30';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- Look for: Pstart=3 Pstop=3  (only partition 3 scanned)
```

---

## Interval Partitioning (Auto-Extend — Best Practice for Dates)

Interval partitioning creates new partitions automatically when data arrives — no manual `ADD PARTITION` needed:

```sql
CREATE TABLE audit_events (
  event_id    NUMBER GENERATED ALWAYS AS IDENTITY,
  event_ts    TIMESTAMP NOT NULL,
  event_type  VARCHAR2(50),
  payload     CLOB CHECK (payload IS JSON)
)
PARTITION BY RANGE (event_ts)
INTERVAL (NUMTOYMINTERVAL(1, 'MONTH'))  -- auto-create monthly partitions
(
  -- At least one seed partition required
  PARTITION p_before_2024
    VALUES LESS THAN (TIMESTAMP '2024-01-01 00:00:00')
);
-- Oracle creates SYS_P* partitions automatically as new months arrive
```

---

## List Partitioning (Discrete Values)

```sql
CREATE TABLE customer_accounts (
  acct_id     NUMBER PRIMARY KEY,
  region      VARCHAR2(20) NOT NULL,
  cust_name   VARCHAR2(100),
  balance     NUMBER(15,2)
)
PARTITION BY LIST (region) (
  PARTITION p_apac   VALUES ('IN', 'SG', 'AU', 'JP'),
  PARTITION p_emea   VALUES ('UK', 'DE', 'FR', 'AE'),
  PARTITION p_amer   VALUES ('US', 'CA', 'BR', 'MX'),
  PARTITION p_other  VALUES (DEFAULT)  -- everything else
);
```

---

## Composite Partitioning: Range-List & Range-Hash

```sql
-- Range-List: partition by month, sub-partition by region
CREATE TABLE orders_composite (
  order_id    NUMBER,
  order_date  DATE     NOT NULL,
  region      VARCHAR2(20),
  amount      NUMBER
)
PARTITION BY RANGE (order_date)
SUBPARTITION BY LIST (region)
SUBPARTITION TEMPLATE (
  SUBPARTITION sp_apac  VALUES ('IN','SG','AU','JP'),
  SUBPARTITION sp_emea  VALUES ('UK','DE','FR'),
  SUBPARTITION sp_amer  VALUES ('US','CA','BR'),
  SUBPARTITION sp_other VALUES (DEFAULT)
)(
  PARTITION p_2024_q1 VALUES LESS THAN (DATE '2024-04-01'),
  PARTITION p_2024_q2 VALUES LESS THAN (DATE '2024-07-01'),
  PARTITION p_future  VALUES LESS THAN (MAXVALUE)
);
```

---

## Partition Maintenance Operations

```sql
-- Add a new range partition
ALTER TABLE sales_transactions ADD PARTITION
  p_2024_q2 VALUES LESS THAN (DATE '2024-07-01');

-- Instantly archive (truncate) a quarter — no undo, instant
ALTER TABLE sales_transactions TRUNCATE PARTITION p_2023_q1;

-- Drop a partition (removes data + segment)
ALTER TABLE sales_transactions DROP PARTITION p_2023_q1;

-- Exchange partition with a staging table (fast bulk load)
ALTER TABLE sales_transactions
  EXCHANGE PARTITION p_2024_q1
  WITH TABLE sales_staging
  INCLUDING INDEXES WITHOUT VALIDATION;

-- Move a partition to a different tablespace (cold storage)
ALTER TABLE sales_transactions
  MOVE PARTITION p_2023_q1
  TABLESPACE ts_archive ONLINE;
```

---

## Local vs Global Indexes on Partitioned Tables

```sql
-- LOCAL index: one index segment per partition — PREFERRED for pruning
CREATE INDEX idx_sales_cust
  ON sales_transactions(cust_id)
  LOCAL;  -- index partition is collocated with table partition

-- GLOBAL index: single index spans all partitions
-- Good for unique constraints, bad for partition drops (invalidates)
CREATE UNIQUE INDEX idx_sales_txn
  ON sales_transactions(txn_id)
  GLOBAL;  -- spans all partitions

-- Update global indexes automatically on partition drop
ALTER TABLE sales_transactions
  DROP PARTITION p_2023_q1
  UPDATE GLOBAL INDEXES;  -- prevents index invalidation
```

---

## Inspect Partition Metadata

```sql
-- View all partitions and their row counts
SELECT partition_name,
       num_rows,
       blocks,
       ROUND(blocks * 8 / 1024, 1) AS size_mb,
       last_analyzed
FROM   user_tab_partitions
WHERE  table_name = 'SALES_TRANSACTIONS'
ORDER BY partition_position;

-- Check if a query will prune correctly
SELECT partition_name, partition_position
FROM   user_tab_partitions
WHERE  table_name = 'SALES_TRANSACTIONS'
AND    high_value LIKE '%2024%';
```

---

## Decision Guide

| Data Characteristic | Recommended Strategy |
|---|---|
| Growing time-series (logs, events) | Interval Range by date |
| Finite category values (region, status) | List |
| Random distribution, equal segment size | Hash |
| Time + category (reports by month × region) | Range-List composite |

---

## References

- [Oracle Docs — Partitioned Tables](https://docs.oracle.com/en/database/oracle/oracle-database/23/vldbg/partition-concepts.html)
- [Interval Partitioning Reference](https://docs.oracle.com/en/database/oracle/oracle-database/23/vldbg/manage_part_table.html)
- [Oracle Partitioning Advisor (DBMS_ADVISOR)](https://docs.oracle.com/en/database/oracle/oracle-database/23/arpls/DBMS_ADVISOR.html)
