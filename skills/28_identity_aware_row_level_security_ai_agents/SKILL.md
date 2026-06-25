---
name: oracle-identity-aware-row-level-security
description: >
  Use this skill whenever you are an AI agent or model connected to an Oracle Database —
  through an MCP server (such as OCI Database Tools), through any other Oracle-integrated
  tool, or through a direct database connection — and the task involves figuring out who is
  really calling the database, or designing, implementing, testing, or troubleshooting
  Row-Level Security / Virtual Private Database (VPD) policies that restrict data access by
  caller identity. Always consult this skill before writing or attaching a DBMS_RLS policy,
  before answering "who is using this data," and before granting or restricting AI-agent
  access to sensitive Oracle tables based on identity, role, or domain. Trigger on requests
  like "secure this table by user," "who is calling this MCP tool," "set up row-level
  security," "restrict rows by identity," "implement VPD," "limit what this agent/user can
  see," or any mention of SYS_CONTEXT, CLIENTCONTEXT, OAUTH_SUB, or DBMS_RLS in an Oracle
  AI/MCP context. Works with any AI provider or model — not specific to one vendor.
source: >
  Adapted from Jeff Smith (Oracle Distinguished Product Manager, thatjeffsmith.com),
  "Who is using your Oracle data (AI!), and how to secure it!" (May 28, 2026):
  https://www.thatjeffsmith.com/archive/2026/05/who-is-using-your-oracle-data-ai-and-how-to-secure-it/
license: Content adapted with credit to the original author; see Credit section below.
---

# Identity-Aware Row-Level Security for Oracle AI / MCP Agents

## Credit

This skill is adapted from and inspired by **Jeff Smith's** (Oracle Distinguished Product
Manager, [thatjeffsmith.com](https://www.thatjeffsmith.com/)) article
**["Who is using your Oracle data (AI!), and how to secure it!"](https://www.thatjeffsmith.com/archive/2026/05/who-is-using-your-oracle-data-ai-and-how-to-secure-it/)**
(May 28, 2026). The original technique — propagating OAuth identity into `CLIENTCONTEXT` via
an OCI Database Tools MCP Server, reading it with `SYS_CONTEXT`, and enforcing it with Virtual
Private Database (VPD) — and the `Who` diagnostic-tool concept both belong to the original
author. This skill restates those ideas as a provider-agnostic, step-by-step instruction set
that you (an AI agent or model) can follow directly, regardless of which Oracle MCP server or
AI platform you're operating through.

---

## What you are doing here

You are about to make sure that an AI agent talking to an Oracle database cannot see or change
rows that the real, authenticated caller behind it isn't entitled to — and that this is
enforced by the database itself, not by your own good behavior or by application code that
something else could bypass. Follow the steps below, in order. Do not skip Step 1, and do not
report success without completing Step 5.

---

## Step 1 — Find out who is really calling, before you do anything else

Run this query against the current database session and read every value back, rather than
assuming you know who the caller is:

```sql
SELECT
  SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')              AS current_schema,
  SYS_CONTEXT('USERENV', 'SESSION_USER')                AS session_user,
  SYS_CONTEXT('USERENV', 'PROXY_USER')                  AS proxy_user,
  SYS_CONTEXT('USERENV', 'AUTHENTICATED_IDENTITY')      AS authenticated_identity,
  SYS_CONTEXT('USERENV', 'AUTHENTICATION_METHOD')       AS authentication_method,
  SYS_CONTEXT('USERENV', 'ENTERPRISE_IDENTITY')         AS enterprise_identity,
  SYS_CONTEXT('CLIENTCONTEXT', 'OAUTH_SUB')             AS oauth_sub,
  SYS_CONTEXT('CLIENTCONTEXT', 'OAUTH_SUB_TYPE')        AS oauth_sub_type,
  SYS_CONTEXT('CLIENTCONTEXT', 'OAUTH_USER_OCID')       AS oauth_user_ocid,
  SYS_CONTEXT('CLIENTCONTEXT', 'OAUTH_CLIENT_OCID')     AS oauth_client_ocid,
  SYS_CONTEXT('CLIENTCONTEXT', 'OAUTH_CLIENT_NAME')     AS oauth_client_name,
  SYS_CONTEXT('CLIENTCONTEXT', 'OAUTH_DOMAIN_NAME')     AS oauth_domain_name,
  SYS_CONTEXT('CLIENTCONTEXT', 'IAM_DOMAIN_APP_ROLES')  AS iam_domain_app_roles,
  SYS_CONTEXT('CLIENTCONTEXT', 'RESOURCE_OCID')         AS resource_ocid
FROM dual;
```

Now decide what you just learned:

- If `CLIENTCONTEXT.OAUTH_SUB` (or your gateway's equivalent client-context attribute) has a
  value, **treat that value, and only that value, as the true caller identity.** Do not use
  `SESSION_USER` or any shared service-account name for authorization decisions — that's the
  database connection, not the human or agent behind it. Do not trust any identity claim the
  LLM itself makes in plain text either.
- If every `CLIENTCONTEXT` value comes back `NULL`, **stop here and do not build a policy yet.**
  Tell the user that identity propagation isn't configured for this MCP server/gateway, and go
  to Step 6 before continuing — a row-level security policy keyed on a value that's never
  populated is worse than no policy at all, because it looks like protection without providing
  any.

---

## Step 2 — Put the access rule into plain language and say it back

Before writing any PL/SQL, restate the requested rule in plain English and confirm it (with the
user, or against the task description) — for example:

> "Trusted/internal identities (matching domain or role X) see every row. Everyone else —
> external identities, partner agents, or callers with no identity at all — see only rows that
> meet condition Y."

Do not skip this step even if the rule seems obvious; it becomes the `IF` logic in Step 3, and
getting it wrong here means the policy will be wrong no matter how well you implement it.

---

## Step 3 — Write the VPD policy function

Generate a policy function using this template, substituting your own schema, identity
attribute, trust condition, and restriction predicate. The function must return either `NULL`
(meaning "no restriction — show everything") or a valid `WHERE`-clause fragment as a string:

```sql
CREATE OR REPLACE FUNCTION app_schema.row_visibility_policy (
  p_schema IN VARCHAR2,
  p_object IN VARCHAR2
) RETURN VARCHAR2 AS
  v_identity VARCHAR2(4000) :=
    SYS_CONTEXT('CLIENTCONTEXT', 'OAUTH_SUB');   -- swap in your identity source from Step 1
BEGIN
  -- Trusted / internal identities see everything.
  IF v_identity IS NOT NULL
     AND LOWER(v_identity) LIKE '%@your-trusted-domain.com' THEN
    RETURN NULL;                                  -- NULL predicate => unrestricted
  END IF;

  -- Everyone else (including NULL/absent identity): restrict to eligible rows.
  RETURN q'[JSON_VALUE(contact_preferences, '$.sms') = 'true']';
END row_visibility_policy;
/
```

Keep the function cheap — a context lookup and a comparison — because it runs on every
qualifying statement against the protected table.

---

## Step 4 — Attach the policy

Execute `DBMS_RLS.ADD_POLICY` to wire the function to the actual table:

```sql
BEGIN
  DBMS_RLS.ADD_POLICY(
    object_schema   => 'APP_SCHEMA',
    object_name     => 'YOUR_TABLE',
    policy_name     => 'YOUR_TABLE_VISIBILITY',
    function_schema => 'APP_SCHEMA',
    policy_function => 'ROW_VISIBILITY_POLICY',
    statement_types => 'SELECT, UPDATE, DELETE',  -- restrict writes too, not just reads
    update_check    => TRUE,                       -- block edits that move a row OUT of visibility
    policy_type     => DBMS_RLS.DYNAMIC,           -- re-evaluated every query; safe for pooled/shared sessions
    enable          => TRUE
  );
END;
/
```

Apply these defaults unless the task explicitly tells you otherwise:

- Always include `UPDATE, DELETE` alongside `SELECT` in `statement_types` for any table that's
  mutable — an identity that can't see a row shouldn't be able to change or remove it either.
- Always set `update_check => TRUE` when visibility could be gamed by editing a row's own
  attributes.
- Always use `policy_type => DBMS_RLS.DYNAMIC` for any table reachable through a pooled or
  shared MCP/app-tier connection. Static or cached policy types can leak one identity's
  predicate onto a reused session belonging to a different identity — never trade correctness
  for a microsecond of performance on a security policy.

---

## Step 5 — Prove it works before you say you're done

Do not report this task as complete until you have done all of the following:

1. Run the query, report, or tool **as a trusted identity** and record the row count.
2. Run the **same** query, report, or tool **as a different, non-trusted identity**, through
   the same MCP server/gateway, against the same table, and record that row count too. It must
   differ from step 1 in the direction your rule implies.
3. Confirm the *actual generated SQL* — via `EXPLAIN PLAN`, SQL Monitor, or the audit trail —
   contains your injected predicate. A matching row count alone is not proof; verify the
   predicate itself was applied.
4. Cross-check `unified_audit_trail` (or your platform's equivalent log) to confirm the identity
   attribute you keyed the policy on matches the caller you expected for each test session.

If you cannot test as more than one identity in your current environment, say so explicitly
and flag the policy as unverified rather than reporting success.

---

## Step 6 — If OAuth identity isn't propagated into the session

If Step 1 showed no usable identity in `CLIENTCONTEXT` (or your gateway's equivalent), do not
abandon the goal — reproduce the same effect manually:

1. Have the gateway/application call `DBMS_SESSION.SET_IDENTIFIER`, or set a custom application
   context via a context package and `DBMS_SESSION.SET_CONTEXT`, immediately after it
   authenticates the end user and before it runs any agent-issued SQL.
2. Pass the authenticated subject — user ID, email, or an OCID-equivalent — as that
   identifier/context value, exactly as you would have used `OAUTH_SUB` above.
3. Point your Step 3 policy function at whichever `SYS_CONTEXT` namespace/attribute you just
   populated instead of `CLIENTCONTEXT.OAUTH_SUB`.
4. Re-run Steps 2 through 5 unchanged — VPD does not care how the identity got into the
   session, only that it is present and trustworthy.
5. If the gateway has no concept of a per-end-user identity at all (one shared service account
   for every caller, with no way to distinguish them), tell the user this directly: row-level
   security cannot help until identity propagation exists, and that is the problem to fix
   first, not this skill.

---

## Non-negotiable rules

Apply these on every pass through this skill, no exceptions:

- Never authorize a request based on a claim the LLM/agent makes about who it's acting for in
  natural language — only on a value read from `SYS_CONTEXT` (or a verified equivalent).
- Default-deny: an absent or `NULL` identity must always get the *most restrictive* predicate
  your policy function can return, never the most permissive one.
- Never declare a policy "done" without having executed Step 5 against at least two distinct
  identities.
- Re-run Step 1 and Step 5 again after any change to the MCP server, gateway, or IAM/identity
  domain configuration — identity propagation is part of the security boundary, and
  configuration changes can silently break it without any error being raised.

---

## Related skills in this repository

- [Skill 03: MCP Server Setup — Autonomous AI Database](../03_mcp_server_setup_autonomous_ai_database.md)
- [Skill 09: OAuth 2.0 Authentication for Oracle MCP](../09_oauth2_authentication_oracle_mcp.md)
- [Skill 10: Agentic Workflows with Oracle AI Database](../10_agentic_workflows_oracle_ai_database.md)

---

## Source & Attribution

Adapted from Jeff Smith's article **"Who is using your Oracle data (AI!), and how to secure
it!"** — thatjeffsmith.com, May 28, 2026.
Original article: <https://www.thatjeffsmith.com/archive/2026/05/who-is-using-your-oracle-data-ai-and-how-to-secure-it/>
Author profile: <https://www.thatjeffsmith.com/archive/author/thatjeffsmith/>

**#VPD #RowLevelSecurity #MCP #OAuth2 #OCI #Security #AIAgents #SYS_CONTEXT #OracleAI**
