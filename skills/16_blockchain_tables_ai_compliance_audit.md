# Skill 16 — Blockchain Tables + AI Compliance Audit (Oracle 23ai)

> **Capability:** Create tamper-evident, cryptographically chained audit trails in Oracle Database and use AI to detect anomalies, generate compliance reports, and answer regulatory questions in natural language.

---

## What It Is

**Oracle Blockchain Tables** (introduced in Oracle 21c, enhanced in 23ai) are append-only tables where every row is cryptographically chained to the previous row using SHA-512 hashes. Rows can never be updated or deleted — even by DBAs. This makes them perfect for:

- HIPAA / SOX / PCI-DSS audit trails
- Financial transaction immutability
- Healthcare record provenance
- AI agent action logs

Combined with **SELECT AI** and **OCI Generative AI**, blockchain tables become a queryable compliance brain.

---

## Architecture

```
 ┌──────────────────────────────────────────────────────────┐
 │                    Application Layer                      │
 │  Agent Actions  │  API Calls  │  PL/SQL Events           │
 └────────────────────────┬─────────────────────────────────┘
                          │ INSERT only
 ┌────────────────────────▼─────────────────────────────────┐
 │          BLOCKCHAIN TABLE (audit_ledger_bt)               │
 │  row 1: [data | prev_hash=NULL | SHA512(row1_content)]   │
 │  row 2: [data | prev_hash=SHA512(row1) | SHA512(row2)]   │
 │  row N: [data | prev_hash=SHA512(rowN-1) | SHA512(rowN)] │
 │  ← Tampering breaks the chain; Oracle verifies on demand │
 └────────────────────────┬─────────────────────────────────┘
                          │
          ┌───────────────┴───────────────┐
          │  SELECT AI Compliance Engine  │
          │  "Any HIPAA violations?"      │
          │  "Summarize last 30d changes" │
          └───────────────────────────────┘
```

---

## Hands-On

### 1. Create the Blockchain Table

```sql
CREATE BLOCKCHAIN TABLE audit_ledger_bt (
  event_id     NUMBER GENERATED ALWAYS AS IDENTITY,
  event_type   VARCHAR2(50)   NOT NULL,
  entity_type  VARCHAR2(50),
  entity_id    VARCHAR2(100),
  actor_user   VARCHAR2(100),
  actor_ip     VARCHAR2(45),
  payload      CLOB           CHECK (payload IS JSON),
  event_ts     TIMESTAMP      DEFAULT SYSTIMESTAMP
)
NO DROP UNTIL 90 DAYS IDLE     -- table can't be dropped until 90 days of no inserts
NO DELETE LOCKED               -- rows can NEVER be deleted
HASHING USING "SHA2_512"       -- cryptographic algorithm
VERSION "v1";
```

### 2. Log Events from PL/SQL

```sql
CREATE OR REPLACE PROCEDURE log_audit_event(
  p_event_type  VARCHAR2,
  p_entity_type VARCHAR2,
  p_entity_id   VARCHAR2,
  p_payload     CLOB DEFAULT '{}'
) AS
BEGIN
  INSERT INTO audit_ledger_bt
    (event_type, entity_type, entity_id, actor_user, actor_ip, payload)
  VALUES (
    p_event_type,
    p_entity_type,
    p_entity_id,
    SYS_CONTEXT('USERENV','SESSION_USER'),
    SYS_CONTEXT('USERENV','IP_ADDRESS'),
    p_payload
  );
  -- No COMMIT needed inside trigger or agent tool; caller commits
END;
/

-- Usage
BEGIN
  log_audit_event(
    'PHI_ACCESS',
    'PATIENT',
    'PAT-00423',
    JSON_OBJECT(
      'field_accessed' VALUE 'diagnosis',
      'reason'         VALUE 'treatment',
      'accessed_by'    VALUE 'dr_sharma'
    )
  );
  COMMIT;
END;
/
```

### 3. Verify Chain Integrity

```sql
-- Verify all rows in the blockchain table (returns error if tampered)
DECLARE
  v_result   RAW(128);
  v_error    VARCHAR2(4000);
BEGIN
  DBMS_BLOCKCHAIN_TABLE.VERIFY_ROWS(
    schema_name    => USER,
    table_name     => 'AUDIT_LEDGER_BT',
    number_of_rows => NULL,  -- verify all rows
    inst_id        => NULL,
    chain_id       => NULL,
    row_id         => NULL,
    hash_algorithm => 'SHA2_512'
  );
  DBMS_OUTPUT.PUT_LINE('Chain verified: INTACT ✓');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Chain BROKEN: ' || SQLERRM);
END;
/
```

### 4. AI Compliance Report via SELECT AI

```sql
-- Natural language query over the immutable audit log
SELECT AI NARRATE
  'Generate a HIPAA compliance summary for the last 30 days.
   Include: total PHI access events, unique users who accessed PHI,
   any access events outside business hours (9am–6pm IST),
   and flag any single user who accessed more than 50 patient records'
FROM audit_ledger_bt
USING PROFILE ai_profile;
```

### 5. AI Anomaly Detection on the Ledger

```sql
-- Find access pattern anomalies with SELECT AI
SELECT AI
  'Which users show access patterns significantly different from
   their 30-day baseline in the last 48 hours? Focus on
   unusually high volume, off-hours access, or new entity types.'
FROM audit_ledger_bt
USING PROFILE ai_profile;
```

---

## Immutability Matrix

| Operation | Blockchain Table | Regular Table |
|---|---|---|
| INSERT | ✅ Allowed | ✅ Allowed |
| UPDATE | ❌ Blocked | ✅ Allowed |
| DELETE | ❌ Blocked (LOCKED) | ✅ Allowed |
| TRUNCATE | ❌ Blocked | ✅ Allowed |
| DROP | ❌ Only after idle period | ✅ Allowed |
| DBA override | ❌ Not possible | ⚠️ Possible |

---

## Compliance Certifications Supported

- **HIPAA** — PHI access audit trail
- **SOX** — Financial transaction immutability
- **PCI-DSS** — Cardholder data access logs
- **GDPR** — Data processing activity records
- **ISO 27001** — Information security event logging

---

## References

- [Oracle Docs — Blockchain Tables](https://docs.oracle.com/en/database/oracle/oracle-database/23/admin/managing-tables.html#GUID-43470B0C-DE4A-4640-9278-B066901C3926)
- [DBMS_BLOCKCHAIN_TABLE Reference](https://docs.oracle.com/en/database/oracle/oracle-database/23/arpls/DBMS_BLOCKCHAIN_TABLE.html)
- [Blockchain Tables LiveLab](https://apexapps.oracle.com/pls/apex/r/dbpm/livelabs/view-workshop?wid=752)
- [Oracle Security Blog — Immutable Tables](https://blogs.oracle.com/cloudsecurity/)
