# Connecting Claude Code to Oracle Autonomous AI Database MCP Server

*AI coding agents are becoming much more powerful when they can safely connect to real enterprise systems.*

In this blog, we walk through how to connect **Claude Code** — Anthropic's agentic command-line coding tool — with the **Oracle Autonomous AI Database MCP Server**, enabling Claude Code to interact with database tools, inspect schemas, retrieve metadata, and support database workflows through the **Model Context Protocol (MCP)**.

What makes this especially compelling is that the MCP Server is a **built-in, managed feature** of Oracle Autonomous AI Database. Teams can expose database capabilities to MCP-compatible AI clients without standing up separate MCP infrastructure — while still relying on database-native security and access controls.

And unlike a chat-based AI, Claude Code operates directly in your terminal and editor, taking autonomous actions: reading files, writing code, running tests, and now — with MCP — querying and reasoning over live enterprise data as part of its agentic workflow.

---

## What Is Claude Code?

Claude Code is Anthropic's agentic CLI tool that brings Claude's capabilities directly into your development environment. It can:

- Read and write files across your project
- Execute shell commands and run tests
- Understand large codebases through contextual reasoning
- Connect to external tools and services via MCP
- Operate autonomously across multi-step tasks with minimal hand-holding

When you add an MCP Server to Claude Code's configuration, it immediately gains the ability to discover and invoke that server's tools — making it a true enterprise-aware coding agent.

---

## What Is the Model Context Protocol (MCP)?

The Model Context Protocol is an open standard that allows AI models to connect to external tools, data sources, and services in a structured, secure way. Instead of building custom integrations for every AI client and data system, MCP defines a common language for capability discovery and invocation.

When Claude Code connects to an MCP Server, it can:

- Discover what tools and resources are available
- Invoke those tools with structured inputs during agentic tasks
- Receive structured outputs it can reason over, write code against, or use to drive next steps

Oracle Autonomous AI Database ships with an MCP Server that exposes database capabilities — schema inspection, query execution, metadata retrieval — directly to MCP-compatible clients. No custom middleware required.

---

## Architecture Overview

```
Claude Code (MCP Client — runs in your terminal)
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
- **OAuth 2.0** handles authentication between Claude Code and the MCP endpoint
- **Claude Code runs locally** — your code and prompts never need to leave your machine to reach the database

---

## Step 1: Install Claude Code

Claude Code is installed as a global npm package. You need Node.js 18 or later.

```bash
npm install -g @anthropic-ai/claude-code
```

Verify the installation:

```bash
claude --version
```

On first run, Claude Code will prompt you to authenticate with your Anthropic account. Follow the OAuth flow in your browser to complete setup.

---

## Step 2: Enable the Autonomous AI Database MCP Server

The MCP Server is a managed feature of Oracle Autonomous AI Database. To enable it:

1. Navigate to your **Oracle Cloud Infrastructure (OCI) Console**
2. Open your **Autonomous Database** instance
3. Under **Database Actions**, go to **AI** → **MCP Server**
4. Toggle **Enable MCP Server** to on
5. Note the generated **MCP Endpoint URL** — you will need this when configuring Claude Code

The endpoint follows this pattern:

```
https://<your-adb-instance>.adb.<region>.oraclecloudapps.com/ords/<schema>/mcp/v1
```

Once enabled, the MCP Server automatically exposes built-in database tools including schema introspection, table metadata, and query capabilities.

---

## Step 3: Create Select AI Agent Tools with DBMS_CLOUD_AI_AGENT

Oracle's `DBMS_CLOUD_AI_AGENT` package lets you define custom agent tools on top of your database objects. These tools become discoverable by MCP clients like Claude Code.

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

You can create multiple tools covering different data domains. Each tool is automatically surfaced through the MCP Server to any connected client.

---

## Step 4: Configure Claude Code to Connect to the MCP Endpoint

Claude Code reads MCP server configuration from its settings file. Add the Oracle Autonomous AI Database MCP Server using the Claude Code CLI:

```bash
claude mcp add oracle-adb \
  --url "https://<your-adb-instance>.adb.<region>.oraclecloudapps.com/ords/<schema>/mcp/v1" \
  --auth-type oauth2 \
  --token-endpoint "https://idcs-<your-tenant>.identity.oraclecloud.com/oauth2/v1/token" \
  --client-id "<your-client-id>" \
  --client-secret "<your-client-secret>" \
  --scope "urn:opc:db:mcp"
```

Alternatively, you can edit the configuration file directly at `~/.claude/claude_code_config.json`:

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

Verify the server is reachable:

```bash
claude mcp list
```

You should see `oracle-adb` listed with a connected status. Claude Code will have already called the MCP Server's discovery endpoint and loaded all available tools.

---

## Step 5: Authenticate with OAuth

The MCP Server uses **OAuth 2.0 client credentials** flow. Register a confidential application in **OCI Identity and Access Management (IAM)**:

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

This ensures Claude Code can only access what it is explicitly permitted to see — no broader database access is granted.

---

## Step 6: Test Agent-Driven Workflows Against Enterprise Data

With Claude Code connected and authenticated, you can now ask it to work with your enterprise data as part of real coding tasks. Claude Code will autonomously discover and invoke the appropriate MCP tools as needed.

### Interactive Mode

Launch an interactive Claude Code session in your project directory:

```bash
claude
```

Then try natural language prompts:

> *"What tables are available in the database and what do they contain?"*

Claude Code will invoke the built-in schema inspection tools and give you a structured summary — without you writing a single SQL query.

> *"Show me the top 5 regions by revenue for Q1 2025."*

Claude Code will:
1. Identify the `get_sales_summary` tool
2. Map Q1 2025 to `start_date: 2025-01-01`, `end_date: 2025-03-31`
3. Call the MCP endpoint and receive structured results
4. Format and display them in your terminal

### Agentic Mode — Full Coding Workflow

This is where Claude Code truly shines. You can ask it to complete an entire task end-to-end:

> *"Write a Python script that pulls last month's top 10 products by revenue from the database and exports them to a CSV. Save it to `scripts/monthly_report.py` and make sure it runs cleanly."*

Claude Code will:
1. Query the MCP Server to understand the schema and available tools
2. Write `scripts/monthly_report.py` using the actual column names and data types
3. Run the script to verify it works
4. Fix any errors autonomously and confirm success

This is the key difference from a chat-based AI: Claude Code doesn't just generate code — it **acts**, **verifies**, and **iterates** within your actual project.

### One-Shot CLI Mode

For scripting and automation, use the `-p` flag to run a prompt non-interactively:

```bash
claude -p "Summarize the schema of the SALES schema and write the output to docs/schema-overview.md"
```

This makes Claude Code composable with CI pipelines, cron jobs, and developer toolchains.

---

## Why Claude Code + Oracle MCP Is a Powerful Combination

Claude Code's agentic nature makes it uniquely suited for this integration compared to chat-based AI tools:

| Capability | Chat-based AI | Claude Code + Oracle MCP |
|---|---|---|
| **Schema awareness** | Requires manual copy-paste | Live, automatic via MCP |
| **Code generation accuracy** | Based on training data | Grounded in actual schema |
| **Verification** | Manual testing required | Runs and fixes code autonomously |
| **Workflow integration** | Copy-paste into editor | Works directly in your project |
| **Enterprise data access** | Not available | Secure, OAuth-gated via MCP |
| **Auditability** | None | Full database-level logging |

---

## Why This Matters for Enterprise AI Development

This integration is a practical example of where AI-assisted development is headed: **not just generating code, but securely working with enterprise context, tools, and workflows — autonomously, end-to-end.**

Key advantages of this approach:

| Concern | How It's Addressed |
|---|---|
| **Security** | Database-native access controls; OAuth 2.0 authentication |
| **Infrastructure** | No separate MCP server to deploy or manage |
| **Governance** | Fine-grained tool definitions control exactly what the agent can do |
| **Auditability** | All agent tool invocations are logged at the database level |
| **Developer experience** | Claude Code works in your terminal, editor, and CI — no context switching |
| **Flexibility** | Add or modify tools without changing client configuration |

---

## Summary

Here is what we covered:

- ✅ **Installing Claude Code** — Anthropic's agentic CLI coding tool
- ✅ **Enabling** the Autonomous AI Database MCP Server — a managed, built-in capability
- ✅ **Creating Select AI Agent tools** with `DBMS_CLOUD_AI_AGENT` to expose curated database capabilities
- ✅ **Configuring Claude Code** to connect to the MCP endpoint via CLI or config file
- ✅ **Authenticating with OAuth 2.0** using OCI IAM confidential applications
- ✅ **Testing agent-driven workflows** — from interactive queries to full agentic coding tasks

The combination of Oracle Autonomous AI Database's managed MCP Server and Claude Code's agentic capabilities creates a secure, governed, and genuinely autonomous path for AI to work with enterprise data — writing real code, against real schemas, in real projects.

---

*Have questions or want to share how you're using Claude Code with Oracle databases? Join the conversation in the Oracle AI Developers Community.*

---

**#OracleAIDatabase #OCI #AutonomousAIDatabase #AI #MCP #ClaudeCode #Anthropic #EnterpriseAI #AIAgents #AICoding**
