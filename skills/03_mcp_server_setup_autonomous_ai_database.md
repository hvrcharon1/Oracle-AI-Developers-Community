# Skill 03: MCP Server Setup — Oracle Autonomous AI Database

**Category:** MCP | Integration | **Level:** Intermediate

---

## Overview

Oracle Autonomous AI Database includes a **built-in, managed MCP (Model Context Protocol) Server**. Enabling it takes minutes and immediately makes your database tools discoverable by any MCP-compatible AI client — including Claude Code, OpenAI Codex, Claude Desktop, and custom agents — with no separate server to deploy.

---

## Prerequisites

- An Oracle Autonomous AI Database (Serverless) instance on OCI
- OCI IAM permissions to manage the database and register applications
- An MCP-compatible AI client (Claude Code, Claude Desktop, etc.)

---

## Step-by-Step

### 1. Enable the MCP Server

1. Open **OCI Console** → your Autonomous Database instance
2. Click **Database Actions** → **AI** → **MCP Server**
3. Toggle **Enable MCP Server** → confirm
4. Copy the generated **MCP Endpoint URL**:

```
https://<instance>.adb.<region>.oraclecloudapps.com/ords/<schema>/mcp/v1
```

### 2. Verify the Discovery Endpoint

Call the MCP discovery endpoint to confirm the server is live:

```bash
curl -s https://<instance>.adb.<region>.oraclecloudapps.com/ords/<schema>/mcp/v1 \
  -H "Authorization: Bearer <access_token>" | jq .
```

You should receive a JSON document listing all available tools.

### 3. Register an OAuth Application in OCI IAM

1. Go to **OCI Console** → **Identity & Security** → **Identity** → **Applications**
2. Click **Add Application** → **Confidential Application**
3. Under **API Access**, grant scope: `urn:opc:db:mcp`
4. Save the **Client ID** and **Client Secret**

### 4. Grant Database Roles to the OAuth Client

```sql
-- Connect as ADMIN in your Autonomous Database
GRANT SELECT ANY TABLE TO <oauth_schema_user>;
GRANT EXECUTE ON DBMS_CLOUD_AI_AGENT TO <oauth_schema_user>;
```

### 5. Connect an MCP Client

Example configuration for Claude Code (`~/.claude/claude_code_config.json`):

```json
{
  "mcpServers": {
    "oracle-adb": {
      "url": "https://<instance>.adb.<region>.oraclecloudapps.com/ords/<schema>/mcp/v1",
      "auth": {
        "type": "oauth2",
        "tokenEndpoint": "https://idcs-<tenant>.identity.oraclecloud.com/oauth2/v1/token",
        "clientId": "<client-id>",
        "clientSecret": "<client-secret>",
        "scope": "urn:opc:db:mcp"
      }
    }
  }
}
```

---

## Built-in Tools Exposed by the MCP Server

| Tool | Description |
|---|---|
| `list_tables` | List tables visible to the authenticated user |
| `describe_table` | Return column names, types, and constraints for a table |
| `run_sql` | Execute a SELECT query and return results as JSON |
| `list_agent_tools` | List custom Select AI Agent tools defined with DBMS_CLOUD_AI_AGENT |

---

## Related Skills

- [Skill 04: Building AI Agents with DBMS_CLOUD_AI_AGENT](04_building_ai_agents_dbms_cloud_ai_agent.md)
- [Skill 09: OAuth 2.0 Authentication for Oracle MCP](09_oauth2_authentication_oracle_mcp.md)
- [Skill 05: Claude Code + Oracle MCP Integration](05_claude_code_oracle_mcp_integration.md)

**#MCP #OracleAI #AutonomousDatabase #OCI #MCPServer**
