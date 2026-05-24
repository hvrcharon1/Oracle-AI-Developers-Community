# Skill 04: Building AI Agents with DBMS_CLOUD_AI_AGENT

**Category:** AI Agents | **Level:** Intermediate

---

## Overview

`DBMS_CLOUD_AI_AGENT` is Oracle's PL/SQL package for defining, registering, and managing AI agent tools that sit directly on top of your database objects. These tools are exposed through the Oracle Autonomous AI Database MCP Server, making them discoverable and invocable by any MCP-compatible AI client — with full database-native security.

---

## Key Concepts

- **Agent Tool**: A named, parameterised SQL query wrapped with a description that an LLM can understand and invoke
- **Tool Discovery**: MCP clients automatically discover your tools via the MCP Server's discovery endpoint
- **Parameter Binding**: Agent tools use named bind variables (`:param_name`) that the LLM maps from natural language

---

## Step-by-Step

### 1. Create a Simple Agent Tool

```sql
BEGIN
  DBMS_CLOUD_AI_AGENT.CREATE_AGENT_TOOL(
    name        => 'get_customer_orders',
    description => 'Returns all orders for a given customer ID, including order date, status, and total value.',
    query       => q'[
      SELECT o.order_id,
             o.order_date,
             o.status,
             o.total_amount
      FROM   orders o
      WHERE  o.customer_id = :customer_id
      ORDER BY o.order_date DESC
    ]',
    parameters  => JSON_OBJECT(
      'customer_id' VALUE JSON_OBJECT(
        'type'        VALUE 'number',
        'description' VALUE 'The unique numeric identifier of the customer'
      )
    )
  );
END;
/
```

### 2. Create a Multi-Parameter Tool

```sql
BEGIN
  DBMS_CLOUD_AI_AGENT.CREATE_AGENT_TOOL(
    name        => 'get_revenue_by_region',
    description => 'Returns total revenue and order count grouped by region for a specified date range.',
    query       => q'[
      SELECT region,
             SUM(total_amount) AS total_revenue,
             COUNT(*)          AS order_count
      FROM   orders
      WHERE  order_date BETWEEN :start_date AND :end_date
      GROUP BY region
      ORDER BY total_revenue DESC
    ]',
    parameters  => JSON_OBJECT(
      'start_date' VALUE JSON_OBJECT('type' VALUE 'string', 'description' VALUE 'Start date YYYY-MM-DD'),
      'end_date'   VALUE JSON_OBJECT('type' VALUE 'string', 'description' VALUE 'End date YYYY-MM-DD')
    )
  );
END;
/
```

### 3. List All Registered Tools

```sql
SELECT tool_name, description
FROM   user_cloud_ai_agent_tools
ORDER BY tool_name;
```

### 4. Update an Existing Tool

```sql
BEGIN
  DBMS_CLOUD_AI_AGENT.UPDATE_AGENT_TOOL(
    name        => 'get_customer_orders',
    description => 'Returns all orders for a customer, including order date, status, total value, and shipping address.'
  );
END;
/
```

### 5. Drop a Tool

```sql
BEGIN
  DBMS_CLOUD_AI_AGENT.DROP_AGENT_TOOL(name => 'get_customer_orders');
END;
/
```

---

## Design Guidelines

- Write **clear, specific descriptions** — the LLM uses the description to decide when to invoke a tool
- Use **bind variables** for all user-supplied values — never interpolate strings into the query
- Keep tools **focused on a single data concern** — prefer many small tools over one large, complex one
- Include **units and formats** in parameter descriptions (e.g., "date in YYYY-MM-DD format")
- Test tools with `DBMS_CLOUD_AI_AGENT.RUN_AGENT_TOOL` before exposing them via MCP

---

## Related Skills

- [Skill 03: MCP Server Setup](03_mcp_server_setup_autonomous_ai_database.md)
- [Skill 10: Agentic Workflows with Oracle AI Database](10_agentic_workflows_oracle_ai_database.md)

**#AIAgents #OracleAI #DBMS_CLOUD_AI_AGENT #MCP #EnterpriseAI**
