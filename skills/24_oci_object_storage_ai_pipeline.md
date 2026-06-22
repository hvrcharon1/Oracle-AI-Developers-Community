# Skill 24 — OCI Object Storage: Loading Data into Oracle AI Pipelines

> **Capability:** Read files (CSV, JSON, Parquet, PDF) directly from OCI Object Storage buckets into Oracle Database tables using `DBMS_CLOUD` — the zero-ETL foundation for any scalable Oracle AI data pipeline.

---

## What It Is

`DBMS_CLOUD` is a built-in Oracle package on Autonomous Database (and installable on on-premises 19c+) that treats OCI Object Storage as a first-class data source. It eliminates the need for external ETL tools when ingesting raw data for AI training, embedding generation, or analytics.

---

## Prerequisites

- Oracle Autonomous Database **or** on-premises 19c+ with `DBMS_CLOUD` installed
- OCI Object Storage bucket containing your data files
- An OCI credential (API key or instance principal auth)

---

## Quick Start

### 1 — Create the OCI credential

```sql
BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
      credential_name => 'MY_OCI_CRED',
      user_ocid       => 'ocid1.user.oc1...',
      tenancy_ocid    => 'ocid1.tenancy.oc1...',
      private_key     => '<base64-pem-private-key>',
      fingerprint     => 'aa:bb:cc:dd:...'
  );
END;
/
```

> **Tip:** On Autonomous Database, prefer **instance principal** auth — no key management required:
> ```sql
> -- No credential needed; uses the database's OCI identity automatically
> ```

### 2 — Bulk load a CSV into a table

```sql
BEGIN
  DBMS_CLOUD.COPY_DATA(
      table_name      => 'CUSTOMER_DATA',
      credential_name => 'MY_OCI_CRED',
      file_uri_list   => 'https://objectstorage.us-chicago-1.oraclecloud.com'
                      || '/n/<namespace>/b/<bucket>/o/customers.csv',
      format          => JSON_OBJECT(
          'type'        VALUE 'CSV',
          'skipheaders' VALUE '1',
          'delimiter'   VALUE ',',
          'trimspaces'  VALUE 'rtrim',
          'rejectlimit' VALUE '100'
      )
  );
END;
/
```

### 3 — Load multiple files with a wildcard URI

```sql
BEGIN
  DBMS_CLOUD.COPY_DATA(
      table_name      => 'RAW_EVENTS',
      credential_name => 'MY_OCI_CRED',
      -- Load all JSON files in the prefix at once
      file_uri_list   => 'https://objectstorage.us-chicago-1.oraclecloud.com'
                      || '/n/<namespace>/b/<bucket>/o/events/*.json',
      format          => JSON_OBJECT(
          'type'        VALUE 'JSON',
          'rejectlimit' VALUE '50'
      )
  );
END;
/
```

### 4 — Query files in-place (no copy) via External Table

```sql
BEGIN
  DBMS_CLOUD.CREATE_EXTERNAL_TABLE(
      table_name      => 'RAW_EVENTS_EXT',
      credential_name => 'MY_OCI_CRED',
      file_uri_list   => 'https://objectstorage.us-chicago-1.oraclecloud.com'
                      || '/n/<namespace>/b/<bucket>/o/events/*.json',
      format          => JSON_OBJECT('type' VALUE 'JSON'),
      column_list     => 'event_id VARCHAR2(64), ts TIMESTAMP, payload CLOB'
  );
END;
/

-- Query directly — data is streamed from Object Storage on demand
SELECT event_id, ts
FROM   raw_events_ext
WHERE  rownum <= 100;
```

### 5 — Write Oracle query results back to Object Storage

```sql
BEGIN
  DBMS_CLOUD.EXPORT_DATA(
      credential_name => 'MY_OCI_CRED',
      file_uri_list   => 'https://objectstorage.us-chicago-1.oraclecloud.com'
                      || '/n/<namespace>/b/<bucket>/o/output/predictions.csv',
      query           => 'SELECT customer_id, prediction_score FROM ml_results',
      format          => JSON_OBJECT('type' VALUE 'CSV', 'header' VALUE TRUE)
  );
END;
/
```

---

## Common Patterns Reference

| Use Case | API |
|---|---|
| One-time bulk load | `DBMS_CLOUD.COPY_DATA` |
| Live query without copying | `DBMS_CLOUD.CREATE_EXTERNAL_TABLE` |
| Incremental load by partition | `DBMS_CLOUD.COPY_DATA` with prefix filter |
| Export results | `DBMS_CLOUD.EXPORT_DATA` |
| List bucket objects | `DBMS_CLOUD.LIST_OBJECTS` |
| Load Parquet | `COPY_DATA` with `'type' VALUE 'parquet'` |

---

## Monitoring & Diagnostics

```sql
-- Check status of recent load jobs
SELECT table_name, start_time, end_time, status, rows_loaded, rows_rejected
FROM   user_load_operations
ORDER BY start_time DESC
FETCH FIRST 10 ROWS ONLY;

-- Inspect rejected rows for a failed load
SELECT *
FROM   dbms_cloud$customer_data_reject
FETCH FIRST 20 ROWS ONLY;
```

---

## Key Tips

- Wildcard URIs (`*.csv`, `*.json`) load all matching files in one call — ideal for date-partitioned data.
- For **Parquet** files, set `'type' VALUE 'parquet'` in the format JSON; column mapping is automatic from the schema.
- Always set `rejectlimit` in production to tolerate bad rows without aborting the entire load.
- Use `CREATE_EXTERNAL_TABLE` for exploratory queries or very large files you do not want to copy permanently.
- Combine with `DBMS_VECTOR_CHAIN` (Skill 23) to build a full RAG ingestion pipeline: Object Storage → Oracle table → chunks → embeddings.

---

## References

- [Oracle Docs — DBMS_CLOUD](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/dbms-cloud-subprograms.html)
- [Loading Data into Autonomous Database](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/load-data.html)
