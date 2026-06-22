# Skill 13 — SQL/PGQ Property Graph Queries (Oracle 23ai)

> **Capability:** Run ISO-standard graph pattern matching queries directly inside Oracle Database — no separate graph engine, no data export.

---

## What It Is

Oracle 23ai implements **SQL/PGQ** (SQL Property Graph Queries), the ISO/IEC 9075-16 graph query standard, natively inside the SQL engine. You define a property graph over existing relational tables and then query it with the `GRAPH_TABLE` operator and `MATCH` clause — all in regular SQL.

Use cases: fraud detection, supply chain tracing, social network analysis, dependency mapping, knowledge graphs.

---

## Architecture

```
  Relational Tables (nodes + edges)
  ┌──────────┐     ┌──────────────┐     ┌──────────┐
  │ ACCOUNTS │────▶│  TRANSFERS   │────▶│ ACCOUNTS │
  │  (nodes) │     │  (edges)     │     │  (nodes) │
  └──────────┘     └──────────────┘     └──────────┘
          │                                    │
          └─────── PROPERTY GRAPH ─────────────┘
                   bank_network_graph
                         │
                   SQL/PGQ MATCH
                   GRAPH_TABLE()
```

---

## Hands-On: Fraud Detection Graph

### 1. Create Node and Edge Tables

```sql
CREATE TABLE accounts (
  acct_id   NUMBER PRIMARY KEY,
  holder    VARCHAR2(100),
  country   VARCHAR2(50),
  risk_flag VARCHAR2(10) DEFAULT 'LOW'
);

CREATE TABLE transfers (
  txn_id    NUMBER PRIMARY KEY,
  from_acct NUMBER REFERENCES accounts(acct_id),
  to_acct   NUMBER REFERENCES accounts(acct_id),
  amount    NUMBER(15,2),
  txn_date  DATE DEFAULT SYSDATE
);

-- Sample data
INSERT INTO accounts VALUES (1,'Alice','US','LOW');
INSERT INTO accounts VALUES (2,'Shell Corp A','KY','HIGH');
INSERT INTO accounts VALUES (3,'Bob','IN','LOW');
INSERT INTO transfers VALUES (101,1,2,50000,SYSDATE-1);
INSERT INTO transfers VALUES (102,2,3,49000,SYSDATE);
COMMIT;
```

### 2. Define the Property Graph

```sql
CREATE PROPERTY GRAPH bank_network
  VERTEX TABLES (
    accounts
      KEY (acct_id)
      PROPERTIES (acct_id, holder, country, risk_flag)
  )
  EDGE TABLES (
    transfers
      KEY (txn_id)
      SOURCE      KEY (from_acct) REFERENCES accounts (acct_id)
      DESTINATION KEY (to_acct)   REFERENCES accounts (acct_id)
      PROPERTIES  (txn_id, amount, txn_date)
  );
```

### 3. Detect Money Laundering Chains (Hop Patterns)

```sql
-- Find 2-hop transfer chains where intermediate node is HIGH risk
SELECT  src.holder  AS origin,
        mid.holder  AS intermediary,
        dst.holder  AS destination,
        e1.amount   AS first_transfer,
        e2.amount   AS second_transfer
FROM    GRAPH_TABLE (
          bank_network
          MATCH (src IS accounts) -[e1 IS transfers]->
                (mid IS accounts) -[e2 IS transfers]->
                (dst IS accounts)
          WHERE mid.risk_flag = 'HIGH'
            AND e2.amount >= e1.amount * 0.9  -- layering pattern
          COLUMNS (
            src.holder,
            mid.holder,
            dst.holder,
            e1.amount,
            e2.amount
          )
        );
```

### 4. Find Shortest Path Between Two Accounts

```sql
SELECT path_length, intermediaries
FROM   GRAPH_TABLE (
         bank_network
         MATCH SHORTEST
           (a1 IS accounts WHERE a1.acct_id = 1)
           -[IS transfers]->+
           (a2 IS accounts WHERE a2.acct_id = 3)
         COLUMNS (
           COUNT(*) AS path_length,
           LISTAGG(v.holder, ' → ')
             WITHIN GROUP (ORDER BY 1) AS intermediaries
         )
       );
```

---

## AI-Augmented Graph Analysis

```sql
-- Use SELECT AI to describe suspicious patterns
SELECT AI NARRATE
  'In the bank_network property graph, summarize any accounts
   that appear as intermediaries in more than 3 transfer chains
   and explain why they might be high risk'
USING PROFILE ai_profile;
```

---

## When to Use SQL/PGQ vs. Oracle Graph Server

| Scenario | SQL/PGQ | Oracle Graph Server (PGQL) |
|---|---|---|
| Simple hop queries | ✅ Perfect fit | Overkill |
| Complex analytics (PageRank, community detection) | Limited | ✅ Use PGQL |
| Embedded in APEX / ORDS app | ✅ Native SQL | Requires separate server |
| Real-time fraud detection | ✅ Low latency | Higher overhead |

---

## References

- [Oracle Docs — SQL/PGQ](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/graph_table-operator.html)
- [ISO/IEC 9075-16:2023 — SQL Property Graph Queries](https://www.iso.org/standard/76120.html)
- [LiveLab: Property Graph with SQL/PGQ](https://apexapps.oracle.com/pls/apex/r/dbpm/livelabs/view-workshop?wid=3773)
