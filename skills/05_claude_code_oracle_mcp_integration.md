# Skill 05: Claude Code + Oracle MCP Integration

**Category:** IDEs | MCP | **Level:** Intermediate

---

## Overview

Claude Code is Anthropic's agentic command-line coding tool. When connected to Oracle Autonomous AI Database via MCP, it becomes an enterprise-aware coding agent that can inspect schemas, query live data, and write accurate, grounded code — all without leaving your terminal.

---

## Prerequisites

- Node.js 18+
- Oracle Autonomous AI Database with MCP Server enabled (see Skill 03)
- OCI IAM OAuth credentials (see Skill 09)

---

## Step-by-Step

### 1. Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code
claude --version
```

### 2. Add the Oracle MCP Server

```bash
claude mcp add oracle-adb \
  --url "https://<instance>.adb.<region>.oraclecloudapps.com/ords/<schema>/mcp/v1" \
  --auth-type oauth2 \
  --token-endpoint "https://idcs-<tenant>.identity.oraclecloud.com/oauth2/v1/token" \
  --client-id "<client-id>" \
  --client-secret "<client-secret>" \
  --scope "urn:opc:db:mcp"
```

### 3. Verify the Connection

```bash
claude mcp list
# oracle-adb  connected  12 tools available
```

### 4. Use Claude Code Interactively

```bash
claude
```

Example prompts:

```
> What tables exist in the SALES schema and what are their primary keys?
> Show me total revenue by region for the last 30 days.
> Write a Python script to export Q1 2025 sales data to CSV. Save it to scripts/q1_export.py and test it.
```

### 5. One-Shot Agentic Mode

```bash
claude -p "Analyse the ORDERS table schema and generate a SQLAlchemy model. Save to models/orders.py"
```

---

## What Claude Code Can Do with Oracle MCP

| Task | How |
|---|---|
| Understand your schema | MCP `describe_table` + `list_tables` |
| Query live data | MCP `run_sql` or custom agent tools |
| Generate accurate models | Schema-grounded code generation |
| Write and test scripts | Agentic file write + shell execution |
| Iterate on errors | Autonomous fix-and-retry loops |

---

## Related Skills

- [Skill 03: MCP Server Setup](03_mcp_server_setup_autonomous_ai_database.md)
- [Skill 09: OAuth 2.0 Authentication](09_oauth2_authentication_oracle_mcp.md)

**#ClaudeCode #Anthropic #OracleAI #MCP #AICoding**
