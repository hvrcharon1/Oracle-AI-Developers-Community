# Skill 09: OAuth 2.0 Authentication for Oracle MCP

**Category:** Security | MCP | **Level:** Intermediate

---

## Overview

The Oracle Autonomous AI Database MCP Server uses **OAuth 2.0 client credentials flow** for authentication. This skill covers how to register a confidential application in OCI IAM, obtain access tokens, and grant the minimum necessary database privileges to the OAuth client — following the principle of least privilege.

---

## How It Works

```
MCP Client (Claude Code, Codex, etc.)
     │
     │  1. POST /oauth2/v1/token (client_id + client_secret)
     ▼
OCI IAM Identity Domain
     │
     │  2. Returns access_token (JWT)
     ▼
MCP Client sends: Authorization: Bearer <access_token>
     │
     ▼
Oracle Autonomous AI Database MCP Server
     │  3. Validates token + checks DB grants
     ▼
Tool execution result returned to client
```

---

## Step-by-Step

### 1. Register a Confidential Application in OCI IAM

1. Open **OCI Console** → **Identity & Security** → **Domains** → your domain
2. Click **Applications** → **Add Application** → **Confidential Application**
3. Set a name (e.g., `mcp-client-claude-code`)
4. Under **Client Configuration**:
   - Grant type: **Client Credentials**
   - Add scope: `urn:opc:db:mcp`
5. Save — note the **Client ID** and **Client Secret**

### 2. Obtain an Access Token (Manual Test)

```bash
curl -s -X POST \
  https://idcs-<your-tenant>.identity.oraclecloud.com/oauth2/v1/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=<your-client-id>" \
  -d "client_secret=<your-client-secret>" \
  -d "scope=urn:opc:db:mcp" | jq .access_token
```

### 3. Map the OAuth Client to a Database User

In Autonomous Database, the OAuth client identity maps to a **schema user**. Create a dedicated low-privilege user:

```sql
-- Connect as ADMIN
CREATE USER mcp_agent_user IDENTIFIED EXTERNALLY AS 'client_id=<your-client-id>';

-- Grant only what the agent needs
GRANT CREATE SESSION TO mcp_agent_user;
GRANT SELECT ON sales.orders TO mcp_agent_user;
GRANT SELECT ON sales.customers TO mcp_agent_user;
GRANT SELECT ON sales.products TO mcp_agent_user;
GRANT EXECUTE ON DBMS_CLOUD_AI_AGENT TO mcp_agent_user;
```

### 4. Rotate Client Secrets

Regularly rotate client secrets in OCI IAM:

1. Go to your confidential application → **Client Configuration**
2. Click **Regenerate Client Secret**
3. Update the secret in your MCP client configuration
4. Verify the new token works before removing the old secret

### 5. Monitor Token Usage

```sql
-- Review recent MCP agent activity in database audit logs
SELECT username, action_name, object_name, timestamp
FROM   unified_audit_trail
WHERE  application_contexts LIKE '%MCP%'
ORDER BY timestamp DESC
FETCH FIRST 50 ROWS ONLY;
```

---

## Security Checklist

- [ ] Use a **dedicated database user** per MCP client — never use ADMIN
- [ ] Grant **SELECT only** on specific tables — not `SELECT ANY TABLE`
- [ ] Set **token expiry** to the shortest acceptable window (default: 3600s)
- [ ] Store client secrets in **OCI Vault** or a secrets manager — never in source code
- [ ] Enable **database auditing** on MCP-accessible tables
- [ ] Review access logs **monthly** and revoke unused credentials

---

## Related Skills

- [Skill 03: MCP Server Setup](03_mcp_server_setup_autonomous_ai_database.md)
- [Skill 05: Claude Code + Oracle MCP Integration](05_claude_code_oracle_mcp_integration.md)

**#OAuth2 #Security #OCI #MCP #OracleAI #IAM #LeastPrivilege**
