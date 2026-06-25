# Skill 28 — Identity-Aware Row-Level Security for Oracle AI / MCP Agents

> **A skill for AI agents integrated with Oracle Database and OCI AI Database MCP Servers.**

## What This Skill Does

This skill enables any AI model or agent connected to Oracle Database (via an OCI AI Database MCP Server or compatible integration) to:

- Identify **who** is calling the database in any session using `SYS_CONTEXT` and OAuth context values propagated automatically by the MCP layer.
- Build and manage **Row-Level Security (VPD) policies** (`DBMS_RLS`) that filter data based on the caller's authenticated identity — enforced at the database level, not the application tier.
- Create **custom MCP Tools** for identity inspection and pre-approved SQL execution.
- Implement **IAM role-based access controls** using OCI IAM App Roles surfaced in `CLIENTCONTEXT`.
- Set up **targeted audit policies** that log AI/MCP-originated sessions specifically.
- Follow best practices for **NL2SQL safety**, including when to use pre-approved Reports instead of ad-hoc SQL.

## Files in This Skill

```
skills/28_identity_aware_row_level_security_ai_agents/
├── SKILL.md                              ← Main skill definition (load this into your agent)
├── README.md                             ← This file
└── examples/
    ├── who-tool.sql                      ← SQL for the "who" identity MCP Tool
    ├── vpd-email-domain-policy.sql       ← VPD policy based on email domain (OAUTH_SUB)
    ├── vpd-iam-role-policy.sql           ← VPD policy based on OCI IAM App Roles
    └── audit-ai-sessions.sql             ← Unified Audit policy for AI/MCP sessions
```

## How to Use

1. **For AI agents / MCP clients**: Point your agent's system prompt or skill loader at `SKILL.md`. The agent will follow the step-by-step instructions to identify callers and implement VPD policies correctly.
2. **For database administrators**: Use the SQL files in `examples/` directly in SQL*Plus, SQLcl, or Oracle SQL Developer. Replace `<SCHEMA>` and `<TABLE_NAME>` placeholders with your actual values.
3. **For OCI Database Tools users**: Copy the SQL from `examples/who-tool.sql` into a new Custom Tool in your MCP Server configuration and name it `who` or `whoami`.

## Prerequisites

- Oracle Database 19c or later (for `JSON_VALUE` in VPD predicates)
- OCI AI Database MCP Server (OCI Database Tools) — or any HTTPS-streaming MCP Server with OAuth2 identity propagation
- `EXECUTE ON DBMS_RLS` privilege to create and manage VPD policies
- `AUDIT ADMIN` privilege to create Unified Audit policies
- Federated identity (Azure Entra ID, OCI IAM, Active Directory) connected to your OCI tenancy

---

## Attribution & Credits

This skill is adapted from the following article:

**"Who is using your Oracle data (AI!), and how to secure it!"**  
By **Jeff Smith** ([@thatjeffsmith](https://twitter.com/thatjeffsmith))  
Published: **May 28, 2026**  
URL: <https://www.thatjeffsmith.com/archive/2026/05/who-is-using-your-oracle-data-ai-and-how-to-secure-it/>

Jeff Smith is a Distinguished Product Manager at Oracle, focused on Oracle Database Tools (SQL Developer, SQLcl, Oracle Database Actions, OCI Database Tools). His blog, [ThatJeffSmith.com](https://www.thatjeffsmith.com), covers practical Oracle Database development and administration topics.

The original article demonstrates how OCI AI Database MCP Servers automatically propagate OAuth identity into `SYS_CONTEXT` (`CLIENTCONTEXT`), and shows a complete VPD implementation that restricts customer data visibility based on the caller's email domain — with zero application-tier changes required. The `who` diagnostic tool concept also originates from that article.

> All SQL examples and architectural patterns in this skill are adapted from or directly inspired by Jeff Smith's original work. See the article for live screenshots and demos.

---

*Part of the [Oracle AI Developers Community](https://github.com/hvrcharon1/Oracle-AI-Developers-Community) skills library · June 2026*
