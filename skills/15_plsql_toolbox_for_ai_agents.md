# Skill 15 — PL/SQL Toolbox for AI Agents

> **Capability:** Build robust, type-safe, observable function tools in PL/SQL that AI agents (Claude, LangChain, OpenAI, DBMS_CLOUD_AI_AGENT) can discover, call, and chain autonomously.

---

## What It Is

AI agents are only as powerful as the tools they can call. This skill covers production patterns for exposing Oracle Database capabilities as **agent-callable tool functions** — with proper input validation, structured JSON output, error contracts, and OTel-compatible logging — all written in PL/SQL without leaving the database.

---

## Tool Design Principles

| Principle | Why It Matters for Agents |
|---|---|
| Single responsibility | Agents compose tools; fat tools break chaining |
| JSON in / JSON out | LLM-native interface, schema-describable |
| Never raise unhandled exceptions | Agents need error JSON, not ORA-XXXXX strings |
| Idempotent where possible | Agents may retry on timeout |
| Structured logging | Essential for agent observability / replay |

---

## Pattern 1 — Core Tool Wrapper Template

```sql
CREATE OR REPLACE FUNCTION agent_tool_lookup_customer(
  p_params IN CLOB  -- JSON: {"email": "hr@datacules.io"}
) RETURN CLOB        -- JSON: {"status":"ok", "data":{...}} or {"status":"error",...}
AS
  v_email     VARCHAR2(200);
  v_result    CLOB;
  v_cust_id   NUMBER;
  v_name      VARCHAR2(100);
BEGIN
  -- 1. Parse input
  v_email := JSON_VALUE(p_params, '$.email');

  IF v_email IS NULL THEN
    RETURN JSON_OBJECT(
      'status' VALUE 'error',
      'code'   VALUE 'MISSING_PARAM',
      'message' VALUE 'email is required'
    );
  END IF;

  -- 2. Execute business logic
  SELECT cust_id, name
  INTO   v_cust_id, v_name
  FROM   customers
  WHERE  email = LOWER(v_email)
  AND    ROWNUM = 1;

  -- 3. Return structured success
  RETURN JSON_OBJECT(
    'status' VALUE 'ok',
    'data'   VALUE JSON_OBJECT(
      'cust_id' VALUE v_cust_id,
      'name'    VALUE v_name,
      'email'   VALUE v_email
    )
  );

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN JSON_OBJECT(
      'status'  VALUE 'error',
      'code'    VALUE 'NOT_FOUND',
      'message' VALUE 'No customer found for ' || v_email
    );
  WHEN OTHERS THEN
    RETURN JSON_OBJECT(
      'status'  VALUE 'error',
      'code'    VALUE 'INTERNAL',
      'message' VALUE SQLERRM
    );
END;
/
```

---

## Pattern 2 — Tool Registry Table

Make tools self-describing so agents can discover them dynamically:

```sql
CREATE TABLE agent_tool_registry (
  tool_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tool_name     VARCHAR2(100) UNIQUE NOT NULL,
  description   VARCHAR2(500),
  input_schema  CLOB CHECK (input_schema IS JSON),
  output_schema CLOB CHECK (output_schema IS JSON),
  plsql_func    VARCHAR2(200),
  active        VARCHAR2(1) DEFAULT 'Y',
  created_at    TIMESTAMP DEFAULT SYSTIMESTAMP
);

INSERT INTO agent_tool_registry
  (tool_name, description, input_schema, output_schema, plsql_func)
VALUES (
  'lookup_customer',
  'Find a customer record by email address',
  '{"type":"object","properties":{"email":{"type":"string","format":"email"}},"required":["email"]}',
  '{"type":"object","properties":{"status":{"type":"string"},"data":{"type":"object"}}}',
  'AGENT_TOOL_LOOKUP_CUSTOMER'
);
COMMIT;
```

---

## Pattern 3 — Universal Tool Dispatcher

One entry point for all agent tool calls:

```sql
CREATE OR REPLACE FUNCTION agent_dispatch(
  p_tool_name IN VARCHAR2,
  p_params    IN CLOB DEFAULT '{}'
) RETURN CLOB AS
  v_func    VARCHAR2(200);
  v_result  CLOB;
BEGIN
  -- Lookup tool in registry
  SELECT plsql_func
  INTO   v_func
  FROM   agent_tool_registry
  WHERE  tool_name = p_tool_name
  AND    active = 'Y';

  -- Dynamic dispatch (safe: only registered functions)
  EXECUTE IMMEDIATE
    'BEGIN :1 := ' || v_func || '(:2); END;'
  USING OUT v_result, IN p_params;

  -- Audit log
  INSERT INTO agent_tool_audit
    (tool_name, params_hash, result_status, called_at)
  VALUES (
    p_tool_name,
    ORA_HASH(p_params),
    JSON_VALUE(v_result, '$.status'),
    SYSTIMESTAMP
  );
  COMMIT;

  RETURN v_result;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN JSON_OBJECT(
      'status'  VALUE 'error',
      'code'    VALUE 'UNKNOWN_TOOL',
      'message' VALUE 'Tool not registered: ' || p_tool_name
    );
  WHEN OTHERS THEN
    RETURN JSON_OBJECT(
      'status'  VALUE 'error',
      'code'    VALUE 'DISPATCH_ERROR',
      'message' VALUE SQLERRM
    );
END;
/
```

---

## Pattern 4 — Register with DBMS_CLOUD_AI_AGENT

```sql
-- Expose the dispatcher as an Oracle AI Agent tool
BEGIN
  DBMS_CLOUD_AI.CREATE_AGENT_TOOL(
    tool_name        => 'oracle_dispatcher',
    tool_description => 'Universal Oracle DB tool dispatcher. ' ||
                        'Input: {tool_name, params}. ' ||
                        'Returns JSON with status and data.',
    tool_spec        => JSON_OBJECT(
      'input_schema' VALUE '{
        "type":"object",
        "properties":{
          "tool_name":{"type":"string"},
          "params":{"type":"object"}
        },
        "required":["tool_name"]
      }',
      'plsql_block'  VALUE
        'BEGIN :result := agent_dispatch(:tool_name, :params); END;'
    )
  );
END;
/
```

---

## Pattern 5 — Agent Audit Table + OTel Spans

```sql
CREATE TABLE agent_tool_audit (
  audit_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tool_name     VARCHAR2(100),
  params_hash   NUMBER,
  result_status VARCHAR2(20),
  duration_ms   NUMBER,
  trace_id      VARCHAR2(64),   -- W3C Trace-ID from calling agent
  span_id       VARCHAR2(16),
  called_at     TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- Query agent tool usage analytics
SELECT
  tool_name,
  result_status,
  COUNT(*)                        AS calls,
  ROUND(AVG(duration_ms), 1)     AS avg_ms,
  ROUND(MAX(duration_ms), 1)     AS max_ms,
  ROUND(SUM(CASE WHEN result_status='error' THEN 1 ELSE 0 END)
        / COUNT(*) * 100, 1)     AS error_rate_pct
FROM  agent_tool_audit
WHERE called_at >= SYSDATE - 7
GROUP BY tool_name, result_status
ORDER BY calls DESC;
```

---

## References

- [DBMS_CLOUD_AI_AGENT Reference](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/dbms-cloud-ai-agent.html)
- [Oracle JSON PL/SQL Functions](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/)
- [Oracle 23ai Free Docker Image](https://container-registry.oracle.com/ords/ocr/ba/database/free)
