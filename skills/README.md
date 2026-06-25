# Oracle AI Developer Skills

This folder contains a curated library of **practical developer skills** for building with Oracle AI Database, OCI, MCP, and AI agents. Each skill is a self-contained guide covering a specific capability — from vector search and Select AI to core SQL/PL/SQL mastery.

---

## 🤖 AI-Powered Skills

| # | Skill | Description |
|---|---|---|
| 01 | [Oracle AI Vector Search](01_oracle_ai_vector_search.md) | Store, index, and query vector embeddings natively in Oracle Database |
| 02 | [Select AI — Natural Language to SQL](02_select_ai_natural_language_to_sql.md) | Query Oracle Database using plain English with Select AI |
| 03 | [MCP Server Setup — Autonomous AI Database](03_mcp_server_setup_autonomous_ai_database.md) | Enable and configure the built-in MCP Server on Oracle Autonomous AI Database |
| 04 | [Building AI Agents with DBMS_CLOUD_AI_AGENT](04_building_ai_agents_dbms_cloud_ai_agent.md) | Create and register custom agent tools using Oracle's agent PL/SQL package |
| 05 | [Claude Code + Oracle MCP Integration](05_claude_code_oracle_mcp_integration.md) | Connect Claude Code to Oracle databases via MCP for agentic coding workflows |
| 06 | [Oracle APEX AI Assistant](06_oracle_apex_ai_assistant.md) | Use APEX AI Assistant to generate low-code apps and SQL with natural language |
| 07 | [OCI Generative AI Service — Getting Started](07_oci_generative_ai_service.md) | Call OCI-hosted LLMs (Cohere, Meta Llama, etc.) from your applications |
| 08 | [RAG with Oracle AI Vector Search](08_rag_oracle_ai_vector_search.md) | Build Retrieval-Augmented Generation pipelines using Oracle as the vector store |
| 09 | [OAuth 2.0 Authentication for Oracle MCP](09_oauth2_authentication_oracle_mcp.md) | Secure MCP Server access with OCI IAM OAuth 2.0 client credentials |
| 10 | [Agentic Workflows with Oracle AI Database](10_agentic_workflows_oracle_ai_database.md) | Design and orchestrate multi-step AI agent workflows backed by Oracle data |
| 11 | [Oracle AI Database 26ai Unified Memory](11_oracle_ai_database_26ai_unified_memory.md) | Leverage Oracle AI Database 26ai's unified memory architecture for AI workloads |
| 12 | [JSON Relational Duality Views](12_json_relational_duality_views.md) | Access the same Oracle data simultaneously as JSON documents and SQL rows — zero duplication |
| 13 | [SQL/PGQ Property Graph Queries](13_sql_pgq_property_graph_queries.md) | Run ISO-standard graph pattern matching (fraud detection, network analysis) inside Oracle SQL |
| 14 | [Oracle Machine Learning (OML) AutoML](14_oracle_machine_learning_automl.md) | Train, evaluate, and deploy ML models entirely in-database — no Python server required |
| 15 | [PL/SQL Toolbox for AI Agents](15_plsql_toolbox_for_ai_agents.md) | Build robust, type-safe, observable function tools in PL/SQL for AI agent frameworks |
| 16 | [Blockchain Tables + AI Compliance Audit](16_blockchain_tables_ai_compliance_audit.md) | Create cryptographically tamper-evident audit trails and query them with AI |
| 23 | [DBMS_VECTOR_CHAIN: Document Chunking & Text Processing](23_dbms_vector_chain_text_processing.md) | Ingest, chunk, embed, and store documents for RAG pipelines — entirely in-database |
| 24 | [OCI Object Storage: Loading Data into Oracle AI Pipelines](24_oci_object_storage_ai_pipeline.md) | Load CSV, JSON, and Parquet files from OCI Object Storage into Oracle with DBMS_CLOUD |
| 28 | [Identity-Aware Row-Level Security for AI / MCP Agents](28_identity_aware_row_level_security_ai_agents/SKILL.md) | Propagate OAuth caller identity into the DB session via MCP, then enforce it with VPD/Row-Level Security — any provider, any model |

---

## 🛠️ Core Developer Skills

| # | Skill | Description |
|---|---|---|
| 17 | [Analytical / Window Functions](17_analytical_window_functions.md) | RANK, DENSE_RANK, LAG, LEAD, running totals, moving averages, LISTAGG — the full toolkit |
| 18 | [Bulk PL/SQL: BULK COLLECT & FORALL](18_bulk_plsql_processing.md) | Process millions of rows with 10×–100× less context-switching overhead |
| 19 | [Table Partitioning Strategies](19_table_partitioning_strategies.md) | Range, List, Interval, and Composite partitioning for large table management |
| 20 | [Index Mastery](20_index_mastery.md) | B-tree, function-based, composite, and invisible indexes — choose and test the right one |
| 21 | [Advanced SQL: CTE, PIVOT, MERGE, CONNECT BY](21_advanced_sql_cte_pivot_merge.md) | Hierarchical queries, dynamic cross-tabs, upserts, and spreadsheet-style calculations |
| 22 | [PL/SQL Error Handling & Debugging](22_plsql_error_handling_debugging.md) | Exception framework, call stack capture, autonomous-transaction error logger |
| 25 | [Reading EXPLAIN PLAN & SQL Monitoring](25_explain_plan_sql_monitoring.md) | Diagnose slow queries using execution plans, DISPLAY_CURSOR, and SQL Monitor |
| 26 | [Dynamic SQL: EXECUTE IMMEDIATE & DBMS_SQL](26_dynamic_sql_execute_immediate.md) | Build runtime SQL safely — bind variables, injection prevention, and DBMS_SQL for unknown schemas |
| 27 | [Materialized Views & Query Rewrite](27_materialized_views_query_rewrite.md) | Pre-compute aggregations and joins; let Oracle rewrite queries transparently for 10×–1000× speedups |

---

## 📝 Attribution

**Skill 28 — Identity-Aware Row-Level Security for AI / MCP Agents** is adapted from the article
**["Who is using your Oracle data (AI!), and how to secure it!"](https://www.thatjeffsmith.com/archive/2026/05/who-is-using-your-oracle-data-ai-and-how-to-secure-it/)**
by **Jeff Smith** ([@thatjeffsmith](https://twitter.com/thatjeffsmith)), Oracle Distinguished Product Manager, published May 28, 2026.

The original technique — propagating OAuth identity automatically into `SYS_CONTEXT` via an OCI Database Tools MCP Server, reading it with `CLIENTCONTEXT.OAUTH_SUB`, and enforcing data access rules at the database layer using `DBMS_RLS` (Virtual Private Database) — was first demonstrated by Jeff Smith on his blog [ThatJeffSmith.com](https://www.thatjeffsmith.com). The `who` diagnostic tool concept also originates from that article. All SQL examples and architectural patterns in Skill 28 are adapted from or directly inspired by his original work.

---

*Skills are maintained by the Oracle AI Developers Community. Contributions welcome — see [CONTRIBUTING.md](../CONTRIBUTING.md).*
