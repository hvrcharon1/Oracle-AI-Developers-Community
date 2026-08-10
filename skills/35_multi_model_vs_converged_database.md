# Skill 35 — Multi-Model vs. Converged Database: Proving the Difference

> **Capability:** Tell a database that merely *stores* several data models apart from one where the guarantees actually *span* them — using a runnable, single-statement test instead of a vendor's "multi-model" badge — then apply the same test when evaluating any candidate engine, including strong peers like Google Spanner.

---

## What It Is

"Multi-model" has stopped being a differentiator. By DB-Engines' own labeling, nine of the world's ten most popular databases now carry the "Multi-model" tag — Oracle, MySQL, SQL Server, PostgreSQL, MongoDB, Databricks, Redis, Db2, and Cassandra all qualify; only Snowflake among the top ten does not. When nine of ten systems wear the same badge, the badge tells you nothing about what happens when you actually query across models.

"Converged" is a narrower, checkable claim: the *architectural guarantees* — one transaction boundary, one cost-based optimizer, one consistency model, one governance domain, and shared access surfaces — hold across every model the engine stores, not just within each one separately.

This isn't a marketing distinction. Lu and Holubová's peer-reviewed survey ("Multi-model Databases: A New Journey to Handle the Variety of Data," *ACM Computing Surveys* 52(3), 2019) examined roughly twenty systems — ArangoDB, OrientDB, Cosmos DB, MongoDB, Couchbase, and 2019-era Oracle among them — and found no documented cross-model transaction management in any of them, and no agreed-upon approach to optimizing a query that spans models. The survey's own bar for "multi-model" excludes a relational engine that merely stores another model's data without a cross-model query language and optimizer to go with it. As of 2019, in the academic record, convergence was an open research problem, not a shipped capability. "Converged" is that research agenda, shipped and testable.

## The Question That Actually Discriminates

Don't ask *how many models can it store*. Ask:

- Is there **one transaction** across the write to each model, or does a partial failure need application-level compensation?
- Is there **one optimizer plan**, or is the "join" really an application loop calling separate service APIs and merging results in code?
- Is there **one consistency model**, or does a search/vector index trail the source table through a change-stream sync window?
- Is there **one governance domain**, or is access control enforced once per service and re-implemented (or forgotten) in the others?
- Are there **shared access surfaces** over the same rows, or is a unified API gateway sitting in front of otherwise-separate engines?

This is the same five-test framework as [Skill 34 — Converged Database Architecture](34_converged_database_architecture.md). What this skill adds is the *verification method*: run one statement, capture one plan, and let CI assert the result — rather than taking a vendor datasheet's word for it.

## Hands-On: One Statement, One Plan, Independently Verified

The clearest way to test convergence is to build the query the label is supposed to make trivial: a relational filter, a graph hop, and a JSON document read, joined once. Extending the patient-care domain from Skill 34 — find every case note flagged for a patient reachable through a referral chain from a doctor whose current caseload exceeds a threshold:

```sql
SELECT DISTINCT jt.finding
FROM GRAPH_TABLE (care_team_graph
       MATCH (d IS doctors) -[IS referred_to]-> (p IS patients)
       WHERE d.active_caseload > 25
       COLUMNS (p.patient_id AS ref_patient_id)) g
JOIN visit_events v ON v.patient_id = g.ref_patient_id
CROSS JOIN JSON_TABLE (v.data, '$.findings[*]'
       COLUMNS (finding VARCHAR2(200) PATH '$.text')) jt;
```

One `WHERE` clause does the relational filter. `GRAPH_TABLE` (SQL/PGQ, ISO/IEC 9075-16:2023) does the referral hop. `JSON_TABLE` (SQL/JSON, standard since SQL:2016) unnests the document. Then check what the engine actually did with it:

```sql
EXPLAIN PLAN FOR <statement above>;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

The signal to look for is structural, not decorative: the graph pattern should appear lowered into ordinary row sources inside the plan tree (Oracle's own documentation describes `GRAPH_TABLE` as being internally translated into equivalent SQL), the JSON unnest should appear as a `JSONTABLE EVALUATION` step *inside the same plan*, and the cost-based optimizer should have chosen one join order across all of it — not three separately-costed sub-plans stitched together by application code. That is the operational meaning of "one optimizer," and unlike a vendor claim, it's something you can capture and assert in CI on every build, the same way the companion lab for this article does (18 assertions across 3 scripts, re-run nightly against the published dataset).

## The Architecture Scorecard

The same five tests, applied honestly across common architecture classes (vendor documentation, mid-2026):

| Architecture | One txn boundary | One optimizer | One consistency model | One governance domain | Shared surfaces, same data |
|---|---|---|---|---|---|
| **API-per-account** (Azure Cosmos DB) | partial — scoped per logical partition | per-API | account-scoped levels; per-partition reads | per account | ✗ — API fixed at account creation |
| **Extension composite** (PostgreSQL + pgvector/AGE) | ✓ — one WAL, one MVCC | partial — planner blind to extension internals; pgvector filters post-index | ✓ | ✓ | SQL only |
| **Engine + sidecar** (MongoDB + mongot) | ✓ core / ✗ search & vector | core only — search planned separately | ✗ for search — eventually consistent | partial — roles don't govern the sidecar | document API only |
| **Single-engine multi-model** (ArangoDB, single-server/OneShard) | ✓ with a documented cluster qualifier | AQL, own engine | ✓ single-instance | ✓ | AQL only |
| **Distributed single-engine multi-model** (Google Spanner) | ✓ — distributed ACID + external consistency | ✓ — one plan; GQL lowers to relational | ✓ for visibility; vector *recall* decays until reindex | partial — column-level only, **no row-level security** | SQL + GQL + vector/FTS; **no document API or duality** |
| **Converged** (Oracle AI Database 26ai) | ✓ | ✓ — graph, JSON, vector, relational in one plan | ✓ | ✓ | SQL + MongoDB-compatible API + REST |

The middle rows are the ones a "multi-model" checkbox hides. PostgreSQL with extensions shares a transaction manager but the planner can't see inside pgvector or AGE — a selective filter narrows the *result*, not the *search space*, until you're on the extension's newest index modes. MongoDB's core is genuinely ACID, but search and vector execute in `mongot`, a separate Lucene-based process fed by change streams on its own consistency timeline. Both look "multi-model" on a datasheet. Neither passes all five tests.

## Spanner: The Closest Peer — and Where It Stops

Google Spanner is the strongest challenge to "the label doesn't mean the guarantees." It genuinely passes the three hardest tests: one distributed ACID transaction across relational, graph, JSON, and vector writes; one compiler plan across them; and — unlike every engine-plus-sidecar architecture above — its full-text search index updates *inside* the same transaction and returns transactionally-consistent results, with no eventually-consistent sidecar trailing the primary.

Three specific gaps remain, worth naming precisely rather than hand-waving:

1. **The vector index is a maintenance schedule, not a live structure.** Spanner ships one vector index type — ScaNN, a centroid tree that Google's own documentation describes as optimized for the dataset at index-creation time and static afterward, so recall degrades as new vectors are inserted until you periodically rebuild it. Committed vectors are still *visible* immediately (this is recall decay, not staleness), but an agent retrieving context against a drifted index quietly gets worse matches with no error to catch. Oracle's centroid-based IVF index shares this trait when the underlying distribution shifts — the honest comparison isn't "Spanner degrades and Oracle doesn't," it's that Oracle also offers an incrementally-maintained HNSW graph index (new vectors added into the structure directly, deletions tracked via bitmaps) or an IVF index that reorganizes online while remaining available for reads and writes — a choice Spanner's single static index type doesn't offer. In fairness, Spanner's ScaNN targets far larger vector counts than a memory-resident HNSW graph, so if raw scale is the binding constraint the trade runs the other way.
2. **No document API or relational↔document duality.** Spanner's "multi-model" surface is SQL, GQL, vector, and full-text search — all over relational tables. A JSON column queried with SQL is not a document store. Google's MongoDB-compatible product, Firestore, is a *separate* database with its own storage engine.
3. **No row-level security.** Spanner's fine-grained access control stops at the column level. For an AI agent acting *as* an end user — where the row a query is allowed to touch depends on who's asking — that's exactly the control layer a converged engine needs to enforce inside the database rather than in application middleware.

None of this makes Spanner "not multi-model" — by any reasonable reading it's one of the most architecturally honest multi-model systems available. It's evidence for the article's actual thesis: convergence is a real, checkable property, argued here by a competitor's own documentation, not an Oracle-only claim.

## What This Means for a Modernization Decision

A "multi-model" checkbox on an RFP or datasheet can mean two very different things: "we can retire a separate graph database" or "we still run a separate search process with its own consistency timeline, inside the same product." The checkbox can't tell you which. The five-test scorecard can — and for an AI agent, the boundary you buy is the boundary the agent inherits. An agent retrieving context through an eventually-consistent search index is reasoning on historical data and has no way to know it. An agent whose permissions live in application code rather than the engine is one missed code path away from overreach.

---

## References

- Rick Houlihan, ["Converged Database vs. Multi-Model Database: What's the Difference?"](https://blogs.oracle.com/developers/converged-database-vs-multi-model-database-whats-the-difference), Oracle Developers Blog, July 9, 2026 — source article for the multi-model-vs-converged distinction, the DB-Engines saturation data, the ACM survey analysis, the architecture scorecard, and the Spanner comparison in this skill
- J. Lu and I. Holubová, ["Multi-model Databases: A New Journey to Handle the Variety of Data"](https://dl.acm.org/doi/10.1145/3323214), *ACM Computing Surveys* 52(3), Article 55, 2019 — the peer-reviewed survey establishing the cross-model transaction and optimization gap
- [DB-Engines Ranking](https://db-engines.com/en/ranking) and [methodology](https://db-engines.com/en/blog_post/80) — the "Multi-model" tagging criteria referenced above
- ["The power of multi-model Spanner for the agentic era"](https://cloud.google.com/blog/products/databases/the-power-of-multi-model-spanner-for-the-agentic-era), Google Cloud Blog — Spanner's own multi-model positioning
- [Vector index best practices](https://docs.cloud.google.com/spanner/docs/vector-index-best-practices) and [Fine-grained access control](https://docs.cloud.google.com/spanner/docs/fgac-about) — Google Cloud Spanner documentation cited for the ScaNN and row-level-security gaps
- Companion proof repository: [oracle-devrel/oracle-umt-developer-hub](https://github.com/oracle-devrel/oracle-umt-developer-hub), module 02 — runnable, CI-validated scripts reproducing the ACM survey's canonical multi-model challenge query in one SQL statement
- Related skills in this library: [34 — Converged Database Architecture](34_converged_database_architecture.md), [12 — JSON Relational Duality Views](12_json_relational_duality_views.md), [13 — SQL/PGQ Property Graph Queries](13_sql_pgq_property_graph_queries.md), [01 — Oracle AI Vector Search](01_oracle_ai_vector_search.md)
