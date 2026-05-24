# Skill 10: Agentic Workflows with Oracle AI Database

**Category:** AI Agents | Architecture | **Level:** Advanced

---

## Overview

Agentic workflows go beyond single prompt-response cycles. An AI agent autonomously plans, executes multiple steps, uses tools, evaluates results, and iterates — all to complete a higher-level goal. Oracle Autonomous AI Database provides the ideal foundation for enterprise agentic workflows: persistent state, secure tool execution via MCP, vector memory, and transactional integrity.

---

## Agentic Workflow Patterns

### Pattern 1: Plan → Execute → Verify

```
User Goal: "Generate the monthly executive sales report and email it."

Agent Plan:
  1. [Tool: get_revenue_by_region] → Fetch Q1 revenue data
  2. [Tool: get_top_customers]     → Fetch top 10 customers
  3. [Tool: get_product_summary]   → Fetch product performance
  4. [Code]                        → Assemble HTML report
  5. [Tool: send_email]            → Send to distribution list
  6. [Tool: log_report_sent]       → Record in audit table
```

### Pattern 2: Retrieval-Augmented Agent (RAG + Tools)

```
User: "Which of our enterprise customers are at risk of churn based on recent activity?"

Agent:
  1. Vector search knowledge base for "churn indicators" definitions
  2. Query Oracle for customers with declining order frequency
  3. Query for open support tickets > 14 days unresolved
  4. Join signals and score each customer
  5. Return ranked list with explanations
```

### Pattern 3: Self-Correcting Agent

```
Agent attempts SQL → Database returns error
     │
     ▼
Agent reads error message
     │
     ▼
Agent revises query (checks schema via MCP describe_table)
     │
     ▼
Agent retries → Success
     │
     ▼
Agent stores corrected pattern in memory table
```

---

## Building an Agentic Workflow: Oracle + Python

### 1. Define Agent Memory Table

```sql
CREATE TABLE agent_memory (
  session_id    VARCHAR2(100),
  step_number   NUMBER,
  tool_name     VARCHAR2(200),
  tool_input    CLOB,
  tool_output   CLOB,
  created_at    TIMESTAMP DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_agent_memory PRIMARY KEY (session_id, step_number)
);
```

### 2. Agent Loop (Python)

```python
import anthropic
import oracledb
import json
import uuid

client = anthropic.Anthropic()
session_id = str(uuid.uuid4())

tools = [
    {
        "name": "run_oracle_query",
        "description": "Execute a SQL SELECT query against Oracle Database and return results as JSON.",
        "input_schema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "The SQL SELECT query to execute"},
                "params": {"type": "object", "description": "Optional bind parameters"}
            },
            "required": ["query"]
        }
    }
]

def run_oracle_query(query, params=None, conn=None):
    with conn.cursor() as cur:
        cur.execute(query, params or {})
        cols = [d[0] for d in cur.description]
        rows = cur.fetchall()
        return [{c: v for c, v in zip(cols, row)} for row in rows]

def log_step(conn, session_id, step, tool_name, tool_input, tool_output):
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO agent_memory VALUES (:1, :2, :3, :4, :5, SYSTIMESTAMP)",
            (session_id, step, tool_name, json.dumps(tool_input), json.dumps(tool_output))
        )
    conn.commit()

def run_agent(goal, conn):
    messages = [{"role": "user", "content": goal}]
    step = 0

    while True:
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=4096,
            tools=tools,
            messages=messages
        )

        if response.stop_reason == "end_turn":
            final = next((b.text for b in response.content if hasattr(b, 'text')), "Done.")
            print(f"Agent completed: {final}")
            break

        # Process tool calls
        tool_results = []
        for block in response.content:
            if block.type == "tool_use":
                step += 1
                result = run_oracle_query(block.input["query"], block.input.get("params"), conn)
                log_step(conn, session_id, step, block.name, block.input, result)
                tool_results.append({"type": "tool_result", "tool_use_id": block.id, "content": json.dumps(result)})

        messages.append({"role": "assistant", "content": response.content})
        messages.append({"role": "user", "content": tool_results})
```

### 3. Run the Agent

```python
conn = oracledb.connect(user="sales", password="...", dsn="...")
run_agent(
    "Find all customers who placed orders in 2024 but have not ordered in 2025. "
    "Return their names, emails, and total 2024 spend, sorted by spend descending.",
    conn
)
```

---

## Enterprise Considerations

| Concern | Recommendation |
|---|---|
| **State persistence** | Store agent memory in Oracle — survives restarts and is queryable |
| **Retry logic** | Implement exponential backoff for tool failures |
| **Cost control** | Set `max_tokens` limits and cap the number of agentic loops |
| **Auditability** | Log every tool invocation with inputs and outputs |
| **Access control** | Use read-only database users for data-retrieval agents |
| **Human-in-the-loop** | For high-stakes actions (email sends, data writes), add approval checkpoints |

---

## Related Skills

- [Skill 04: Building AI Agents with DBMS_CLOUD_AI_AGENT](04_building_ai_agents_dbms_cloud_ai_agent.md)
- [Skill 08: RAG with Oracle AI Vector Search](08_rag_oracle_ai_vector_search.md)
- [Skill 03: MCP Server Setup](03_mcp_server_setup_autonomous_ai_database.md)

**#AIAgents #AgenticAI #OracleAI #EnterpriseAI #MCP #Anthropic #Python**
