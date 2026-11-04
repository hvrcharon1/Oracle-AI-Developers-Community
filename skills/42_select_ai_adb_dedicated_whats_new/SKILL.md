---
name: select-ai-adb-dedicated-whats-new
description: >
  Use this skill whenever a task involves Select AI on Autonomous AI Database on Dedicated
  Infrastructure (ADB-D), or any "move the AI to the data" design on Oracle AI Database: adding AWS
  Bedrock as an AI provider, running RAG with an in-database ONNX embedding model ("database:"
  prefix), generating synthetic test data with DBMS_CLOUD_AI.GENERATE_SYNTHETIC_DATA, teaching
  NL2SQL your schema with DBMS_CLOUD_AI.FEEDBACK, multi-turn conversations, natural-language
  property-graph questions (NL2GRAPH), metadata-aware SQL generation (comments, annotations,
  constraints), translation, document summarization, or building agents with DBMS_CLOUD_AI_AGENT.
  Also trigger when Select AI calls fail on a Dedicated instance (missing package, ACE in place but
  call times out, EXECUTE privilege errors) or when planning fleet capacity, egress, and privileges
  for AI profiles. Works with any AI provider or model.
---

<!--
  CREDIT / ATTRIBUTION (kept here as a comment on purpose, not part of the skill body)

  Based on the article "Move the AI to the Data: What's New in Select AI for Autonomous AI Database
  on Dedicated Infrastructure" by Saurabh Shah, Principal Product Manager, Oracle, published
  September 5, 2026 on the Oracle Developers Blog (a syndicated post; the original appeared on the
  Oracle Autonomous AI Database blog):
  https://blogs.oracle.com/developers/move-the-ai-to-the-data-whats-new-in-select-ai-for-autonomous-ai-database-on-dedicated-infrastructure
  Original post:
  https://blogs.oracle.com/autonomous-ai-database/move-the-ai-to-the-data-whats-new-in-select-ai-for-autonomous-ai-database-on-dedicated-infrastructure

  The framing in this skill originates from Saurabh Shah's article: the AI profile as the single unit
  of configuration; the ten capabilities (AWS Bedrock provider, in-database ONNX embeddings,
  synthetic data, feedback, conversations, NL2GRAPH, metadata-aware generation, translation,
  summarization, Select AI Agent); and the ADB-D-specific checks (release update level, egress,
  privileges, capacity). The article also points to a recorded developer coaching session and a code
  gist, linked under References; their contents are not reproduced here.
  The workflow structure, sample retail schema, SQL and PL/SQL examples, decision tables, and all
  prose in this skill were independently written and are not reproduced from the original post.
-->

# Select AI on Autonomous AI Database Dedicated (ADB-D): What's New and How to Use It

## What you are doing here

You are building generative-AI features **inside** Oracle AI Database instead of shipping data out to
an external stack. On ADB-D this works well, but several things that a managed service would handle
for you are **your** responsibility: the database release level, outbound network routes, privilege
grants, and CPU capacity. Check those first (Steps 1–3), then pick the feature (Step 5).

**One idea holds everything together:** the **AI profile** is the unit of configuration. Every
feature here is a new provider for a profile, a new attribute on a profile, or a new verb pointed at
a profile. When something does not work, look at the profile first.

Follow the steps in order. Do not report success until Step 7 is done.

---

## Step 1 — Check the release update level before anything else

On Dedicated you control maintenance of your Autonomous Container Database (ACD), so a documented
feature can simply be missing from an older one.

| Feature | Minimum noted in the source article |
|---|---|
| Select AI Agent (`DBMS_CLOUD_AI_AGENT`) | Oracle Database 19c **19.29+**, or 26ai **23.26+** |
| Other features in this skill | Not stated in the article; verify in the Select AI documentation for your release |

```sql
select banner_full from v$version;

-- Does the package even exist for this user?
select object_name, object_type
from   all_objects
where  object_name in ('DBMS_CLOUD_AI', 'DBMS_CLOUD_AI_AGENT');
```

If a documented procedure is missing, check the ACD's release update level **before** debugging
credentials or profiles. Tell the user the feature is unavailable on that release rather than
rewriting the request into something else.

---

## Step 2 — Confirm network egress (external providers only)

Providers such as AWS Bedrock live outside the database. Two separate things must both be true:

1. **Permission** — a network ACE lets the database user call the host.
2. **Route** — the VCN actually carries the traffic (NAT gateway or equivalent for a private subnet).

An ACE grants permission; it does **not** create a route. The classic false alarm: ACE present,
credential correct, call still times out because the private subnet has no NAT gateway. Check the
route table before debugging the credential.

```sql
begin
  dbms_network_acl_admin.append_host_ace(
    host => 'bedrock-runtime.<region>.amazonaws.com',   -- must match the region you call
    ace  => xs$ace_type(
              privilege_list => xs$name_list('http'),
              principal_name => '<APP_SCHEMA>',
              principal_type => xs_acl.ptype_db));
end;
/
```

OCI Generative AI needs no network ACL but still needs a network path.

---

## Step 3 — Plan privileges and ownership of profiles

The AI packages are typically enabled for `ADMIN` out of the box. For application schemas you
generally need explicit `EXECUTE` grants and per-principal network ACEs.

```sql
grant execute on dbms_cloud_ai       to <app_schema>;
grant execute on dbms_cloud_ai_agent to <app_schema>;   -- only if the schema will build agents
```

Decide early, especially on a fleet with many PDBs: are AI profiles **centrally curated** by a
platform team, or **self-service** per schema? That is a governance decision. Make it now rather
than retrofitting it later.

Credentials hold provider secrets. Create them with `DBMS_CLOUD.CREATE_CREDENTIAL`, use placeholders
in scripts and tickets, and never paste a real key into source control or a chat.

---

## Step 4 — Start from a metadata-aware profile (the cheapest accuracy win)

Before adding anything exotic, turn on the context Select AI can already use: table and column
comments, annotations, and foreign-key constraints.

```sql
begin
  dbms_cloud_ai.create_profile(
    profile_name => 'RETAIL_AI',
    attributes   => '{
      "provider": "oci",
      "model": "<model-name>",
      "credential_name": "GENAI_CRED",
      "comments": "true",
      "annotations": "true",
      "constraints": "true",
      "object_list": [
        {"owner": "RETAIL", "name": "ORDERS"},
        {"owner": "RETAIL", "name": "CUSTOMERS"},
        {"owner": "RETAIL", "name": "PRODUCTS"}]}');
end;
/

begin dbms_cloud_ai.set_profile('RETAIL_AI'); end;
/
```

Foreign keys matter most: without them the model guesses join paths from column-name similarity,
which is where hallucinated joins come from. If NL2SQL accuracy is disappointing, enable these
attributes and add missing `COMMENT ON` text **before** switching to a bigger model.

---

## Step 5 — Pick the capability

| You want to… | Capability | Go to |
|---|---|---|
| Use Amazon Bedrock models to generate SQL | AWS provider | 5a |
| RAG where chunks and prompts never leave the database | In-database ONNX embeddings | 5b |
| Realistic test data that respects constraints | Synthetic data generation | 5c |
| Make NL2SQL learn your business terms and column choices | Feedback | 5d |
| Multi-turn analyst sessions with an audit trail | Conversations | 5e |
| Ask relationship questions without writing `GRAPH_TABLE` | NL2GRAPH | 5f |
| Normalize a multilingual corpus or translate text | Translation | 5g |
| Summarize long documents without an app tier | Summarization | 5h |
| Let the database take actions, not just answer | Select AI Agent | 5i |

### 5a — AWS Bedrock as a provider

```sql
begin
  dbms_cloud.create_credential(
    credential_name => 'AWS_CRED',
    username        => '<AWS_ACCESS_KEY_ID>',
    password        => '<AWS_SECRET_ACCESS_KEY>');
end;
/

begin
  dbms_cloud_ai.create_profile(
    profile_name => 'RETAIL_BEDROCK',
    attributes   => '{
      "provider": "aws",
      "credential_name": "AWS_CRED",
      "model": "<bedrock-model-id | inference-profile-id | ARN>",
      "object_list": [{"owner": "RETAIL", "name": "ORDERS"}]}');
end;
/
```

- **`model` is mandatory for AWS** — there is no default. Supply a base model ID, an inference
  profile ID, or the corresponding ARN.
- The Bedrock runtime endpoint is **regional**; the ACE host from Step 2 must match the region.
- What leaves the database: schema metadata used to generate the SQL. The data itself stays put.

### 5b — In-database embeddings for RAG

Import an ONNX-format embedding model into the database (see the Oracle AI Vector Search
documentation for the import procedure on your release), then reference it with the `database:`
prefix in the profile:

```sql
begin
  dbms_cloud_ai.create_profile(
    profile_name => 'POLICY_RAG',
    attributes   => '{
      "provider": "oci",
      "model": "<model-name>",
      "credential_name": "GENAI_CRED",
      "vector_index_name": "POLICY_DOCS_IDX",
      "embedding_model": "database: <IMPORTED_ONNX_MODEL_NAME>"}');
end;
/
```

Why it matters: with hosted embeddings every chunk and every prompt makes a round trip to an
external API, and the chunks are the raw sensitive text. With an in-database model, chunking and
vectorization stay inside the perimeter; only the retrieved context goes to the LLM for the final
answer. The imported model is a database object, so it also takes part in backup, recovery, Data
Guard, and your privilege model.

**Capacity warning:** embedding inference consumes the ECPUs you provisioned. A large first
vectorization run competes with production workload on a rack you sized yourself. Schedule it like
any batch job. See also [Skill 23](../23_dbms_vector_chain_text_processing.md) for chunking.

### 5c — Synthetic data generation

```sql
begin
  dbms_cloud_ai.generate_synthetic_data(
    profile_name => 'RETAIL_AI',
    object_name  => 'ORDERS',
    owner_name   => 'RETAIL',
    record_count => 1000,
    user_prompt  => 'Include edge cases: zero-quantity lines, orders on month-end boundaries, '
                    || 'customers with very long names, and unusual currency amounts');
end;
/
```

- Generation is schema-aware: data types, constraints, and referential integrity shape the output,
  so rows insert instead of bouncing.
- Large multi-table runs are split into chunks and run in parallel. Per-chunk status is tracked in a
  `SYNTHETIC_DATA$<operation_id>_STATUS` table, and the operation is logged in
  `USER_LOAD_OPERATIONS`.
- Ask explicitly for pathological rows. That is what masked production clones and hand-written
  generators fail to give you, and masked clones keep residual re-identification risk.

### 5d — Feedback: persistent, retrieval-based schema learning

```sql
-- Confirm a good generated statement
exec dbms_cloud_ai.feedback(profile_name => 'RETAIL_AI', -
     sql_id => '<sql_id>', feedback_type => 'positive', operation => 'add');

-- Correct a bad one
exec dbms_cloud_ai.feedback(profile_name => 'RETAIL_AI', -
     sql_text         => 'select ai showsql total net sales last month', -
     feedback_type    => 'negative', -
     response         => 'SELECT SUM(net_amount) FROM "RETAIL"."ORDERS" WHERE ...', -
     feedback_content => 'Net sales means net_amount, not gross_amount');
```

How it works: on first use Select AI creates a vector index named
`<profile_name>_FEEDBACK_VECINDEX` (backed by a `$VECTAB` table of embedded prompts and
corrections). On a later prompt, vector search retrieves the closest matches (default
`match_limit` is 3) and injects them into the prompt as hints.

Consequences to state to users: this is **not fine-tuning** — nothing is retrained and no knowledge
leaves the database. It only applies to NL2SQL actions (`runsql`, `showsql`, `explainsql`) and needs
a profile set up for SQL generation, not RAG. Dropping the profile drops the index.

### 5e — Conversations

```sql
declare
  l_conv_id varchar2(50);
begin
  l_conv_id := dbms_cloud_ai.create_conversation(
                 attributes => '{"title": "Returns analysis"}');
  dbms_cloud_ai.set_conversation_id(l_conv_id);
end;
/

select ai show me the ten products with the most returns this month;
select ai only those shipped from the Rotterdam warehouse;
select ai chart the weekly trend for them;
```

Short-term (session) and long-term (persistent, resumable, shareable) conversations work across
`runsql`, `chat`, and `narrate`. The database holds the state, so the application no longer needs a
chat-history cache, and prompts are queryable through `USER_CLOUD_AI_CONVERSATION_PROMPTS` for
audit questions like "what did people ask the AI about our data last quarter?"

### 5f — NL2GRAPH (property graphs)

Add the property graph to the profile's `object_list`. Select AI reads the `CREATE PROPERTY GRAPH`
metadata (nodes, edges, labels, properties) and translates a relationship question into a
`GRAPH_TABLE` query. The user keeps using the same `SELECT AI` interface and does not need to know
whether the answer came from a join or a traversal. Prerequisite: a working property graph — see
[Skill 13](../13_sql_pgq_property_graph_queries.md).

### 5g — Translation

Set a `target_language` attribute on the profile (backed by OCI Language), then call
`SELECT AI TRANSLATE <text>` or `DBMS_CLOUD_AI.TRANSLATE`; it can also run inside `GENERATE` and
`NARRATE` flows. The most valuable use is **RAG normalization**: if the corpus is multilingual and
the embedding model is trained mostly on one language, translating to a single language before
embedding improves retrieval in ways that are otherwise hard to diagnose.

### 5h — Summarization

Use `SELECT AI SUMMARIZE …` for quick cases, or `DBMS_CLOUD_AI.SUMMARIZE` for control over length,
output format, and extraction level. Input can be inline text, stored text, or an Object Storage
document via `location_uri`. Large inputs are chunked (map-reduce or iterative refinement); the
article cites roughly 1 GB depending on provider. Check the package documentation for the exact
parameter names on your release.

### 5i — Select AI Agent

`DBMS_CLOUD_AI_AGENT` provides agents, tasks, tools, and teams, using the ReAct (reason + act)
pattern with short- and long-term memory, powered by the LLM in an AI profile.

```sql
begin
  dbms_cloud_ai_agent.create_agent(
    agent_name => 'RefundTriageAgent',
    attributes => '{"profile_name": "RETAIL_AI",
                    "role": "You review refund requests and prepare a recommendation for a human approver"}');
end;
/
```

- **Built-in tools:** NL2SQL, RAG, web search, notification (Slack via `DBMS_CLOUD_NOTIFICATION`,
  email via OCI SMTP).
- **Custom tools:** any PL/SQL procedure — existing business logic becomes the agent's action space
  with no adapter code. Build them carefully; see
  [Skill 15](../15_plsql_toolbox_for_ai_agents.md).
- **Teams:** a supervisor agent (`supervisor` attribute true) routes subtasks to worker agents, each
  paired with a task.
- **Human-in-the-loop:** an agent can suspend before a sensitive action (approving a refund,
  issuing a credit) and wait for a person; the wait state shows in the history views.

Look up the exact procedures for tasks, tools, and teams in the `DBMS_CLOUD_AI_AGENT` package
reference for your release. Do not guess signatures. For workflow design, see
[Skill 04](../04_building_ai_agents_dbms_cloud_ai_agent.md) and
[Skill 10](../10_agentic_workflows_oracle_ai_database.md).

Do not over-claim: this does not replace every external framework. Multi-agent systems with heavy
non-database tooling can still belong outside. It fits best when the workflow's center of gravity
is enterprise data.

---

## Step 6 — Capacity and operations (ADB-D specifics)

- In-database embedding generation and parallel synthetic-data generation consume provisioned ECPUs.
  Include them in fleet capacity planning, and run bulk jobs off-peak.
- Keep an inventory of profiles per PDB: who owns them, which credentials they use, which objects
  they expose in `object_list`.
- Treat `object_list` as a data-exposure decision: it controls which schema metadata is sent to the
  model. For row-level control on what an agent can read, see
  [Skill 28](../28_identity_aware_row_level_security_ai_agents/SKILL.md).

---

## Step 7 — Validate before reporting success

1. **Release.** The package or procedure you used exists on this ACD (Step 1 query).
2. **Network.** For external providers, one real call succeeds end to end. If it times out, check
   the route before the credential.
3. **Profile.** `SELECT AI SHOWSQL <question>` returns sensible SQL against the intended tables,
   with the metadata attributes on.
4. **Feature-specific proof:**
   - Embeddings: a RAG question returns grounded context, and no embedding calls leave the database.
   - Synthetic data: rows exist, constraints hold, and the status table shows no failed chunks.
   - Feedback: repeat the corrected prompt and confirm the correction now influences the SQL.
   - Conversations: a follow-up prompt resolves against the earlier turn, and the prompt appears in
     `USER_CLOUD_AI_CONVERSATION_PROMPTS`.
   - Agent: a run that touches a sensitive action pauses for approval as designed.
5. **Safety.** Nothing generated was executed against production data without review (use
   `showsql` first), and no secret appears in scripts or logs.
6. If any check could not be run, say so instead of declaring the feature working.

---

## Common pitfalls

| Symptom | Likely cause | Fix |
|---|---|---|
| `DBMS_CLOUD_AI_AGENT` or a procedure does not exist | ACD below the required release update | Check and patch the container database, then retry |
| Bedrock call times out although ACE and credential are right | Private subnet with no NAT gateway or route | Fix the VCN route; the ACE only grants permission |
| Bedrock profile creation complains about the model | `model` omitted — mandatory for AWS | Supply a model ID, inference profile ID, or ARN |
| ACE fails for the endpoint | ACE host region differs from the region being called | Match the regional runtime hostname |
| `ORA-` privilege error from an application schema | No `EXECUTE` grant or per-principal ACE | Grant explicitly (Step 3) |
| Feedback seems to be ignored | Profile is RAG, or action is not `runsql`/`showsql`/`explainsql` | Use an NL2SQL profile and a supported action |
| Wrong joins in generated SQL | Missing foreign keys, comments not enabled | Add FKs, enable `comments`/`annotations`/`constraints` |
| Production slows during first RAG load | In-database embedding competes for ECPUs | Schedule bulk vectorization off-peak |

---

## Non-negotiable rules

- Check the release update level first; never assume a feature exists on the target ACD.
- Remember that an ACE is permission, not a route, for every external provider.
- Never put real keys or secrets in scripts, tickets, or chat; use credentials and placeholders.
- Use `showsql` and review before running generated SQL on data that matters.
- Do not call feedback "fine-tuning" or the agent framework a replacement for every external tool.
- Do not claim a feature works until Step 7 has been run.

---

## Related skills in this repository

- [Skill 02: Select AI — Natural Language to SQL](../02_select_ai_natural_language_to_sql.md)
- [Skill 04: Building AI Agents with DBMS_CLOUD_AI_AGENT](../04_building_ai_agents_dbms_cloud_ai_agent.md)
- [Skill 08: RAG with Oracle AI Vector Search](../08_rag_oracle_ai_vector_search.md)
- [Skill 13: SQL/PGQ Property Graph Queries](../13_sql_pgq_property_graph_queries.md)
- [Skill 15: PL/SQL Toolbox for AI Agents](../15_plsql_toolbox_for_ai_agents.md)
- [Skill 23: DBMS_VECTOR_CHAIN Text Processing](../23_dbms_vector_chain_text_processing.md)
- [Skill 28: Identity-Aware Row-Level Security for AI / MCP Agents](../28_identity_aware_row_level_security_ai_agents/SKILL.md)
- [Skill 39: Integrating AI Providers with Select AI on 26ai Free](../39_ai_provider_integration_select_ai.md)

---

## References

- [Original article — Move the AI to the Data (Saurabh Shah), Oracle Developers Blog](https://blogs.oracle.com/developers/move-the-ai-to-the-data-whats-new-in-select-ai-for-autonomous-ai-database-on-dedicated-infrastructure)
- [Original post — Oracle Autonomous AI Database blog](https://blogs.oracle.com/autonomous-ai-database/move-the-ai-to-the-data-whats-new-in-select-ai-for-autonomous-ai-database-on-dedicated-infrastructure)
- [Developer coaching session recording referenced by the article](https://youtu.be/x6zIt8nf660)
- [Code gist referenced by the article](https://gist.github.com/germanviscuso/c8015cb79d7ffe8789b979a1870017bc)
- [Select AI User's Guide (26ai)](https://docs.oracle.com/en/database/oracle/oracle-database/26/selai/)
- [Build Autonomous Agents with Select AI Agent (ADB-D)](https://docs.oracle.com/en/cloud/paas/autonomous-database/dedicated/adbaa/build-autonomous-agents-with-select-ai-agent.html)
- [DBMS_CLOUD_AI Package (ADB-D)](https://docs.oracle.com/en/cloud/paas/autonomous-database/dedicated/adbaa/dbmscloudai-package.html)
- [DBMS_CLOUD_AI_AGENT Package (ADB-D)](https://docs.oracle.com/en/cloud/paas/autonomous-database/dedicated/adbaa/dbmscloudaiagent-package.html)
- [Generate SQL from Natural Language Prompts Using Select AI (ADB-D)](https://docs.oracle.com/en/cloud/paas/autonomous-database/dedicated/adbaa/generate-sql-from-natural-language-prompts-using-select-ai.html)

**#SelectAI #AutonomousAIDatabase #ADBD #Oracle26ai #NL2SQL #RAG #AIAgents #AWSBedrock #OracleAI**
