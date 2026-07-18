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
| 29 | [Maximizing Coding Agents as an Oracle AI Database Developer](29_maximizing_coding_agents_oracle_developer.md) | The complete practitioner loop: SQLcl MCP setup, schema intent via COMMENT ON + ANNOTATIONS, doc-backed prompting, /plan-first discipline, and the 6-step Oracle AI Database agent workflow |

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
| 30 | [SQL Assertions: Guaranteeing At-Least-One Relationships](30_sql_assertions_at_least_one_relationships.md) | Enforce "every parent needs at least one child" rules with 23.26.1+ assertions, plus a composite-FK fallback for earlier releases |
| 31 | [Diagnosing Hidden Characters with DUMP()](31_diagnosing_hidden_characters_with_dump.md) | Spot and fix exact-match failures (APEX Popup LOV, WHERE-clause equality, unique keys, joins) caused by invisible CR/LF or trailing whitespace |
| 32 | [Real-Time GPS Tracking in Oracle APEX with Supabase and Leaflet](32_realtime_gps_tracking_apex_supabase_leaflet.md) | Add a live-updating map to an APEX app — Oracle as system of record, Supabase Realtime for WebSocket push, Leaflet for rendering, OSRM for free road-network routing |

---

## 📝 Attribution

**Skill 28 — Identity-Aware Row-Level Security for AI / MCP Agents** is adapted from the article
**["Who is using your Oracle data (AI!), and how to secure it!"](https://www.thatjeffsmith.com/archive/2026/05/who-is-using-your-oracle-data-ai-and-how-to-secure-it/)**
by **Jeff Smith** ([@thatjeffsmith](https://twitter.com/thatjeffsmith)), Oracle Distinguished Product Manager, published May 28, 2026.

The original technique — propagating OAuth identity automatically into `SYS_CONTEXT` via an OCI Database Tools MCP Server, reading it with `CLIENTCONTEXT.OAUTH_SUB`, and enforcing data access rules at the database layer using `DBMS_RLS` (Virtual Private Database) — was first demonstrated by Jeff Smith on his blog [ThatJeffSmith.com](https://www.thatjeffsmith.com). The `who` diagnostic tool concept also originates from that article. All SQL examples and architectural patterns in Skill 28 are adapted from or directly inspired by his original work.

---

**Skill 29 — Maximizing Coding Agents as an Oracle AI Database Developer** is inspired by the article
**["Get More Out of Your Coding Agents (as an Oracle Developer)"](https://andersswanson.dev/2026/06/15/get-more-out-of-your-coding-agents-as-an-oracle-developer/)**
by **Anders Swanson** ([@anders__swanson](https://twitter.com/anders__swanson)), published June 15, 2026 on [andersswanson.dev](https://andersswanson.dev).

The foundational ideas in Skill 29 — using agent skills as token-efficient modules, connecting agents via SQLcl MCP with low-privilege schemas, embedding prose intent in `COMMENT ON` and machine-readable hints in the Oracle `ANNOTATIONS` clause, enriching context with exact Oracle documentation, using `/plan` as the primary error-correction gate, and the complete 6-step Oracle AI Database agent loop — all originate from Anders Swanson's article. The SQL examples, prompt templates, plan review checklist, and Oracle-vs-PostgreSQL comparison guide in Skill 29 are expanded from or directly inspired by his original work. Anders Swanson is a regular contributor to Oracle AI Database developer education and maintains code samples at [anders-swanson.github.io/oracle-database-code-samples](https://anders-swanson.github.io/oracle-database-code-samples/#/).

---

**Skill 30 — SQL Assertions: Guaranteeing At-Least-One Relationships** is adapted from the article
**["Guarantee at least one in one-to-many relationships in Oracle AI Database"](https://blogs.oracle.com/sql/guarantee-at-least-one-in-one-to-many-relationships-in-oracle-ai-database)**
by **Chris Saxon**, Oracle Developer Advocate for SQL ([All Things SQL](https://blogs.oracle.com/sql/authors/chris-saxon/)), published June 25, 2026.

The core technique — using the 23.26.1+ `CREATE ASSERTION ... ALL ... SATISFY` syntax with `DEFERRABLE INITIALLY DEFERRED` to guarantee a parent row has at least one child, and the composite-foreign-key fallback (with its "wrong-parent" scoping gotcha) for releases before 23.26.1 — originates from Chris Saxon's article. The SQL examples, error-code reference, and decision guide in Skill 30 are adapted from or directly inspired by his original work.

---

**Skill 31 — Diagnosing Hidden Characters with DUMP()** is based on the debugging write-up
**["Same Row. Same Value. Two Different Results. Here's Why."](https://oracleapexhub.in/same-row-same-value-two-different-results-heres-why/)**
by **Ayush**, Oracle ACE Associate ([Oracle APEX hub](https://oracleapexhub.in/author/ayushsingh290304gmail-com/)), published June 29, 2026.

The core scenario — an APEX Popup LOV silently failing to match a value that a Select List built from the same query displays without complaint, traced to hidden `CHR(13)`/`CHR(10)` bytes appended to the stored value and confirmed with `DUMP()` — originates from Ayush's article. The diagnostic query pattern, the cleanup approach, and the explanation of why rendering tolerates invisible bytes while exact-match comparisons don't are adapted from or directly inspired by his original work. All code examples, table/column names, and prose in Skill 31 were independently written and are not reproduced from the original post.

---

**Skill 32 — Real-Time GPS Tracking in Oracle APEX with Supabase and Leaflet** is based on the article
**["Real-Time GPS Tracking in Oracle APEX Using Supabase and Leaflet"](https://medium.com/@kamrulfardaus/real-time-gps-tracking-in-oracle-apex-using-supabase-and-leaflet-106bcf24c6aa)**
by **Md.Kamrul Fardaus**, published on Medium, July 4, 2026.

The core architecture — using Oracle APEX as the enterprise frontend and system of record while Supabase's Realtime WebSocket channel carries the live-position stream and Leaflet.js renders the map — along with the ID-keyed marker-registry fix for duplicate markers, the Supabase Row Level Security anonymous-write gotcha, the APEX PWA + `wakeLock` tracker pattern and its background-tracking limitation, and the free OSRM routing / coordinate-order gotcha, originates from Md.Kamrul Fardaus's article. All code examples, table/column names, and prose in Skill 32 were independently written and are not reproduced from the original post.

---

*Skills are maintained by the Oracle AI Developers Community. Contributions welcome — see [CONTRIBUTING.md](../CONTRIBUTING.md).*
