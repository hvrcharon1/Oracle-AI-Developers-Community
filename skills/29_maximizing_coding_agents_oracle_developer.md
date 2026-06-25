# Skill 29: Maximizing Coding Agents as an Oracle AI Database Developer

**Category:** AI Agents | Developer Workflow | **Level:** Intermediate

> **Inspired by:** ["Get More Out of Your Coding Agents (as an Oracle Developer)"](https://andersswanson.dev/2026/06/15/get-more-out-of-your-coding-agents-as-an-oracle-developer/)  
> **Author:** [Anders Swanson](https://andersswanson.dev) ([@anders__swanson](https://twitter.com/anders__swanson)) — published June 15, 2026

---

## Overview

Most sub-optimal coding-agent output has one root cause: the agent is missing the proper shape of your system. Oracle AI Database work spans live schemas, distributed applications, views, grants, Oracle-specific SQL dialect features, generated DDL, documentation — and the few sentences in your head about what the application actually does.

This skill teaches you how to give coding agents the structured, factual context they need to produce Oracle-correct output — every session, every model, every AI provider.

### Core Principle

The goal is not to make the agent smarter in the abstract. The goal is to make each next token less dependent on guesswork. When an agent can inspect the schema, read the right docs, see your intent embedded in comments and annotations, and work from a corrected plan — it stops behaving like autocomplete with ambition and becomes a useful junior developer with a good terminal, a narrow permission set, and a checklist you actually trust.

---

## Part 1 — Use and Create Agent Skills

### What Are Skills?

Skills are token-efficient modules of instructions, scripts, and resources that describe how to execute specific tasks. They are generally more token-efficient than repeated MCP tool calls because they encode the pattern once rather than re-establishing it every turn.

**Oracle's official skills repository:** https://github.com/oracle/skills

Downloading and installing these skills is a strong starting point. From there, create your own for business-specific use cases.

### When to Create Your Own Skill

- Your internal schema naming and partitioning conventions
- Team-specific middleware or API integration steps  
- Application-specific agent loops (how to run and validate your test suite)
- Oracle release features you rely on that generic models confuse with PostgreSQL or MySQL

### Skill File Template (NL / Markdown Format)

```markdown
# Skill: [Task Name]

## Context
[Which system, schema, and Oracle version this skill targets]

## Goal
[What the agent should accomplish in one sentence]

## Steps
1. Inspect the schema via SQLcl MCP (describe tables, read COMMENT ON and ANNOTATIONS)
2. Load the relevant Oracle documentation section into context
3. Draft a /plan — do not execute until plan is reviewed
4. Correct any Oracle-specific mistakes (feature name, SQL dialect, GRANTs)
5. Execute only after the plan is boringly specific
6. Run the smallest real verification (SQL query, unit test, or container test)

## Oracle SQL Constraints
- Use Oracle SQL dialect only (never PostgreSQL, MySQL, or generic ANSI extensions)
- Verify all required GRANTs before generating DDL
- Never use PGQL unless explicitly requested
- Reference USER_TAB_COMMENTS, USER_COL_COMMENTS, and USER_ANNOTATIONS_USAGE for schema intent
- Annotate VECTOR columns with: Distance, IndexType, and AgentUse

## Verification
[Describe the minimum real verification step for this task]
```

---

## Part 2 — Connect the Agent to Your Oracle Database via SQLcl MCP

### Why SQLcl MCP?

The [SQLcl MCP Server](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/26.1/sqcug/sqlcl-mcp-server.html) standardizes how AI applications connect to Oracle AI Database instances through named or saved SQLcl connections. It gives the agent real introspection capability — not hallucinated schema knowledge — and is compatible with any MCP-enabled AI client regardless of provider.

**Reference:** [Run SQLcl as an MCP Server with Oracle Database Free](https://andersswanson.dev/2025/07/11/run-sqlcl-as-a-mcp-server-with-oracle-database-free/)

### Recommended Setup Pattern

**Step 1 — Create a low-privilege agent schema:**

```sql
-- Create a dedicated read-restricted user for agent access
CREATE USER agent_readonly IDENTIFIED BY "SecurePass123!";

-- Minimum necessary privileges only
GRANT CREATE SESSION TO agent_readonly;

-- Grant SELECT on the specific tables you want the agent to see
GRANT SELECT ON your_schema.support_tickets  TO agent_readonly;
GRANT SELECT ON your_schema.ticket_chunks     TO agent_readonly;

-- Allow the agent to read schema intent from the data dictionary
GRANT SELECT ON SYS.USER_TAB_COMMENTS        TO agent_readonly;
GRANT SELECT ON SYS.USER_COL_COMMENTS        TO agent_readonly;
GRANT SELECT ON SYS.USER_ANNOTATIONS_USAGE   TO agent_readonly;
```

**Step 2 — Save a named SQLcl connection for the agent schema:**

```bash
# In SQLcl, connect as the agent user and save the connection
conn agent_readonly/SecurePass123!@//localhost:1521/FREEPDB1
save connection agent-dev
```

**Step 3 — Expose the saved connection through SQLcl MCP** in your AI client configuration.

### Security Caution

Before connecting an agent to any shared or important database, review [Oracle's database security controls and best practices](https://www.oracle.com/security/database-security/features/deep-data-security/). Agent access to real production databases should always be tightly controlled. Always apply the minimum-privilege principle — never connect an agent using DBA or schema-owner credentials.

---

## Part 3 — Embed Intent Directly in the Database

Agents produce better output when the database carries its own explanation. Oracle AI Database provides two complementary levels for this.

### Level 1: `COMMENT ON` — Prose Intent

Comments are stored in the data dictionary and readable from `USER_TAB_COMMENTS` and `USER_COL_COMMENTS`. Use comments for prose descriptions that convey the business purpose, operational context, and caveats of a database object.

```sql
-- Describe the table's business purpose and primary operational filters
COMMENT ON TABLE support_tickets IS
  'Customer support cases. Use status and sla_status for operational filters.';

-- Explain non-obvious columns
COMMENT ON COLUMN support_tickets.payload IS
  'JSON diagnostics captured from the customer environment. Do not use for identity data.';

COMMENT ON COLUMN support_tickets.sla_status IS
  'Computed SLA compliance: WITHIN, BREACHED, or EXEMPT. Populated by nightly batch job.';

COMMENT ON COLUMN support_tickets.priority IS
  'Values: 1=Critical, 2=High, 3=Medium, 4=Low. Critical triggers PagerDuty alert.';
```

**Agent reads comments with:**

```sql
-- Read table-level intent
SELECT table_name, comments
FROM   user_tab_comments
WHERE  table_name = 'SUPPORT_TICKETS';

-- Read all column-level intent for a table
SELECT column_name, comments
FROM   user_col_comments
WHERE  table_name = 'SUPPORT_TICKETS'
ORDER  BY column_name;
```

### Level 2: `ANNOTATIONS` — Machine-Readable Hints

The [`annotations` clause](https://docs.oracle.com/en/database/oracle/oracle-database/26/sqlrf/annotations_clause.html) provides centrally stored, shared application metadata. Use annotations for compact, machine-readable hints that drive agent behavior — especially for vector columns, AI indexes, allowed values, and semantic context.

```sql
-- Add annotations at CREATE TABLE time
CREATE TABLE ticket_chunks (
  chunk_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  ticket_id   NUMBER         NOT NULL,
  chunk_type  VARCHAR2(30)   NOT NULL,
  chunk_text  CLOB           NOT NULL,
  embedding   VECTOR(384, FLOAT32)
    ANNOTATIONS (
      Distance  'COSINE',
      IndexType 'IVF',
      AgentUse  'rank support tickets and runbook chunks by semantic similarity'
    )
);
```

```sql
-- Add annotations to existing columns with ALTER TABLE
ALTER TABLE support_tickets
  MODIFY status ANNOTATIONS (
    AllowedValues 'OPEN,IN_PROGRESS,RESOLVED,CLOSED',
    AgentFilter   'always filter on this column for operational queries'
  );

ALTER TABLE support_tickets
  MODIFY priority ANNOTATIONS (
    AllowedValues '1,2,3,4',
    AgentNote     '1=Critical triggers PagerDuty; do not use in bulk updates without approval'
  );
```

**Agent reads annotations with:**

```sql
SELECT object_name, column_name, annotation_name, annotation_value
FROM   user_annotations_usage
WHERE  object_name = 'TICKET_CHUNKS'
ORDER  BY column_name, annotation_name;
```

### When to Use Which

| Situation | Recommended Approach |
|---|---|
| Business explanation, usage guidance, caveats | `COMMENT ON` (prose) |
| Technical hints for AI tools (distance metric, index type) | `ANNOTATIONS` |
| Allowed enumeration values | `ANNOTATIONS` |
| Column filter recommendations for agents | `ANNOTATIONS` |
| Historical notes, migration context | `COMMENT ON` |
| Multi-word, narrative explanations | `COMMENT ON` |

---

## Part 4 — Enrich Agent Context with Oracle Documentation

### The Problem with Vague Prompts

Without targeted documentation context, an agent defaults to generic SQL that may silently borrow syntax from PostgreSQL or MySQL. The shift from generic-and-wrong to Oracle-precise is achieved by loading the right resources before asking for code.

**Vague prompt (avoid this):**

```
Add a property graph to my app.
```

**Precise, doc-backed prompt (use this instead):**

```
Use Oracle AI Database SQL property graph syntax from the Oracle AI Database 26 Developer
Guide Section 4 (attached). Follow the CREATE PROPERTY GRAPH mapping shown in the sample.
Write a GRAPH_TABLE query that preserves source and destination direction.
Do NOT use PGQL unless I explicitly request it.
```

### Key Oracle Documentation to Load by Feature

| Feature | Documentation Resource |
|---|---|
| Property Graphs | [Oracle Property Graph Developer Guide](https://docs.oracle.com/en/database/oracle/property-graph/26.2/spgdg/graph-developers-guide-property-graph.pdf) |
| AI Vector Search | [Oracle AI Vector Search User's Guide](https://docs.oracle.com/en/database/oracle/oracle-database/26/vecse/) |
| Annotations Clause | [Oracle SQL Language Reference: annotations_clause](https://docs.oracle.com/en/database/oracle/oracle-database/26/sqlrf/annotations_clause.html) |
| COMMENT ON | [Oracle SQL Language Reference: COMMENT](https://docs.oracle.com/en/database/oracle/oracle-database/26/sqlrf/COMMENT.html) |
| SQLcl MCP Server | [SQLcl User Guide: MCP Server](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/26.1/sqcug/sqlcl-mcp-server.html) |
| Select AI | [Oracle AI Database: Using Select AI](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/sql-generation-ai-autonomous.html) |
| DBMS_VECTOR_CHAIN | [PL/SQL Packages: DBMS_VECTOR_CHAIN](https://docs.oracle.com/en/database/oracle/oracle-database/26/arpls/DBMS_VECTOR_CHAIN.html) |
| Oracle AI Database 26 Home | [Oracle AI Database 26 Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/26/index.html) |

### Practical Context Loading Pattern

1. Identify the exact Oracle feature you're implementing
2. Open the official Oracle documentation page for that feature
3. Paste the relevant section URL or excerpt directly into your agent prompt
4. Explicitly forbid the agent from using syntax that doesn't appear in the provided docs

---

## Part 5 — Use `/plan` Before Any Code or Migration

### Why Plan First?

Planning is the cheapest place to surface and correct mistakes. A corrected plan costs tokens. A bad migration costs time, rollback effort, and trust. With Oracle AI Database work, the plan stage is where you catch Oracle-specific errors before they become real problems.

### Common Errors to Catch at Plan Stage

| Error Type | Example to Watch For |
|---|---|
| Wrong feature name or release assumption | Agent references `VECTOR_DISTANCE()` syntax from a pre-26 doc |
| SQL syntax borrowed from another database | `ILIKE`, `SERIAL`, `::` cast operator (PostgreSQL) appearing in Oracle context |
| Missing GRANT or privilege | DDL succeeds but runtime SELECT fails with ORA-01031 |
| Invalid DML/DDL | Agent generates `CREATE OR REPLACE PROCEDURE` where `ALTER PROCEDURE` is needed |
| Guessed table relationships | Agent assumes a FK constraint that does not exist |
| Generated tests that don't start Oracle Database Free | Container not pulled, init script not confirmed |
| Links to generic or wrong-dialect docs | Agent references MySQL EXPLAIN instead of Oracle `EXPLAIN PLAN` |

### Sample Plan Prompt

```
/plan

Goal: Add semantic search to support_tickets using Oracle AI Vector Search.

Oracle version: Oracle AI Database 26 (Free container image)
Schema: SUPPORT (agent user: agent_readonly — read-write on SUPPORT schema only)
Vector model: all-MiniLM-L6-v2 producing 384-dimension FLOAT32 embeddings
Index type: IVF, distance metric: COSINE
Chunking strategy: per-ticket body, maximum 500 tokens per chunk

Documentation to use:
  - [paste Oracle AI Vector Search doc URL or excerpt here]

Constraints:
  - Use Oracle SQL syntax only (not PostgreSQL, MySQL, or generic ANSI)
  - Include all required GRANT statements for agent_readonly
  - Do not use PGQL
  - Annotate the embedding VECTOR column with: Distance, IndexType, and AgentUse
  - Generated tests must actually start Oracle Database Free container

Wait for my review and approval before making any edits or running any SQL.
```

### Plan Review Checklist

Before approving any plan, verify:

- [ ] Every SQL syntax element is valid in Oracle AI Database 26
- [ ] All GRANTs required by the agent user are explicitly listed
- [ ] Test cases actually start the Oracle Database Free container (not mocked)
- [ ] No PostgreSQL, MySQL, or generic ANSI syntax has been introduced
- [ ] All VECTOR columns include Distance, IndexType, and AgentUse annotations
- [ ] Table relationships are confirmed via `USER_CONSTRAINTS`, not assumed
- [ ] Documentation links point to Oracle docs, not other databases

---

## Part 6 — The Complete 6-Step Oracle AI Database Agent Loop

This is the full practitioner workflow for Oracle AI Database coding-agent work:

```
┌──────────────────────────────────────────────────────────────────────┐
│  STEP 1: Establish a Low-Privilege SQLcl MCP Connection              │
│  Save a named SQLcl connection for a read/restricted schema.         │
│  Expose it through SQLcl MCP. Never use DBA or owner credentials.    │
├──────────────────────────────────────────────────────────────────────┤
│  STEP 2: Add Comments and Annotations for Stable Schema Intent       │
│  Prose intent lives in COMMENT ON. Machine-readable hints live in    │
│  ANNOTATIONS. The agent should read both before generating code.     │
├──────────────────────────────────────────────────────────────────────┤
│  STEP 3: Load Exact Oracle Documentation Into Context                │
│  Before asking for feature-specific code, paste the relevant Oracle  │
│  documentation section, URL, or PDF excerpt. Forbid the agent from   │
│  using syntax not present in the provided docs.                      │
├──────────────────────────────────────────────────────────────────────┤
│  STEP 4: Plan First — Review and Correct Before Executing            │
│  Use /plan. Review for: wrong feature names, borrowed SQL syntax,    │
│  missing GRANTs, invalid DML/DDL, guessed relationships, broken      │
│  test assumptions, and links to non-Oracle documentation.            │
├──────────────────────────────────────────────────────────────────────┤
│  STEP 5: Let the Agent Edit Only After the Plan is Boringly Specific │
│  Do not approve a plan that contains guesswork or unresolved         │
│  ambiguity. Specificity is the gate. Vague plans produce vague code. │
├──────────────────────────────────────────────────────────────────────┤
│  STEP 6: Run the Smallest Real Verification                          │
│  A SQL query, unit test, integration test, or container-backed       │
│  sample. The verification must target your real schema or a real     │
│  Oracle container — not a mocked or stubbed environment.             │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Prompt Templates

### Template A — Schema Introspection Before Any Code

```
Before generating any code or DDL, please:
1. Use SQLcl MCP to DESCRIBE tables: [list table names]
2. Read all COMMENT ON values from USER_TAB_COMMENTS and USER_COL_COMMENTS for those tables
3. Read all ANNOTATIONS from USER_ANNOTATIONS_USAGE for those tables
4. Summarize what you found and confirm all table relationships using USER_CONSTRAINTS
5. Do not generate any code or SQL until I confirm your schema summary is accurate
```

### Template B — Feature-Specific Oracle Task

```
Task: [Your specific task]

Oracle version: Oracle AI Database 26
Schema: [schema name], exposed via SQLcl MCP connection named [connection name]
Reference documentation: [paste URL or doc excerpt]

Constraints:
- Use Oracle SQL syntax only (not PostgreSQL, MySQL, or generic ANSI)
- Include all required GRANT statements
- Do not reference PGQL unless I specifically request it
- Annotate all VECTOR columns with: Distance, IndexType, and AgentUse annotations
- Confirm table relationships via USER_CONSTRAINTS before writing any JOINs

Start with /plan. Wait for my explicit approval before making any edits.
```

### Template C — Plan Approval Gate

```
Before I approve this plan, confirm each of the following:
1. Every SQL syntax element is valid in Oracle AI Database 26 (not PostgreSQL/MySQL)
2. All GRANTs required by [agent username] are explicitly listed in the plan
3. Test cases actually start the Oracle Database Free container (not a mock or stub)
4. No foreign-key or table relationships are assumed — all are verified via USER_CONSTRAINTS
5. All VECTOR columns include Distance, IndexType, and AgentUse annotations
6. All documentation links point to oracle.com docs for the correct Oracle version
```

---

## Quick Reference: Key Data Dictionary Views

```sql
-- Read all table-level comments in current schema
SELECT table_name, comments
FROM   user_tab_comments
WHERE  comments IS NOT NULL
ORDER  BY table_name;

-- Read all column-level comments for a specific table
SELECT column_name, comments
FROM   user_col_comments
WHERE  table_name = 'SUPPORT_TICKETS'
  AND  comments IS NOT NULL
ORDER  BY column_name;

-- Read all annotations in current schema
SELECT object_name, column_name, annotation_name, annotation_value
FROM   user_annotations_usage
ORDER  BY object_name, column_name, annotation_name;

-- Verify actual foreign key relationships (never assume)
SELECT a.table_name, a.column_name, a.constraint_name,
       b.table_name AS ref_table, b.column_name AS ref_column
FROM   user_cons_columns a
JOIN   user_constraints  c ON a.constraint_name = c.constraint_name
JOIN   user_cons_columns b ON c.r_constraint_name = b.constraint_name
WHERE  c.constraint_type = 'R'
ORDER  BY a.table_name;

-- Check what the current session can access
SELECT * FROM session_privs ORDER BY privilege;

-- Check which tables are accessible to the agent user
SELECT owner, table_name, privilege
FROM   all_tab_privs
WHERE  grantee = USER
ORDER  BY owner, table_name;
```

---

## Common Oracle-Specific Mistakes: SQL Comparison Guide

```sql
-- ─────────────────────────────────────────────────────────
-- CASE-INSENSITIVE SEARCH
-- ─────────────────────────────────────────────────────────
-- ❌ PostgreSQL ILIKE — invalid in Oracle
SELECT * FROM support_tickets WHERE status ILIKE '%open%';

-- ✓ Oracle equivalent
SELECT * FROM support_tickets WHERE LOWER(status) LIKE '%open%';

-- ─────────────────────────────────────────────────────────
-- AUTO-INCREMENT PRIMARY KEY
-- ─────────────────────────────────────────────────────────
-- ❌ PostgreSQL SERIAL — not valid in Oracle
CREATE TABLE log_entries (id SERIAL PRIMARY KEY, message VARCHAR(500));

-- ✓ Oracle identity column
CREATE TABLE log_entries (
  id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  message VARCHAR2(500)
);

-- ─────────────────────────────────────────────────────────
-- STRING CONCATENATION
-- ─────────────────────────────────────────────────────────
-- ❌ MySQL/PostgreSQL double-pipe may need escaping in some configs
-- Oracle uses || natively — always use this form explicitly
SELECT first_name || ' ' || last_name AS full_name FROM employees;

-- ─────────────────────────────────────────────────────────
-- ASSUMED FOREIGN KEYS — verify before writing JOINs
-- ─────────────────────────────────────────────────────────
-- ❌ Agent assumes FK exists without verifying
SELECT t.ticket_id, u.username
FROM   support_tickets t
JOIN   users u ON t.user_id = u.id;  -- Is this FK defined? Check first.

-- ✓ Verify FK before writing the JOIN
SELECT a.column_name, b.table_name AS ref_table, b.column_name AS ref_column
FROM   user_cons_columns a
JOIN   user_constraints  c ON a.constraint_name = c.constraint_name
JOIN   user_cons_columns b ON c.r_constraint_name = b.constraint_name
WHERE  c.constraint_type = 'R'
  AND  a.table_name = 'SUPPORT_TICKETS';

-- ─────────────────────────────────────────────────────────
-- TYPE CASTING
-- ─────────────────────────────────────────────────────────
-- ❌ PostgreSQL cast operator — not valid in Oracle
SELECT '42'::NUMBER FROM dual;

-- ✓ Oracle CAST or TO_NUMBER
SELECT CAST('42' AS NUMBER) FROM dual;
SELECT TO_NUMBER('42')      FROM dual;
```

---

## Related Skills

- [Skill 03: MCP Server Setup — Autonomous AI Database](03_mcp_server_setup_autonomous_ai_database.md)
- [Skill 04: Building AI Agents with DBMS_CLOUD_AI_AGENT](04_building_ai_agents_dbms_cloud_ai_agent.md)
- [Skill 05: Claude Code + Oracle MCP Integration](05_claude_code_oracle_mcp_integration.md)
- [Skill 10: Agentic Workflows with Oracle AI Database](10_agentic_workflows_oracle_ai_database.md)
- [Skill 13: SQL/PGQ Property Graph Queries](13_sql_pgq_property_graph_queries.md)
- [Skill 23: DBMS_VECTOR_CHAIN: Document Chunking & Text Processing](23_dbms_vector_chain_text_processing.md)
- [Skill 28: Identity-Aware Row-Level Security for AI / MCP Agents](28_identity_aware_row_level_security_ai_agents/SKILL.md)

---

**#OracleAI #CodingAgents #SQLclMCP #AgentSkills #SchemaAnnotations #OracleDeveloper #AIDatabase #AgenticAI #OracleAIDatabase26**
