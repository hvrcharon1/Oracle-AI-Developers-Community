# Agent Identity Crisis in AI-Driven Oracle Environments

> **Understanding and Resolving AI Agent Identity Ambiguity**  
> Across Oracle AI Database 26ai, Legacy Oracle Versions, APEX 26.1, and APEXlang

**Technical Reference | 2026**  
**Tags:** `oracle-26ai` `oracle-apex` `apexlang` `ai-agents` `security` `deep-data-security` `identity` `mcp`

---

## Abstract

As AI agents proliferate across enterprise systems, a silent architectural problem has emerged: agents do not always know who they are, what context they carry, or how to assert that identity across system boundaries. This "Agent Identity Crisis" is not philosophical — it is a concrete engineering challenge manifesting as failed authentication handoffs, inconsistent session context, data ownership ambiguity, and audit trail gaps in multi-agent pipelines.

This article examines the roots of agent identity problems in Oracle-based environments, contrasts how **Oracle AI Database 26ai**'s native AI capabilities — including the newly released **Oracle Deep Data Security** (March 2026) — address these challenges compared to older Oracle versions, and explores how **Oracle APEX 26.1** and the emerging **APEXlang** declarative language can be leveraged, or must be adapted, to architect identity-aware AI agent systems.

> **What's New in 2026:** Oracle AI Database 26ai (released October 2025 as a seamless upgrade from 23ai) and Oracle APEX 26.1 (released May 2026) together represent the most complete native platform for solving the agent identity problem. Key additions include Oracle Deep Data Security, the Private Agent Factory, Oracle Unified Memory Core, and APEXlang — all directly relevant to the architecture patterns described in this article.

---

## Table of Contents

1. [What Is the Agent Identity Crisis?](#1-what-is-the-agent-identity-crisis)
2. [Oracle Legacy Versions — The Identity Gap](#2-oracle-database-legacy-versions--the-identity-gap)
3. [Oracle AI Database 26ai — Native Agent Identity](#3-oracle-ai-database-26ai--native-agent-identity)
4. [Oracle Deep Data Security — The 2026 Answer](#4-oracle-deep-data-security--the-2026-answer)
5. [Tackling Identity Crisis — Architecture Patterns](#5-tackling-identity-crisis--architecture-patterns)
6. [Oracle APEX 26.1 and Agent Identity](#6-oracle-apex-261-and-agent-identity)
7. [APEXlang and Agent Identity](#7-apexlang-and-agent-identity)
8. [End-to-End Reference Architecture](#8-end-to-end-reference-architecture)
9. [Security Hardening for Agent Identity](#9-security-hardening-for-agent-identity)
10. [Migration Path: Legacy Oracle to 26ai](#10-migration-path-legacy-oracle-to-26ai)
11. [Conclusion](#11-conclusion)
12. [References & Further Reading](#12-references--further-reading)

---

## 1. What Is the Agent Identity Crisis?

The "Agent Identity Crisis" refers to a class of problems that arise when AI agents — autonomous software entities that plan, act, and interact with external systems — fail to carry, assert, or maintain a consistent, verifiable identity across their operational lifecycle.

### 1.1 Core Dimensions of the Problem

Agent identity operates across four critical dimensions:

| Dimension | Description |
|---|---|
| **Authentication Identity** | Who is the agent to the database or service it is calling? Is it a human user's proxy, a service account, or a first-class agent principal? |
| **Contextual Identity** | What task, session, or workflow does this agent represent? A single agent invoked ten times in parallel carries ten distinct contexts. |
| **Ownership Identity** | Who owns the data the agent creates, reads, or modifies? This determines row-level security, audit attribution, and GDPR-style accountability. |
| **Delegation Identity** | When Agent A invokes Agent B, does B know who A is, and does the original human principal's identity persist through the chain? |

> **Why This Matters in Oracle Environments**  
> Oracle's security model is deeply principal-centric. VPD policies, fine-grained auditing, Real Application Security (RAS), and Database Vault all rely on knowing exactly who is performing an action. When an AI agent acts as an opaque "service account," these controls collapse — the entire security stack becomes blind to the true initiator of a database operation.

### 1.2 How the Crisis Manifests in Practice

In real-world agent deployments, the identity crisis surfaces in predictable failure patterns:

| Failure Pattern | Symptom | Root Cause |
|---|---|---|
| **Session Collapse** | Agent loses user context mid-workflow | Stateless invocation without session token propagation |
| **Audit Black Hole** | DB audit shows only service account, not user | Agent uses shared credentials, not proxy auth |
| **RLS Bypass** | Agent reads data it should not see | VPD policy not applied to agent session |
| **Cascade Failure** | Sub-agent errors cannot be traced to root cause | No correlation ID passed through agent chain |
| **Ghost Writes** | Records created with no ownership | Agent inserts with NULL user context columns |
| **Prompt Injection Escalation** | Agent claims elevated identity after reading malicious content | No database-level capability boundary enforcement |

### 1.3 The MCP Dimension (2026 Addition)

The rise of the **Model Context Protocol (MCP)** as a standard for connecting AI agents to enterprise data sources adds a new surface area for the identity crisis. When Claude, GPT-4, or any other LLM agent connects to an Oracle database through an MCP server, every SQL query the agent executes carries the MCP server's credentials — not the end user's identity. Without explicit identity propagation, the MCP layer becomes the largest identity gap in the modern AI stack.

Oracle AI Database 26ai's Deep Data Security is specifically architected to close this gap by enforcing end-user authorization at the database engine level, regardless of whether access comes from a direct connection, an application, an AI agent, or an MCP-based tool.

---

## 2. Oracle Database Legacy Versions — The Identity Gap

Oracle databases prior to version 23ai were not designed with AI agents as first-class actors. The authentication and authorization model assumes a human or application-tier service at one end and the database at the other. This creates a structural gap when agents are introduced.

### 2.1 The Shared Service Account Anti-Pattern

The most common approach in legacy Oracle environments is assigning agents a shared service account — a single database user under which all agent operations run. This is expedient but catastrophically wrong from an identity perspective.

```sql
-- Legacy anti-pattern: all agent operations run as AGENT_SVC_USER
CREATE USER agent_svc_user IDENTIFIED BY ****;
GRANT CONNECT, RESOURCE TO agent_svc_user;

-- Every agent operation is now indistinguishable in audit logs
-- VPD sees agent_svc_user, not the underlying human principal
-- Row-level security cannot differentiate Agent A from Agent B
```

### 2.2 Proxy Authentication — A Partial Bridge

Oracle has supported proxy authentication since Oracle 9i, allowing one user to connect on behalf of another. This can be adapted for agent scenarios in legacy versions to partially preserve identity:

```sql
-- Allow agent_svc_user to proxy as actual users
ALTER USER john_doe GRANT CONNECT THROUGH agent_svc_user;

-- Agent connects using proxy syntax
-- Connection string: agent_svc_user[john_doe]/<password>@<db>

-- In the session, USER returns 'JOHN_DOE'
-- VPD policies and auditing see the proxied identity
SELECT SYS_CONTEXT('USERENV','PROXY_USER') FROM DUAL;
-- Returns: AGENT_SVC_USER
SELECT USER FROM DUAL;
-- Returns: JOHN_DOE
```

This solves authentication identity and audit identity, but does not address contextual or delegation identity — the database has no native mechanism to know which workflow, task, or parent agent invoked the current operation.

### 2.3 Application Context — Injecting Agent Context

Oracle's Application Context mechanism (`DBMS_SESSION.SET_CONTEXT`) is the primary tool in legacy versions for carrying agent-specific metadata through a session:

```sql
-- Create a trusted context namespace
CREATE OR REPLACE CONTEXT agent_ctx USING agent_ctx_pkg ACCESSED GLOBALLY;

CREATE OR REPLACE PACKAGE agent_ctx_pkg AS
  PROCEDURE set_agent_context(
    p_agent_id     VARCHAR2,
    p_workflow_id  VARCHAR2,
    p_task_id      VARCHAR2,
    p_parent_agent VARCHAR2 DEFAULT NULL
  );
END agent_ctx_pkg;
/

CREATE OR REPLACE PACKAGE BODY agent_ctx_pkg AS
  PROCEDURE set_agent_context(
    p_agent_id     VARCHAR2,
    p_workflow_id  VARCHAR2,
    p_task_id      VARCHAR2,
    p_parent_agent VARCHAR2 DEFAULT NULL
  ) AS
  BEGIN
    DBMS_SESSION.SET_CONTEXT('AGENT_CTX', 'AGENT_ID',     p_agent_id);
    DBMS_SESSION.SET_CONTEXT('AGENT_CTX', 'WORKFLOW_ID',  p_workflow_id);
    DBMS_SESSION.SET_CONTEXT('AGENT_CTX', 'TASK_ID',      p_task_id);
    DBMS_SESSION.SET_CONTEXT('AGENT_CTX', 'PARENT_AGENT', p_parent_agent);
    DBMS_SESSION.SET_CONTEXT('AGENT_CTX', 'SET_AT',       TO_CHAR(SYSTIMESTAMP));
  END;
END agent_ctx_pkg;
/

-- VPD policy leveraging agent context
CREATE OR REPLACE FUNCTION agent_rls_policy(
  schema_name IN VARCHAR2, table_name IN VARCHAR2
) RETURN VARCHAR2 AS
BEGIN
  RETURN 'workflow_id = SYS_CONTEXT(''AGENT_CTX'', ''WORKFLOW_ID'')'
       || ' OR owner_agent_id = SYS_CONTEXT(''AGENT_CTX'', ''AGENT_ID'')';
END;
/
```

> **Legacy Oracle Identity Limitations Summary**  
> In Oracle versions prior to 23ai, agent identity must be manually constructed using proxy authentication + application context + custom audit tables. There is no native concept of an "agent principal." Every identity assertion requires explicit, disciplined coding — and any lapse creates a security blind spot.

---

## 3. Oracle AI Database 26ai — Native Agent Identity

Oracle AI Database 26ai (the successor to 23ai, released October 2025) introduces first-class AI primitives directly into the database engine. Critically for identity, it introduces the concept of **AI Agent Principals** alongside enhanced session context propagation and built-in vector-aware security models.

> **26ai is not a disruptive upgrade.** Existing Oracle Database 23ai customers apply the October 2025 Release Update to transition — no database upgrade or application re-certification required. This means the identity patterns described in this section are accessible today for 23ai customers.

### 3.1 Select AI Agent — In-Database Agent Framework

Oracle 26ai's **Select AI Agent** is an in-database framework for building, deploying, and managing autonomous agentic AI workflows. Unlike external agent frameworks, Select AI Agent runs inside the database engine, meaning agent execution inherits the full Oracle security model from the moment of instantiation — no separate identity bridge required.

This architectural decision is significant: agents are not calling the database from outside; they *are* database objects, subject to the same principal-centric security that governs all other database operations.

### 3.2 Agent Principals in Oracle 26ai

Oracle 26ai introduces a formal `AGENT PRINCIPAL` object type that exists at the database level — distinct from user accounts, service accounts, or application roles. An agent principal carries a cryptographically verifiable identity and a capability scope.

```sql
-- Oracle 26ai: Creating a formal agent principal
CREATE AGENT PRINCIPAL research_agent
  DESCRIPTION 'Document research and summarization agent'
  CAPABILITIES (SELECT_DATA, CALL_AI_PROFILE, VECTOR_SEARCH)
  DELEGATION_DEPTH 3  -- can spawn up to 3 levels of sub-agents
  AUDIT_POLICY COMPREHENSIVE;

-- Granting the agent principal access to specific schemas
GRANT AGENT PRINCIPAL research_agent TO SCHEMA knowledge_base;
GRANT AI_PROFILE summarizer_profile TO AGENT PRINCIPAL research_agent;
```

### 3.3 Identity Chain Propagation

One of the most significant advances in 26ai is automatic identity chain propagation across agent invocations. When an orchestrator agent spawns a sub-agent, the full identity chain is cryptographically maintained and inspectable at every level:

```sql
-- Oracle 26ai: Identity chain is automatically propagated
-- Sub-agent can inspect its full delegation chain

SELECT
  SYS_CONTEXT('AGENT_ENV', 'AGENT_PRINCIPAL')   AS current_agent,
  SYS_CONTEXT('AGENT_ENV', 'PARENT_PRINCIPAL')  AS parent_agent,
  SYS_CONTEXT('AGENT_ENV', 'ROOT_PRINCIPAL')    AS root_agent,
  SYS_CONTEXT('AGENT_ENV', 'HUMAN_PRINCIPAL')   AS originating_user,
  SYS_CONTEXT('AGENT_ENV', 'DELEGATION_DEPTH')  AS depth,
  SYS_CONTEXT('AGENT_ENV', 'WORKFLOW_ID')       AS workflow_id,
  SYS_CONTEXT('AGENT_ENV', 'TASK_ID')           AS task_id
FROM DUAL;
```

### 3.4 Oracle Unified Memory Core — Stateful Agent Identity

Announced March 24, 2026, the **Oracle Unified Memory Core** provides persistent, stateful memory for AI agents within the database engine itself. This directly addresses the contextual identity dimension: an agent no longer loses its context between invocations. The workflow ID, task chain, and human principal association persist in the database's own memory substrate — with full ACID transactional guarantees.

This eliminates the largest source of session collapse failures in legacy agent deployments.

### 3.5 AI Profiles and Capability-Scoped Identity

Oracle 26ai's AI Profiles bind an agent's identity to a specific set of model capabilities and data access patterns. This means an agent cannot exceed its declared capability scope even if it acquires elevated credentials through a bug or prompt injection:

```sql
-- Define an AI profile scoped to specific models and data
BEGIN
  DBMS_AI.CREATE_AI_PROFILE(
    profile_name   => 'RESEARCH_AGENT_PROFILE',
    description    => 'Profile for research agent with read-only data access',
    attributes     => JSON_OBJECT(
      'provider'        VALUE 'oracle',
      'model'           VALUE 'meta.llama-3-70b-instruct',
      'max_tokens'      VALUE 4096,
      'data_scope'      VALUE 'READ_ONLY',
      'allowed_schemas' VALUE JSON_ARRAY('KNOWLEDGE_BASE', 'PUBLIC_DOCS')
    )
  );
END;
/

-- Bind the profile to the agent principal
GRANT AI_PROFILE RESEARCH_AGENT_PROFILE
  TO AGENT PRINCIPAL research_agent;
```

### 3.6 Native Vector Security and Identity

Oracle 26ai's native vector store (backed by AI Vector Search) enforces identity at the embedding retrieval level. VPD policies can be applied directly to vector searches, ensuring an agent only retrieves vectors it is authorized to access:

```sql
-- Vector search with automatic identity-scoped filtering
SELECT doc_id, doc_title, content,
       VECTOR_DISTANCE(embedding, :query_vector, COSINE) AS similarity
FROM   knowledge_documents
WHERE  VECTOR_DISTANCE(embedding, :query_vector, COSINE) < 0.3
  AND  tenant_id = SYS_CONTEXT('AGENT_ENV', 'TENANT_ID')
ORDER BY similarity
FETCH FIRST 10 ROWS ONLY;

-- The VPD policy enforces this invisibly based on agent principal
-- Agents in different workflows cannot cross-contaminate results
```

---

## 4. Oracle Deep Data Security — The 2026 Answer

On March 24, 2026, Oracle announced **Oracle Deep Data Security** — a next-generation, database-native authorization system specifically engineered for the agentic AI era. This is the most significant evolution in Oracle's security architecture as it pertains to agent identity.

### 4.1 What Deep Data Security Solves

Traditional Oracle security (VPD, RAS) was designed for application-layer enforcement — the app knew who the user was and applied filters accordingly. In the agentic model, the application layer is replaced by an AI agent that may be acting on behalf of any user in the system. Deep Data Security moves the trust boundary from the application into the database engine itself.

Key capabilities:

- **Transparent identity propagation** — End-user and agent identities, roles, and attributes are relayed to the database at runtime via OAuth 2.0 tokens
- **Declarative SQL policies** — Row, column, and cell-level access control defined in SQL, not PL/SQL procedures, making them auditable and portable
- **Least-privilege enforcement** — Even if an agent or application has broad credentials, data returned is filtered to only what the end user is authorized to see
- **Prompt injection defense** — Because authorization is enforced at the data layer before results are returned, a prompt-injected instruction to "retrieve all records" still returns only the authorized subset
- **MCP server support** — When an MCP server queries Oracle on behalf of an AI agent, Deep Data Security applies the same end-user policies, closing the MCP identity gap

### 4.2 Deep Data Security Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    END-USER / HUMAN PRINCIPAL                    │
│                  (authenticated via IAM / OCI)                   │
└──────────────────────────────┬──────────────────────────────────┘
                               │  OAuth 2.0 Token
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│              APPLICATION / MCP SERVER / AI AGENT                 │
│   (connects to DB using service credentials + end-user token)    │
└──────────────────────────────┬──────────────────────────────────┘
                               │  Token propagated on every SQL call
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                  ORACLE AI DATABASE 26ai ENGINE                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │            DEEP DATA SECURITY ENFORCEMENT               │   │
│  │  • Validates OAuth token                                │   │
│  │  • Establishes End-User Security Context                │   │
│  │  • Applies declarative row/column/cell policies         │   │
│  │  • Generates audit record with full identity chain      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ▼                                       │
│              DATA RETURNED = AUTHORIZED SUBSET ONLY             │
└─────────────────────────────────────────────────────────────────┘
```

### 4.3 Deep Data Security — Declarative Policy Example

Unlike legacy VPD (which requires PL/SQL function authoring), Deep Data Security policies are declarative SQL — closer to how modern authorization systems like row-level security in PostgreSQL work, but with Oracle's full ACID and multi-tenant capabilities:

```sql
-- Deep Data Security: Declarative policy for HR data
-- End users see only their own record; managers see their reports
-- AI agents acting on behalf of any user inherit the same rules

CREATE DATA SECURITY POLICY hr_employee_access
  ON hr.employees
  USING (
    employee_id = END_USER_CONTEXT('EMPLOYEE_ID')
    OR manager_id = END_USER_CONTEXT('EMPLOYEE_ID')
  )
  COLUMNS VISIBLE (
    -- Sensitive columns hidden from non-managers
    CASE WHEN END_USER_CONTEXT('ROLE') = 'MANAGER'
         THEN ALL_COLUMNS
         ELSE EXCLUDE (ssn, home_address, salary_details)
    END
  )
  AUDIT ALL_ACTIONS;
```

This single declarative policy enforces identity-aware access regardless of whether the query comes from a human user's SQL client, a Python application, an AI agent via Select AI, or an LLM through an MCP server.

### 4.4 IAM-Managed End Users — No Database Provisioning Required

A practical friction point in legacy agent identity patterns was the need to provision every user in the database. Deep Data Security integrates with OCI Identity Domains and external IAM providers (including Microsoft Entra ID). End users are managed in IAM, not the database. Their identity and group memberships arrive via OAuth tokens at query time — enabling enterprise-scale deployments where thousands of users interact with agents without individual database accounts.

---

## 5. Tackling Identity Crisis — Architecture Patterns

Whether on legacy Oracle or 26ai, the agent identity crisis can be systematically tackled using a layered architecture. The approach differs by version but the logical layers remain consistent.

### 5.1 The Identity Stack

| Layer | Legacy Oracle (< 23ai) | Oracle 26ai + Deep Data Security |
|---|---|---|
| **Authentication** | Proxy Auth + shared service account | Native Agent Principal + IAM OAuth tokens |
| **Context** | `DBMS_SESSION.SET_CONTEXT` (manual) | `AGENT_ENV` system context + End-User Security Context (automatic) |
| **Authorization** | Custom VPD functions per table | Declarative Deep Data Security policies + capability-scoped AI Profiles |
| **Audit** | Custom audit tables + FGA policies | Built-in agent audit trail with full identity chain, including MCP access |
| **Memory** | Stateless — context lost between calls | Oracle Unified Memory Core — persistent stateful context |

### 5.2 The Correlation ID Pattern

Regardless of Oracle version, every agent invocation must carry a **Correlation ID** — a unique token that threads through every database operation, log entry, and sub-agent call in a workflow. This is the single most impactful pattern for resolving identity chain gaps:

```sql
-- Universal correlation ID pattern (compatible with all Oracle versions)
CREATE OR REPLACE PACKAGE agent_identity AS

  -- Generate a new correlation ID for a workflow root
  FUNCTION new_workflow_id RETURN VARCHAR2;

  -- Create a scoped task ID under a workflow
  FUNCTION new_task_id(p_workflow_id VARCHAR2) RETURN VARCHAR2;

  -- Initialize agent identity for current session
  PROCEDURE init_agent(
    p_agent_id     VARCHAR2,
    p_workflow_id  VARCHAR2,
    p_task_id      VARCHAR2,
    p_human_user   VARCHAR2,
    p_parent_agent VARCHAR2 DEFAULT NULL
  );

  -- Retrieve current agent context value
  FUNCTION get_ctx(p_key VARCHAR2) RETURN VARCHAR2;

END agent_identity;
/

CREATE OR REPLACE PACKAGE BODY agent_identity AS

  FUNCTION new_workflow_id RETURN VARCHAR2 AS
  BEGIN
    RETURN 'WF-' || TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3')
           || '-' || DBMS_RANDOM.STRING('X', 8);
  END;

  FUNCTION new_task_id(p_workflow_id VARCHAR2) RETURN VARCHAR2 AS
  BEGIN
    RETURN p_workflow_id || '-T-' || DBMS_RANDOM.STRING('X', 6);
  END;

  PROCEDURE init_agent(
    p_agent_id     VARCHAR2,
    p_workflow_id  VARCHAR2,
    p_task_id      VARCHAR2,
    p_human_user   VARCHAR2,
    p_parent_agent VARCHAR2 DEFAULT NULL
  ) AS
  BEGIN
    DBMS_SESSION.SET_CONTEXT('AGENT_CTX','AGENT_ID',     p_agent_id);
    DBMS_SESSION.SET_CONTEXT('AGENT_CTX','WORKFLOW_ID',  p_workflow_id);
    DBMS_SESSION.SET_CONTEXT('AGENT_CTX','TASK_ID',      p_task_id);
    DBMS_SESSION.SET_CONTEXT('AGENT_CTX','HUMAN_USER',   p_human_user);
    DBMS_SESSION.SET_CONTEXT('AGENT_CTX','PARENT_AGENT', NVL(p_parent_agent,'NONE'));
    DBMS_SESSION.SET_CONTEXT('AGENT_CTX','INIT_TIME',    TO_CHAR(SYSTIMESTAMP));
  END;

  FUNCTION get_ctx(p_key VARCHAR2) RETURN VARCHAR2 AS
  BEGIN
    RETURN SYS_CONTEXT('AGENT_CTX', p_key);
  END;

END agent_identity;
/
```

---

## 6. Oracle APEX 26.1 and Agent Identity

Oracle APEX (Application Express) is frequently the UI and workflow orchestration layer sitting above Oracle Database in enterprise deployments. **APEX 26.1** (released May 14, 2026) takes a major step forward in native AI agent support, making APEX not merely an identity origin point but a full **governed AI runtime**.

> **APEX 26.1 requires:** Oracle Database 19c with patch 19.18 (January 2023) or newer, plus ORDS 26.1.1 or later. Deep Data Security and BOOLEAN session state require Oracle AI Database 26ai. There are no per-user or per-application licensing fees.

### 6.1 APEX as the Identity Origin

In a well-architected system, APEX is where the human principal is authenticated and where the identity chain must originate. APEX provides several mechanisms to carry this forward:

```sql
-- In APEX 26.1: Set agent context at session initialization
-- Typically placed in Application Process: On New Session

DECLARE
  l_workflow_id VARCHAR2(100);
  l_agent_id    VARCHAR2(100) := 'APEX_ORCHESTRATOR_V1';
BEGIN
  -- Generate a workflow ID for this APEX session's agent context
  l_workflow_id := agent_identity.new_workflow_id();

  -- Store in APEX session state for use in page processes
  APEX_UTIL.SET_SESSION_STATE('G_WORKFLOW_ID', l_workflow_id);

  -- Initialize agent identity with the authenticated APEX user
  agent_identity.init_agent(
    p_agent_id     => l_agent_id,
    p_workflow_id  => l_workflow_id,
    p_task_id      => agent_identity.new_task_id(l_workflow_id),
    p_human_user   => V('APP_USER')  -- APEX authenticated user
  );
END;
```

### 6.2 AI Agents with Tools in APEX 26.1

APEX 26.1 introduces **AI Agents with Tools** — a native agent framework that allows APEX applications to define tools (database queries, REST calls, PL/SQL procedures) that an AI agent can reason over and invoke. Each tool invocation is an identity boundary: the agent must carry the authenticated APEX user's identity into every tool call.

For sensitive tools — those that create, update, or delete data — APEX 26.1 introduces a **confirmation gate**: the AI presents its planned action, and the human user must explicitly approve before the tool executes. This is a direct mitigation for prompt injection attacks where the agent would otherwise take destructive actions without human awareness.

### 6.3 APEX REST APIs and Agent Callbacks

Modern APEX deployments expose REST APIs that agents can call back into. Each such callback is a potential identity gap — the agent must re-assert its identity on every inbound REST call:

```sql
-- APEX REST Handler: Validate agent identity on callback
-- Handler placed on /agent-callback/ REST endpoint

DECLARE
  l_agent_id    VARCHAR2(100) := :agent_id;     -- from REST body
  l_workflow_id VARCHAR2(100) := :workflow_id;
  l_task_id     VARCHAR2(100) := :task_id;
  l_signature   VARCHAR2(500) := :signature;    -- HMAC of payload
  l_valid        BOOLEAN;
BEGIN
  -- Verify the agent's HMAC signature
  l_valid := agent_security.verify_signature(
    p_agent_id  => l_agent_id,
    p_payload   => l_workflow_id || '|' || l_task_id,
    p_signature => l_signature
  );

  IF NOT l_valid THEN
    APEX_ERROR.ADD_ERROR(
      p_message          => 'Agent identity verification failed',
      p_display_location => APEX_ERROR.c_inline_in_notification
    );
    RETURN;
  END IF;

  -- Re-initialize session context for this callback
  agent_identity.init_agent(
    p_agent_id    => l_agent_id,
    p_workflow_id => l_workflow_id,
    p_task_id     => l_task_id,
    p_human_user  => agent_registry.get_owner(l_agent_id)
  );
END;
```

### 6.4 APEX Authorization Schemes for Agent-Triggered Actions

APEX Authorization Schemes should be extended to handle the case where a page process is triggered by an agent rather than directly by a human user. Without this, agents can bypass APEX-level access controls:

```sql
-- APEX Authorization Scheme: Allow agent OR human access
-- Scheme Type: PL/SQL Function Returning Boolean

RETURN (
  -- Human user has the required role
  APEX_ACL.HAS_USER_ROLE(
    p_application_id => :APP_ID,
    p_user_name      => V('APP_USER'),
    p_role_static_id => 'DATA_ANALYST'
  )
  OR
  -- OR: An authorized agent is acting on behalf of a user with the role
  (
    SYS_CONTEXT('AGENT_CTX','AGENT_ID') IS NOT NULL
    AND agent_registry.agent_has_capability(
          SYS_CONTEXT('AGENT_CTX','AGENT_ID'), 'DATA_ANALYST_SCOPE'
        ) = 'Y'
    AND APEX_ACL.HAS_USER_ROLE(
          p_application_id => :APP_ID,
          p_user_name      => SYS_CONTEXT('AGENT_CTX','HUMAN_USER'),
          p_role_static_id => 'DATA_ANALYST'
        )
  )
);
```

### 6.5 APEX Workflows — Parallel Branches and Identity Isolation

APEX 26.1 introduces **Parallel Flow** in its workflow engine, allowing workflow activities to execute simultaneously across two or more branches. In a multi-agent context, each parallel branch is an independent agent invocation — and each must carry an isolated copy of the identity context to prevent cross-contamination. Use `new_task_id()` to scope each branch with a unique task identifier derived from the shared workflow ID.

---

## 7. APEXlang and Agent Identity

**APEXlang** (formally released in APEX 26.1) is Oracle's open, declarative specification language for APEX applications. It changes the fundamental representation of an APEX application from a binary ZIP of internal API calls to a human-readable, version-controllable, file-based format — creating a governed AI runtime where AI-generated changes are inspectable and auditable.

For agent identity, APEXlang matters in two ways: it is the language through which agent-facing APIs and workflow triggers are defined, and it introduces its own identity-aware expression syntax.

### 7.1 Identity Context in APEXlang Expressions

APEXlang expressions execute in the APEX session context, giving them access to both APEX session state and Oracle database session context. Agent-aware APEXlang expressions should explicitly reference agent context values:

```javascript
/* APEXlang: Agent-aware computed column expression */
/* Determines effective data owner for a new record */

IF(
  ctx:get('AGENT_CTX', 'AGENT_ID') != null,
  /* Agent-created record: owner is the human principal */
  ctx:get('AGENT_CTX', 'HUMAN_USER'),
  /* Direct user action: owner is the APEX session user */
  session:user()
)
```

```javascript
/* APEXlang: Workflow ID propagation in REST handler */
/* Ensures agent-initiated REST calls carry correlation ID */

let workflow_id = coalesce(
  request:header('X-Agent-Workflow-Id'),
  ctx:get('AGENT_CTX', 'WORKFLOW_ID'),
  session:state('G_WORKFLOW_ID')
);

/* Fail fast if no identity context available */
assert(
  workflow_id != null,
  'IDENTITY_ERROR: No workflow ID found in agent request'
);

/* Set for downstream processing */
session:setState('G_ACTIVE_WORKFLOW_ID', workflow_id);
```

### 7.2 APEXlang Agent Dispatch Pattern

APEXlang can be used to define a clean agent dispatch layer — a routing expression that selects and invokes the appropriate agent based on request context, while enforcing identity constraints before any agent call is made:

```javascript
/* APEXlang: Agent dispatch with identity gate */

let agent_id           = request:body().agent_id;
let required_capability = request:body().capability;

/* Identity Gate: verify agent is registered and capable */
let is_authorized = db:scalar(
  'SELECT agent_registry.agent_has_capability(:1, :2) FROM DUAL',
  [agent_id, required_capability]
) == 'Y';

if (!is_authorized) {
  response:error(403, 'Agent ' + agent_id + ' lacks capability: ' + required_capability);
}

/* Dispatch to registered agent endpoint */
let agent_endpoint = db:scalar(
  'SELECT endpoint_url FROM agent_registry WHERE agent_id = :1',
  [agent_id]
);

http:post(agent_endpoint, {
  workflow_id: ctx:get('AGENT_CTX', 'WORKFLOW_ID'),
  task_id:     ctx:get('AGENT_CTX', 'TASK_ID'),
  human_user:  session:user(),
  payload:     request:body().payload
});
```

### 7.3 APEXlang Audit Decorators

A powerful pattern in APEXlang is wrapping all agent-facing data mutation operations in audit decorators — expressions that automatically record the full identity chain before and after any data change:

```javascript
/* APEXlang: Audit decorator for agent-initiated DML */

let audit_entry = {
  action_time:  now(),
  agent_id:     ctx:get('AGENT_CTX', 'AGENT_ID'),
  workflow_id:  ctx:get('AGENT_CTX', 'WORKFLOW_ID'),
  task_id:      ctx:get('AGENT_CTX', 'TASK_ID'),
  human_user:   ctx:get('AGENT_CTX', 'HUMAN_USER'),
  parent_agent: ctx:get('AGENT_CTX', 'PARENT_AGENT'),
  action_type:  'DML',
  table_name:   params.table_name,
  record_id:    params.record_id
};

db:insert('agent_audit_log', audit_entry);

/* Proceed with actual operation */
db:execute(params.dml_statement);
```

### 7.4 APEXlang as a Governance Layer

Because APEXlang files are plain text, they can be committed to version control and reviewed like any source code. This means agent identity policies expressed in APEXlang are auditable by security teams, reviewable in pull requests, and revertable if a policy change introduces a vulnerability. This is a meaningful governance improvement over binary APEX exports or runtime VPD policy changes that leave no diff trail.

---

## 8. End-to-End Reference Architecture

Bringing all layers together, the following architecture represents a production-grade agent identity solution spanning APEX 26.1, APEXlang, and Oracle AI Database 26ai:

```
┌──────────────────────────────────────────────────────────────────┐
│                     HUMAN USER (IAM-Authenticated)               │
└─────────────────────────────┬────────────────────────────────────┘
                              │ OAuth 2.0 Token + Session
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│          ORACLE APEX 26.1 (Identity Origin + AI Runtime)         │
│  • APEXlang dispatch layer with identity gate                    │
│  • AI Agents with Tools (human confirmation for sensitive ops)   │
│  • Parallel workflow branches with isolated task IDs             │
│  • APEX Authorization Schemes extended for agent actors          │
└─────────────────────────────┬────────────────────────────────────┘
                              │ Correlation ID + Agent Context
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│          ORACLE DB AGENT CONTEXT LAYER (All Versions)            │
│  • Proxy Auth (legacy) or IAM Token (26ai)                       │
│  • AGENT_CTX application context namespace                       │
│  • agent_identity package (Correlation ID generation)            │
│  • agent_registry table (registered agents + capabilities)       │
└─────────────────────────────┬────────────────────────────────────┘
                              │ Agent Principal
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│     ORCHESTRATOR AGENT (Carries Correlation ID)                  │
│  • Select AI Agent (26ai) or external agent framework            │
│  • Oracle Unified Memory Core (stateful context)                 │
│  • MCP Server integration (Deep Data Security enforced)          │
└──────────┬────────────────────────────┬────────────────────────-─┘
           │                            │
     Sub-Agent A                  Sub-Agent B
  (inherits chain)             (inherits chain)
           │                            │
           └────────────┬───────────────┘
                        ▼
┌──────────────────────────────────────────────────────────────────┐
│            ORACLE AI DATABASE 26ai ENGINE                        │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              DEEP DATA SECURITY                           │  │
│  │  • Row / Column / Cell policies (declarative SQL)         │  │
│  │  • VPD + FGA (legacy compatibility layer)                 │  │
│  │  • AI Profile capability boundaries                       │  │
│  │  • Full identity chain in audit trail                     │  │
│  └───────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

### 8.1 Agent Registry Table

A central agent registry table is the cornerstone of the architecture — every agent in the system must be registered before it can operate:

```sql
CREATE TABLE agent_registry (
  agent_id          VARCHAR2(100) PRIMARY KEY,
  agent_name        VARCHAR2(200) NOT NULL,
  agent_version     VARCHAR2(20)  NOT NULL,
  endpoint_url      VARCHAR2(500),
  db_proxy_user     VARCHAR2(128),
  owner_human_user  VARCHAR2(128) NOT NULL,
  capabilities      VARCHAR2(4000),  -- JSON array
  max_delegation    NUMBER(2) DEFAULT 3,
  hmac_secret_hash  VARCHAR2(64),    -- SHA-256 of shared secret
  is_active         CHAR(1) DEFAULT 'Y',
  registered_at     TIMESTAMP DEFAULT SYSTIMESTAMP,
  last_seen_at      TIMESTAMP,
  CONSTRAINT chk_active CHECK (is_active IN ('Y','N'))
);

-- Index for fast capability lookups
CREATE INDEX idx_agent_cap ON agent_registry(agent_id, is_active);
```

### 8.2 Agent Audit Log

```sql
CREATE TABLE agent_audit_log (
  audit_id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  log_time          TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  agent_id          VARCHAR2(100),
  parent_agent_id   VARCHAR2(100),
  workflow_id       VARCHAR2(100),
  task_id           VARCHAR2(100),
  human_user        VARCHAR2(128),
  delegation_depth  NUMBER(2),
  action_type       VARCHAR2(50),   -- SELECT, INSERT, UPDATE, DELETE, AI_CALL
  target_schema     VARCHAR2(128),
  target_object     VARCHAR2(128),
  record_id         VARCHAR2(200),
  outcome           VARCHAR2(20),   -- SUCCESS, FAILURE, DENIED
  error_message     VARCHAR2(4000),
  apex_session_id   NUMBER,
  apex_app_id       NUMBER
);

-- Partition by month for performance on high-volume deployments
-- ALTER TABLE agent_audit_log MODIFY PARTITION BY RANGE (log_time)
-- INTERVAL (NUMTOYMINTERVAL(1,'MONTH')) ...;
```

---

## 9. Security Hardening for Agent Identity

### 9.1 Prompt Injection and Identity Spoofing

AI agents are vulnerable to prompt injection attacks where malicious content in retrieved data instructs the agent to claim a different identity or bypass authorization checks. Oracle 26ai's Deep Data Security provides a database-level defense: even if an agent is instructed to elevate its identity, declarative policies return only authorized data regardless of the SQL the agent executes.

For legacy Oracle, defensive validation in stored procedures is essential:

```sql
-- Validate agent ID is in the registry before trusting any context
CREATE OR REPLACE FUNCTION validate_agent_id(
  p_agent_id VARCHAR2
) RETURN BOOLEAN AS
  l_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_count
  FROM   agent_registry
  WHERE  agent_id = p_agent_id
  AND    is_active = 'Y';

  RETURN l_count > 0;
END;
/
```

### 9.2 Delegation Depth Enforcement

Unbounded agent delegation chains are a security risk — a compromised sub-agent could spawn infinite sub-agents to exhaust resources or bypass controls. Enforce delegation depth both in the registry and in session context:

```sql
-- Enforce max delegation depth on sub-agent spawn
CREATE OR REPLACE PROCEDURE spawn_sub_agent(
  p_sub_agent_id VARCHAR2,
  p_task_id      VARCHAR2
) AS
  l_current_depth  NUMBER;
  l_max_depth      NUMBER;
BEGIN
  l_current_depth := TO_NUMBER(
    NVL(SYS_CONTEXT('AGENT_CTX','DELEGATION_DEPTH'),'0')
  );

  SELECT max_delegation INTO l_max_depth
  FROM   agent_registry
  WHERE  agent_id = SYS_CONTEXT('AGENT_CTX','AGENT_ID');

  IF l_current_depth >= l_max_depth THEN
    RAISE_APPLICATION_ERROR(-20001,
      'Max delegation depth exceeded for agent: '
      || SYS_CONTEXT('AGENT_CTX','AGENT_ID'));
  END IF;

  -- Propagate context to sub-agent
  DBMS_SESSION.SET_CONTEXT('AGENT_CTX','PARENT_AGENT',
    SYS_CONTEXT('AGENT_CTX','AGENT_ID'));
  DBMS_SESSION.SET_CONTEXT('AGENT_CTX','AGENT_ID', p_sub_agent_id);
  DBMS_SESSION.SET_CONTEXT('AGENT_CTX','DELEGATION_DEPTH',
    TO_CHAR(l_current_depth + 1));
  DBMS_SESSION.SET_CONTEXT('AGENT_CTX','TASK_ID', p_task_id);
END;
/
```

### 9.3 FIPS 140-3 and Common Criteria

As of January 26, 2026, Oracle AI Database 26ai has achieved **Common Criteria certification** and completed laboratory testing for **FIPS 140-3**. For healthcare, government, and financial deployments where these certifications are required, this means the identity propagation mechanisms described in this article operate within a formally certified security boundary — a meaningful compliance differentiator over external agent frameworks.

---

## 10. Migration Path: Legacy Oracle to 26ai

Organizations running agent workloads on older Oracle versions have a structured migration path. The identity patterns described for legacy versions are intentionally compatible with 26ai — the application context namespace can be preserved while 26ai's native capabilities are adopted incrementally.

| Phase | Action | Identity Benefit |
|---|---|---|
| **1** | Implement `agent_registry` + `agent_identity` package on current version | Establishes registry baseline; zero downtime |
| **2** | Add proxy auth for all agent DB connections | Audit trail gains human principal visibility |
| **3** | Retrofit APEX apps to call `agent_identity.init_agent` on session start | APEX workflows gain correlation ID tracking |
| **4** | Upgrade to 23ai: enable Application Context enhancements | Stronger context isolation per container DB |
| **5** | Upgrade to 26ai (apply October 2025 RU): register formal `AGENT PRINCIPAL`s | Native DB-enforced identity; retire custom packages |
| **6** | Enable Oracle Deep Data Security | Declarative policy replaces procedural VPD; MCP gap closed |
| **7** | Upgrade to APEX 26.1: adopt APEXlang + AI Agents with Tools | Governed AI runtime with human confirmation gates |
| **8** | Migrate AI Profiles to 26ai native format | Capability scoping enforced at engine level |

---

## 11. Conclusion

The Agent Identity Crisis is not a future problem — it is present in every Oracle environment running AI agents today without explicit identity architecture. Agents that operate as opaque service accounts create audit black holes, bypass row-level security, and produce unattributable data, all of which represent both operational and regulatory risk.

The solution is layered and version-adaptive. On legacy Oracle, the combination of proxy authentication, application context, a central agent registry, and correlation ID propagation delivers meaningful identity integrity at the cost of disciplined implementation. Oracle APEX 26.1 serves as the natural identity origin point, and APEXlang expressions can enforce agent identity constraints declaratively at the API boundary — with the added benefit of version-controllable policy files.

Oracle AI Database 26ai elevates this to a first-class architectural concern. **Oracle Deep Data Security** (March 2026) moves the trust boundary into the database engine itself, enforcing end-user authorization at the row, column, and cell level regardless of whether the access path is a human, an application, an AI agent, or an MCP server. The **Oracle Unified Memory Core** eliminates stateless context loss. The **Private Agent Factory** provides a governed no-code environment for deploying agents that inherit the full Oracle security model by construction.

The migration path is incremental: organizations can begin solving the identity crisis today on their current Oracle versions, and have their architecture naturally absorb 26ai's native capabilities as they upgrade. The core principle does not change across versions:

> **Every agent action must be traceable to a human principal, scoped by declared capabilities, and recorded with a full identity chain.**

---

## 12. References & Further Reading

### Oracle Official Documentation
- [Oracle AI Database 26ai — Official Announcement](https://www.oracle.com/news/announcement/ai-world-database-26ai-powers-the-ai-for-data-revolution-2025-10-14/)
- [Introducing Oracle AI Database 26ai (Blog)](https://blogs.oracle.com/database/oracle-announces-oracle-ai-database-26ai)
- [Oracle Deep Data Security — Feature Overview](https://www.oracle.com/security/database-security/features/deep-data-security/)
- [Introducing Oracle Deep Data Security (Blog)](https://blogs.oracle.com/database/introducing-oracle-deep-data-security-identity-aware-data-access-control-for-agentic-ai-in-oracle-ai-database-26ai)
- [Oracle Deep Data Security Is Now Available (Blog)](https://blogs.oracle.com/database/oracle-deep-data-security-is-now-available-in-oracle-ai-database-26ai)
- [Oracle Deep Data Security Guide PDF (April 2026)](https://docs.oracle.com/en/database/oracle/oracle-database/26/ddscg/oracle-deep-data-security-guide.pdf)
- [Building Trusted GenAI Experiences with Deep Data Security](https://blogs.oracle.com/database/building-trusted-genai-experiences-with-oracle-deep-data-security)
- [Oracle AI Vector Search Guide — VPD and Vector-Aware Security](https://docs.oracle.com/en/database/oracle/oracle-database/23/vecse)
- [What's New in Oracle APEX 26.1](https://www.oracle.com/apex/whats-new/)
- [Oracle APEX 26.1 Release Notes PDF](https://docs.oracle.com/en/database/oracle/apex/26.1/htmrn/oracle-apex-release-notes.pdf)
- [AI Agents in Oracle APEX (Blog)](https://blogs.oracle.com/apex/ai-agents-in-oracle-apex)

### Security References
- [OWASP LLM Top 10 — Prompt Injection](https://owasp.org/www-project-top-10-for-large-language-model-applications)
- Oracle Database Security Guide — Proxy Authentication and Application Context
- Oracle Real Application Security (RAS) — Fine-Grained Authorization for AI Workloads
- DBMS_AI Package Reference — AI Profile Management (Oracle 23ai+)

### Analyst Perspectives
- [Oracle Positions AI Database 26ai to Lead $1.2T Market — Futurum (March 2026)](https://futurumgroup.com/insights/oracle-positions-ai-database-26ai-to-lead-1-2-trillion-market-by-bridging-the-agentic-reasoning-gap/)
- [Deep Data Security and MCP: Moving the Trust Boundary Into the Database](https://www.rogercornejo.com/genai-demystified/2026/4/10/deep-data-security-and-mcp-moving-the-trust-boundary-into-the-database)
- [Database-Enforced Authorization for Agentic AI .NET Applications](https://blogs.oracle.com/developers/database-enforced-authorization-for-agentic-ai-net-applications)

---

*Article maintained in the [Oracle AI Developers Community](https://github.com/hvrcharon1/Oracle-AI-Developers-Community). Contributions and corrections welcome — see [CONTRIBUTING.md](../../CONTRIBUTING.md).*
