# Skill 34 — Converged Database Architecture (Oracle AI Database 26ai)

> **Capability:** Tell a genuinely converged database apart from a system that merely stores several data models, using five checkable guarantees — then design multi-model schemas, transactions, and queries that actually earn the label.

---

## What It Is

"Multi-model" describes what a database can *store* — relational rows, JSON documents, vectors, graphs, spatial data, side by side in one product. "Converged" describes whether the *guarantees* span those models: one transaction manager, one query optimizer, one consistency model, and one security/governance domain covering all of them, exposed through the access surfaces developers already use (SQL, a document API, REST).

The distinction matters most for RAG pipelines and AI agents. Those workloads need retrieval that is simultaneously fresh (the embedding reflects the row as it is right now), governed (permissions apply inside retrieval, not bolted on afterward), and joined (the real question is rarely "similar documents" alone — it's "similar documents for this patient, on this care team, with an open referral"). A polyglot stack — operational store + vector index + search index + graph engine, wired together with change-data-capture — turns each of those three properties into its own synchronization pipeline, and every pipeline is a place where an agent can act on stale or unauthorized data.

Oracle AI Database 26ai is used as the reference engine below because it natively combines a relational engine, a MongoDB-compatible document API (via JSON-Relational Duality Views), `VECTOR` columns and ANN indexes, and SQL/PGQ property graphs under one optimizer.

## The Five Tests

A product passes "converged," not just "multi-model," when all five hold — not some:

| # | Test | What passing looks like | What failing looks like |
|---|---|---|---|
| 1 | One transaction boundary | A single `COMMIT`/`ROLLBACK` covers a relational write, a document write, and a vector update at once | Each store commits independently; a partial failure needs application-level compensation logic |
| 2 | One optimizer | `EXPLAIN PLAN` over a statement spanning graph + JSON + vector + relational returns **one** plan tree | The "join" is really an application loop calling several service APIs and merging results in code |
| 3 | One consistency model | A write through any API is immediately visible to a read through any other API | A search or vector index lags the source table via change streams, with a documented eventual-consistency window |
| 4 | One governance domain | The same grants, row-level policies, and audit trail cover every access path | Access control is enforced once per service, and re-implemented (or forgotten) in the others |
| 5 | Shared access surfaces | SQL, document API, and REST are projections of the same rows | A unified API gateway sits in front of otherwise-separate engines |

## Converged vs. Multi-Model vs. Vector-Only

| Pattern | What it guarantees | Where it breaks down for agents |
|---|---|---|
| Converged database | All five tests above, across every model | — |
| Multi-model database | Storage for several models in one product | Guarantees often stop at the model boundary — no cross-model transaction, no single optimizer |
| Specialized vector store | Fast approximate similarity search | No live relational predicates, no transactional link back to the source of truth |

---

## Hands-On: One Transaction Across Three Models

Take a clinical-intake workflow: a structured visit record, a free-text nursing note stored as a document, and the note's embedding for later similarity search. In a converged engine, all three writes are one transaction:

```sql
-- One transaction, three models, atomic together
INSERT INTO patient_visits (patient_id, visit_id, status, chief_complaint)
VALUES (4471, 90210, 'in_progress', 'shortness of breath');

INSERT INTO visit_events (data)
VALUES (JSON('{
  "type": "nursing_note",
  "visitId": 90210,
  "note": "Pt reports SOB x2 days, no chest pain, sats 94% RA."
}'));

UPDATE case_notes
   SET note_embedding = TO_VECTOR(
         DBMS_VECTOR.EMBED_TEXT(
           credential_name => 'OCI_GENAI_CRED',
           params => JSON_OBJECT('provider' VALUE 'ocigenai', 'model' VALUE 'cohere.embed-english-v3.0'),
           content => 'Pt reports SOB x2 days, no chest pain, sats 94% RA.'
         )
       )
 WHERE visit_id = 90210;

COMMIT;   -- all three land together, or none do
```

If step two or three fails — a constraint violation, a network blip calling the embedding model — the `ROLLBACK` undoes the visit record too. Nothing needs a saga, an outbox table, or a retry queue to stay consistent; the transaction manager already guarantees it.

## Hands-On: One Optimizer Across Graph + Vector + JSON + Relational

A single statement can walk a referral graph, rank the reachable patients' case notes by similarity, and join back to structured visit data — costed as one plan, not stitched together in application code:

```sql
WITH reachable AS (
  SELECT DISTINCT p2.patient_id
  FROM GRAPH_TABLE (care_team_graph
    MATCH (p1 IS patients) -[IS referred_to]->{1,3} (p2 IS patients)
    WHERE p1.patient_id = 4471
    COLUMNS (p2.patient_id))
  p2
)
SELECT v.visit_id, v.chief_complaint
FROM   reachable r
JOIN   patient_visits v ON v.patient_id = r.patient_id
JOIN   case_notes    cn ON cn.visit_id  = v.visit_id
WHERE  JSON_EXISTS(v.flags, '$.readmission_risk')
ORDER  BY VECTOR_DISTANCE(
             cn.note_embedding,
             TO_VECTOR('[...]', 1024, FLOAT32),
             COSINE)
FETCH APPROXIMATE FIRST 10 ROWS ONLY WITH TARGET ACCURACY 90;
```

```sql
EXPLAIN PLAN FOR <statement above>;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

Check the plan for one signal specifically: the `GRAPH_TABLE` row source, the JSON predicate, and the vector ranking should all appear inside a **single** plan tree — no federation seam, no separate cost model per model. That's the operational meaning of "one optimizer," and it's checkable on any statement you write, not just this one.

## Hands-On: One Consistency Model — Read-Your-Writes Across APIs

Write through the document API, read the same row through SQL in the same request — no polling, no "index not updated yet" retry loop:

```javascript
// Write via the Mongo-compatible document API
const notes = db.getCollection('visit_events');
notes.insertOne({ type: 'vitals_update', visitId: 90210, spo2: 96 });

// Immediately read it back via SQL — same engine, no replication lag
const check = db.aggregate([
  { $sql: "SELECT COUNT(*) AS n FROM visit_events e WHERE e.data.visitId.number() = 90210 AND e.data.spo2.number() = 96" }
]).toArray();
// check[0].n === 1, deterministically — not "usually, within a few seconds"
```

Contrast this with a stack where the vector or search index is fed by a change stream: a query issued milliseconds after the write can miss it, and an agent reading that index has no way to know whether it's current.

## One Governance Domain

Because the document, SQL, and vector paths are projections of the same rows, a single Virtual Private Database policy protects all of them — no separate access-control layer to keep in sync per API:

```sql
BEGIN
  DBMS_RLS.ADD_POLICY(
    object_schema   => 'CLINICAL',
    object_name     => 'PATIENT_VISITS',
    policy_name     => 'care_team_only',
    function_schema => 'CLINICAL',
    policy_function => 'care_team_predicate',
    statement_types => 'SELECT,INSERT,UPDATE,DELETE'
  );
END;
/
```

`care_team_predicate` runs whether the row is reached via SQL, the document API, or a REST/ORDS call against the same duality view — one policy, three surfaces, no gaps to audit for.

---

## When to Reach for This vs. a Polyglot Stack

| Scenario | Converged database | Polyglot / multi-store |
|---|---|---|
| Agent needs retrieval that's fresh, governed, *and* joined to live operational data | Fits directly — one transaction, one policy | Requires a sync pipeline per property, each a staleness risk |
| Pure standalone similarity search, no relational context needed | Overkill | A dedicated vector store is a defensible, simpler choice |
| Team already has deep operational investment in a specialized store (e.g., a mature search cluster) | Migration cost is real — weigh it | Staying put may be the pragmatic call short-term |
| Compliance requires one auditable access-control surface | Strong fit | Each store needs its own enforcement, independently verified |

## Why It Matters for RAG and Agents

An agent that reads a stale vector index doesn't fail loudly — it acts confidently on a fact that stopped being true when the index lagged the source table. The bigger the model, the more convincing the wrong answer sounds. When the agent also has write access — updating a record, triggering a workflow — a stale read stops being a UX problem and becomes an operational one. Convergence doesn't make retrieval pipelines faster; it removes the pipeline (and its staleness window) as a separate thing to reason about.

---

## References

- Rick Houlihan, ["What Is a Converged Database? Definition, Five Tests, and AI Use Cases"](https://blogs.oracle.com/developers/what-is-a-converged-database-definition-five-tests-and-ai-use-cases), Oracle Developers Blog, June 24, 2026 — source article for the five-tests framework in this skill
- Maria Colgan, ["What is a Converged Database?"](https://sqlmaria.com/2020/03/05/what-is-a-converged-database/), March 2020 — original definition
- [Oracle AI Vector Search overview](https://docs.oracle.com/en/database/oracle/oracle-database/26/vecse/overview-ai-vector-search.html)
- [Oracle Database API for MongoDB overview](https://docs.oracle.com/en/database/oracle/mongodb-api/mgapi/overview-oracle-database-api-mongodb.html)
- [JSON-Relational Duality Views overview](https://docs.oracle.com/en/database/oracle/oracle-database/26/jsnvu/overview-json-relational-duality-views.html)
- [Oracle Database Property Graph / SQL-PGQ documentation](https://docs.oracle.com/en/database/oracle/property-graph/)
- Companion proof repository: [oracle-devrel/oracle-umt-developer-hub](https://github.com/oracle-devrel/oracle-umt-developer-hub) — runnable CI-verified scripts for each of the five tests
- Related skills in this library: [12 — JSON Relational Duality Views](12_json_relational_duality_views.md), [13 — SQL/PGQ Property Graph Queries](13_sql_pgq_property_graph_queries.md), [01 — Oracle AI Vector Search](01_oracle_ai_vector_search.md)
