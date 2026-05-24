# Connecting OpenAI Codex to Oracle Autonomous AI Database MCP Server

*AI coding agents are becoming much more powerful when they can safely connect to real enterprise systems.*

In this blog, we walk through how to connect **OpenAI Codex** with the **Oracle Autonomous AI Database MCP Server**, enabling Codex to interact with database tools, inspect schemas, retrieve metadata, and support database workflows through the **Model Context Protocol (MCP)**.

What makes this especially compelling is that the MCP Server is a **built-in, managed feature** of Oracle Autonomous AI Database. Teams can expose database capabilities to MCP-compatible AI clients without standing up separate MCP infrastructure — while still relying on database-native security and access controls.

---

## What Is the Model Context Protocol (MCP)?

The Model Context Protocol is an open standard that allows AI models to connect to external tools, data sources, and services in a structured, secure way. Think of it as a universal adapter: instead of building custom integrations for every AI client and data system, MCP defines a common language for capability discovery and invocation.

When an AI agent like OpenAI Codex connects to an MCP Server, it can:

- Discover what tools and resources are available
- Invoke those tools with structured inputs
- Receive structured outputs it can reason over and act upon

Oracle Autonomous AI Database ships with an MCP Server that exposes database capabilities — schema inspection, query execution, metadata retrieval — directly to MCP-compatible clients. No custom middleware required.

---

## Architecture Overview

```
OpenAI Codex (MCP Client)
        │
        │  OAuth 2.0 / HTTPS
        ▼
Oracle Autonomous AI Database
  ├── MCP Server (built-in, managed)
  ├── Select AI Agent Tools (DBMS_CLOUD_AI_AGENT)
  └── Database-native security & access controls
```

This architecture keeps things clean:

- **No separate MCP infrastructure** to manage or scale
- **Database-native access controls** govern what the agent can see and do
- **OAuth 2.0** handles authentication between Codex and the MCP endpoint

---

## Step 1: Enable the Autonomous AI Database MCP Server

The MCP Server is a managed feature of Oracle Autonomous AI Database. To enable it:

1. Navigate to your **Oracle Cloud Infrastructure (OCI) Console**
2. Open your **Autonomous Database** instance
3. Under **Database Actions**, go to **AI** → **MCP Server**
4. Toggle **Enable MCP Server** to on
5. Note the generated **MCP Endpoint URL** — you will need this when configuring Codex

The endpoint follows this pattern:

```
https://<your-adb-instance>.adb.<region>.oraclecloudapps.com/ords/<schema>/mcp/v1
```

Once enabled, the MCP Server automatically exposes built-in database tools including schema introspection, table metadata, and query capabilities.

---

## Step 2: Create Select AI Agent Tools with DBMS_CLOUD_AI_AGENT

Oracle's `DBMS_CLOUD_AI_AGENT` package lets you define custom agent tools that sit on top of your database objects. These tools become discoverable by MCP clients like Codex.

Connect to your Autonomous Database (via SQL Developer Web or SQLcl) and create an agent tool:

```sql
BEGIN
  DBMS_CLOUD_AI_AGENT.CREATE_AGENT_TOOL(
    name        => 'get_sales_summary',
    description => 'Returns aggregated sales data by region and product category for a given date range.',
    query       => q'[
      SELECT
        region,
        product_category,
        SUM(revenue)   AS total_revenue,
        COUNT(*)       AS order_count
      FROM   sales_data
      WHERE  sale_date BETWEEN :start_date AND :end_date
      GROUP BY region, product_category
      ORDER BY total_revenue DESC
    ]',
    parameters  => JSON_OBJECT(
      'start_date' VALUE JSON_OBJECT('type' VALUE 'string', 'description' VALUE 'Start date in YYYY-MM-DD format'),
      'end_date'   VALUE JSON_OBJECT('type' VALUE 'string', 'description' VALUE 'End date in YYYY-MM-DD format')
    )
  );
END;
/
```

You can create multiple tools covering different data domains. Each tool you create is automatically surfaced through the MCP Server to any connected client.

---

## Step 3: Configure Codex to Connect to the MCP Endpoint

OpenAI Codex supports MCP connections through its agent configuration. Add the Oracle Autonomous AI Database MCP Server as a tool source:

```json
{
  "mcpServers": {
    "oracle-adb": {
      "url": "https://<your-adb-instance>.adb.<region>.oraclecloudapps.com/ords/<schema>/mcp/v1",
      "auth": {
        "type": "oauth2",
        "tokenEndpoint": "https://idcs-<your-tenant>.identity.oraclecloud.com/oauth2/v1/token",
        "clientId": "<your-client-id>",
        "clientSecret": "<your-client-secret>",
        "scope": "urn:opc:db:mcp"
      }
    }
  }
}
```

Replace the placeholder values with your actual ADB instance details and OAuth credentials (covered in Step 4).

Once configured, Codex will call the MCP Server's discovery endpoint on startup and load the list of available tools — including both built-in database tools and any custom Select AI Agent tools you defined.

---

## Step 4: Authenticate with OAuth

The MCP Server uses **OAuth 2.0 client credentials** flow. You need to register a confidential application in **OCI Identity and Access Management (IAM)**:

1. Go to **OCI Console** → **Identity & Security** → **Identity** → **Applications**
2. Create a new **Confidential Application**
3. Grant it the OAuth scope: `urn:opc:db:mcp`
4. Note the **Client ID** and **Client Secret**

Then assign the application identity appropriate **database roles** in your Autonomous Database:

```sql
-- Grant the OAuth client read access to the schema
GRANT SELECT ON sales_data TO <oauth_client_username>;

-- Grant access to MCP agent tools
GRANT EXECUTE ON DBMS_CLOUD_AI_AGENT TO <oauth_client_username>;
```

This ensures the agent can only access what it is explicitly permitted to see — no broader database access is granted.

---

## Step 5: Test Agent-Driven Workflows Against Enterprise Data

With Codex connected and authenticated, you can now prompt it to work with your enterprise data using natural language. Codex will automatically discover and invoke the appropriate MCP tools.

**Example prompts you can use:**

> *"Show me a breakdown of Q1 2025 sales by region."*

Codex will:
1. Identify the `get_sales_summary` tool
2. Map Q1 2025 to `start_date: 2025-01-01`, `end_date: 2025-03-31`
3. Call the MCP Server with those parameters
4. Present the structured results back to you

> *"What tables are available in the SALES schema?"*

Codex uses built-in MCP schema inspection tools to retrieve and display the table list — without you writing a single SQL query.

> *"Write a Python script that pulls the top 10 products by revenue for last month and exports them to a CSV."*

Codex can combine its code generation capability with live schema and data context from the MCP Server to generate accurate, ready-to-run code.

---

## Why This Matters for Enterprise AI Development

This integration is a practical example of where AI-assisted development is headed: **not just generating code, but securely working with enterprise context, tools, and workflows**.

Key advantages of this approach:

| Concern | How It's Addressed |
|---|---|
| **Security** | Database-native access controls; OAuth 2.0 authentication |
| **Infrastructure** | No separate MCP server to deploy or manage |
| **Governance** | Fine-grained tool definitions control exactly what agents can do |
| **Auditability** | All agent tool invocations are logged at the database level |
| **Flexibility** | Add or modify tools without changing client configuration |

---

## Summary

Here is what we covered:

- ✅ **Enabling** the Autonomous AI Database MCP Server — a managed, built-in capability
- ✅ **Creating Select AI Agent tools** with `DBMS_CLOUD_AI_AGENT` to expose curated database capabilities
- ✅ **Configuring Codex** to connect to the MCP endpoint
- ✅ **Authenticating with OAuth 2.0** using OCI IAM confidential applications
- ✅ **Testing agent-driven workflows** against real enterprise data

The combination of Oracle Autonomous AI Database's managed MCP Server and OpenAI Codex's agent capabilities creates a secure, governed path for AI agents to work with enterprise data — without compromising on security or requiring complex infrastructure.

---

*Have questions or want to share how you're using MCP with Oracle databases? Join the conversation in the Oracle AI Developers Community.*

---

**#OracleAIDatabase #OCI #AutonomousAIDatabase #AI #MCP #OpenAICodex #EnterpriseAI #AIAgents**
