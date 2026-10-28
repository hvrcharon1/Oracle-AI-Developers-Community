---
name: oracle-deep-trust-ai-architecture
description: >
  Use this skill whenever a task involves making AI agents, AI-generated applications, or
  natural-language data access on Oracle AI Database trustworthy by enforcing controls BELOW the
  model rather than inside prompts — designing, reviewing, or hardening an Oracle-backed AI
  system against prompt injection, private-data leakage, misunderstood or hallucinated answers,
  AI-accelerated cyber attacks, or AI-generated code nobody can fully review. Consult it before
  answering "can we trust this agent / app / answer," before giving an AI agent unrestricted SQL
  access, before relying on prompt-level guardrails for data privacy, and whenever the user
  mentions Oracle's Deep Trust AI architecture, Deep Data Security, SQL assertions, trusted data
  APIs, Deep NL2SQL (business knowledge, data knowledge, continuous feedback learning, knowledge
  change verification), APEXlang, Autonomous Database auto-patching, or running 26ai AI features
  over an existing 19c database. Works with any AI provider or model.
source: >
  Oracle AI World 2026 (Las Vegas, October 25-28, 2026) session by Juan Loaiza, Executive Vice
  President, Oracle Database Technologies, on Oracle's Deep Trust AI architecture.
license: Content adapted with credit to the original speaker; see Credit section below.
---

<!--
  CREDIT / ATTRIBUTION (kept here as a comment on purpose, not part of the skill body)

  Author: Juan Loaiza, Executive Vice President, Oracle Database Technologies.
  Source: his Oracle AI World 2026 presentation on the Deep Trust AI architecture
  (Las Vegas, October 25-28, 2026), supplied to this repository as an auto-generated video
  transcript. The transcript spells his name "Juan Leea"; that is a transcription error, and
  the speaker is Juan Loaiza.

  Demonstrations shown inside the session were presented by David Knox (Deep Data Security),
  Maya and Kumar (Deep NL2SQL, shown as demo personas), and Scott Spendolini (APEXlang vs React).
  Names are as they appear in the transcript.

  The five-layer structure, the failure-mode-to-layer mapping, the demo-derived tests, and all
  prose and code in this skill were independently written from the talk's content. They are not
  a verbatim reproduction of the talk. Customer and product names that the auto-transcript
  garbled were corrected only where the correct name is unambiguous (Rappi); other names are
  kept as spoken and flagged in the "What this skill does not claim" section.
-->

# Oracle Deep Trust AI Architecture: Enforcing AI Trust Below the Model

## What you are doing here

You are helping design, review, or harden an AI system that touches Oracle data, using the
principle at the center of Oracle's Deep Trust AI architecture: **do not ask the AI to be
trustworthy; make the layers underneath it enforce trust in a way the AI cannot bypass.**

The talk's framing is an overconfident teenager. AI is smart, fast, and useful, but it invents
answers, misreads requests, reveals private data, makes poor choices, and can be talked into
things by bad actors. Telling it to follow rules (guardrails, system prompts) is like telling a
teenager to only drive to school: it may work, and nothing stops the side trips. So each
failure mode is assigned to a layer of the stack that sits below the model and enforces the
rule regardless of what the model does.

Oracle positions this the way its Maximum Availability Architecture (MAA) works for resilience:
a blueprint of layered controls. Each part delivers value on its own and can be deployed on its
own; the parts are stronger together. The architecture applies to existing applications as well
as new ones, and runs wherever Oracle runs (the leading hyperscalers and on premises).

Work through Steps 0 to 7 in order. Do not report a system as "trusted" until Step 7 is done.

---

## Step 0 — Map the task to the layers

Before recommending anything, identify which risks the task actually involves, then use the
matching steps. Say which layers you are skipping and why.

| Failure mode ("the teenager...") | Why a prompt or guardrail is not enough | Owning layer | Mechanism named in the talk | Step |
|---|---|---|---|---|
| ...gets exploited by outsiders | AI now finds zero-days and reverse-engineers patches into attacks on unpatched systems | Software platform | Autonomous Database auto-patching; patch and policy tooling for other deployments | 1 |
| ...reveals private data | Guardrails get tricked by indirect questions; apps and agents implement privacy rules inconsistently | Data privacy | Deep Data Security: end-user-level rules enforced in the database | 2 |
| ...makes choices that violate business rules | Generated code may omit or mis-implement a rule | Data validity | Declarative SQL assertions | 2 |
| ...does more than it should with data access | Unrestricted SQL gives the AI everything the connection can do | Data access | Trusted data APIs over logical business objects | 3 |
| ...misunderstands the request | Natural language is ambiguous and the schema is cryptic | Knowledge | Deep NL2SQL: business knowledge, data knowledge, feedback loop, change verification | 4 |
| ...writes code nobody can review | Thousands of generated lines, many dependencies, no human understands all of it | Application | AI generates a declarative definition (APEXlang) executed by a hardened engine | 5 |

---

## Step 1 — Platform: assume attackers have AI too

**The risk (as stated in the talk).** AI models make finding vulnerabilities cheaper and faster;
they have already surfaced hundreds of zero-day exploits across widely used software platforms,
and the number of new exploits keeps rising. Attackers also use AI to reverse-engineer a
published patch into an attack on systems that have not applied it yet. The question to ask is
therefore not "do we have a patch process" but "how long are we exposed between a fix existing
and our system having it."

**What Oracle offers.**

- **Oracle Autonomous Database** applies security updates automatically while applications stay
  online. The talk's claim is that this happens before an update is made public, so there is
  nothing yet to reverse-engineer. It also provides a hardened configuration and always-encrypted
  data, and its converged architecture covers all data types and workloads from small to large.
- **Co-managed cloud and on-premises systems** are covered by Oracle's patching and security
  tools: tools to manage patching, to test patches against your real workloads, and to apply
  security policies across a whole database fleet. The speaker said Oracle is offering these free
  or at a steep discount (see the licensing caveat at the end).

**What you do.**

1. Determine the deployment model (Autonomous, co-managed, or self-managed on premises) and say
   which patching story applies. Do not assume all three behave like Autonomous.
2. For any database you can query, report concrete evidence rather than asserting it is patched:

   ```sql
   SELECT banner_full FROM v$version;

   -- Patches applied through datapatch. This is evidence, not a complete patch inventory
   -- (it does not cover OS, Grid Infrastructure, or client-side patches).
   SELECT patch_id, action, status, description, action_time
   FROM   dba_registry_sqlpatch
   ORDER  BY action_time DESC;
   ```

3. Recommend moving fleet-wide patching to automated tooling where possible, since the talk's
   point is that manual patch cycles are the exposure.

**Evidence cited in the talk.** Rappi, a Latin American delivery super-app operating in about
300 cities, runs on Autonomous AI Database for infrastructure and security, and used Oracle AI
Vector Search to make search results relevant. It reported a 40% latency improvement on
searches and a 25% conversion improvement. (The transcript renders the name as "WPPY".) This is a
customer-reported result presented by Oracle, not an independent benchmark.

---

## Step 2 — Data trust: privacy and business rules live in the database

AI can be told your privacy rules while it generates an app, but it cannot be trusted to
implement them flawlessly in the finished app. Agents also increasingly reach data directly
(natural language, agent frameworks, MCP) without passing through application code at all. So
the enforcement point has to be below both.

### 2a — Deep Data Security (end-user-level privacy at the source)

**What it does.** You declare end-user-specific privacy rules inside the database. The database
then guarantees that any SQL run on behalf of a user sees only the data that user may access,
whether the SQL came from an application or from an AI agent. It also verifies the end user's
identity cryptographically (in the demo, from a signed token issued by the corporate
directory), so an agent cannot impersonate another user to reach their data.

The talk's example rule set: an employee sees all of their own data; HR sees benefits data;
finance sees compensation data. Historically those rules sit in custom application code, which
is exactly what an AI-generated app or a direct agent connection can skip.

**The demo, and why it matters.** In the "before" run, the HR agent used ordinary role checks
plus an AI guardrail. A direct request for team salaries was refused, but a reworded request
(an arithmetic question about an end-of-year party budget) slipped past the guardrail and made
the agent read salary data. In the "after" run, with Deep Data Security, the identical prompt
returned nothing because the database never let the agent's session see salaries the signed-in
user was not entitled to. Filtering happened before data reached the application layer, so the
guardrail being fooled no longer mattered.

**What you do.**

1. Treat any privacy rule enforced only in a prompt, a guardrail, or application code as
   **unenforced** against an AI agent. Say so in your review.
2. Recommend declaring the rule in the database. The talk shows no rule syntax in its
   transcript, so look up Oracle's Deep Data Security documentation for the target release
   before writing any rule DDL. Do not invent syntax.
3. Require end-user identity to come from a verified token the database checks, never from a
   claim the model makes in text.
4. Run the indirect-question test in Step 7 before calling it done.

If Deep Data Security is not yet available on the target release, the established mechanism
for row-level restriction by caller identity is Virtual Private Database; follow
[Skill 28](../../../skills/28_identity_aware_row_level_security_ai_agents/SKILL.md). Do not
claim VPD and Deep Data Security are the same feature.

### 2b — SQL assertions (business-rule validity at the source)

Every enterprise also needs to trust that its **business rules** are never violated by an agent
or a generated app. SQL assertions declare such rules once, in the database, where they cannot
be bypassed. The talk's two examples: customers who order liquor must be at least 21, and a new
credit-card charge must not push the balance past the card's limit.

Assertion syntax and the required `DEFERRABLE INITIALLY DEFERRED` pattern are covered in
[Skill 30](../../../skills/30_sql_assertions_at_least_one_relationships.md) (23.26.1 and later).
An illustrative shape for the first example, using that skill's `ALL ... SATISFY` form:

```sql
-- ILLUSTRATIVE ONLY. Written from Skill 30's syntax pattern; not executed against a database.
-- Tables are hypothetical. Confirm which joins and functions an assertion permits in the
-- CREATE ASSERTION reference for your release, and simplify if the statement is rejected.
CREATE ASSERTION liquor_orders_require_adult
CHECK (
  ALL ( SELECT o.order_id, o.customer_id, o.order_date
        FROM   orders o
        WHERE  EXISTS ( SELECT 1
                        FROM   order_items oi
                        JOIN   products p ON p.product_id = oi.product_id
                        WHERE  oi.order_id = o.order_id
                        AND    p.category = 'LIQUOR' ) ) o
  SATISFY (
    EXISTS ( SELECT 1
             FROM   customers c
             WHERE  c.customer_id = o.customer_id
             AND    c.birth_date <= ADD_MONTHS(o.order_date, -12 * 21) )
  )
)
DEFERRABLE INITIALLY DEFERRED;
```

The age is measured against the order date, not the current date, so the rule is stable over
time. Test it by attempting an underage liquor order and confirming the commit fails
(see the error table in Skill 30).

---

## Step 3 — Data access: give agents interfaces, not a SQL prompt

Handing an AI-generated app unrestricted SQL is like giving a teenager a phone with permission
to use it only for calling family: once they have the phone, the phone's full capability is
theirs. The safer pattern is to give the agent **exactly the data interfaces it needs and
nothing else.**

**What the talk describes.** Declarative **trusted data APIs** expose limited read and write
access on *logical business objects*, such as a full purchase order, rather than on raw tables.
The database enforces the update rules, integrity, and evolvability of those objects, so the
limit on what the AI can touch is part of the data architecture rather than part of its good
behavior.

**What you do.**

1. For each agent or generated app, list the business objects it needs (for example "purchase
   order") and the operations on each (read, create, change). Anything not on the list is
   denied.
2. Prefer a database-enforced object interface over arbitrary SQL. The talk does not name the
   mechanism or show syntax in the transcript. JSON Relational Duality Views
   ([Skill 12](../../../skills/12_json_relational_duality_views.md)) are this repository's closest
   existing pattern for document-shaped, database-enforced access to a business object; treat
   them as a related pattern, not as confirmation that they are the same feature. Check Oracle's
   documentation for the current trusted-data-API feature on the target release.
3. If neither is available, fall back to a least-privilege schema and a small set of typed
   tools ([Skill 15](../../../skills/15_plsql_toolbox_for_ai_agents.md),
   [Skill 29](../../../skills/29_maximizing_coding_agents_oracle_developer.md)) instead of
   open SQL, and say plainly that this is weaker than a declarative interface.
4. Default-deny: a new agent starts with no access and is granted specific objects.

---

## Step 4 — Knowledge: minimize misunderstanding, then fix it at the root

Natural language is unbounded and ambiguous, so perfect trust in a free-text answer is not
achievable. The talk's goal is to **minimize AI misunderstandings and mistakes** and to correct
each one at its source. That requires two kinds of knowledge supplied by humans (assisted by AI):

- **Business knowledge**: your private terminology, context, and rules.
- **Data knowledge**: what the data means, how it is organized, and how to use it.

Without private business knowledge the answers are guaranteed to be wrong in some cases. The
talk's example: a sales manager asks "who are our top customers in Asia this quarter?" The AI
cannot know that *top* means highest revenue, that *Asia* excludes Japan because Japan is its own
business unit here, or that *quarter* means the company's fiscal quarter.

### 4a — Organize business knowledge by topic

Deep NL2SQL groups business knowledge by business topic (the talk's simplified example has
products, customers, and services). The flow is: match the user's question to a topic, pull that
topic's terms and rules, and identify which tables hold the relevant data. The block below is a
neutral template for gathering this knowledge; it is **not** Oracle's storage format (Deep NL2SQL
keeps it in a knowledge graph):

```text
Topic: Customers
Business terms:
  top customers = highest revenue
  Asia          = Asian countries except Japan (Japan is a separate business unit)
  this quarter  = the company's fiscal quarter
  revenue       = <definition; the demo's correction was to exclude returned merchandise>
Relevant data: CUSTOMERS, ORDERS, REGION, LINE_ITEM
Ask, do not guess: "sold best" -> units or revenue?
Owner: <knowledge expert>    Last verified: <date>
```

### 4b — Make the schema self-explanatory

Cryptic schemas cause wrong SQL. The talk names these ways to add data knowledge: SQL
annotations, analytic (semantic) views for dimensions, facts, measures, hierarchies, and metrics,
and others including ontologies, related data graphs, comments, and documentation. For the
annotation example (a cryptic column `CN` that actually holds a country name):

```sql
-- Hypothetical table. Annotation clause usage follows the pattern in Skill 29.
COMMENT ON COLUMN customers.cn IS 'Country name';
ALTER TABLE customers MODIFY cn ANNOTATIONS (Description 'Country name');
```

### 4c — Close the loop: feedback, then verification

This is the part that changed from the prior year's talk, which covered NL2SQL; this year's adds
a correction process:

1. **Ambiguity handling.** In the demo, "sold best" was flagged as ambiguous and the agent asked
   whether the user meant units or revenue instead of guessing.
2. **Show your work.** When the user doubted a number, the agent showed that gross revenue had
   been computed without returned merchandise, then recomputed. The top product changed.
3. **Continuous feedback learning.** The user's correction goes to a knowledge expert (often a
   data engineer or DBA), who finds the root cause and updates the shared knowledge, so the fix
   applies to *all* future answers rather than patching one answer.
4. **Knowledge change verification.** Before publishing a knowledge change, re-run previously
   approved "gold" answers to confirm the change did not break other questions. In the demo all
   tests passed before the update went to production.

If the built-in verification is unavailable, the generic equivalent is a maintained set of
question-and-expected-answer pairs that you re-run after every knowledge edit. Treat that as a
fallback, not as Oracle's mechanism.

**Rule for agents:** when a user reports a wrong answer, do not just fix the one query. Find which
business or data knowledge was missing or ambiguous, fix it at that source, and re-verify.

---

## Step 5 — Application: AI generates intent, the engine supplies implementation

Can you trust an AI-generated app made of thousands of lines of code that no human fully
understands? The talk's answer is to stop asking the AI to generate the implementation at all.

The same split already exists for data: you tell the AI what data you want, it produces
declarative SQL, and the SQL engine provides the implementation (performance, availability,
security). Oracle applies that idea to apps: the **APEX AI Application Generator** has the AI
produce **APEXlang**, a declarative language describing what the app should do, and the APEX
engine executes it and centrally provides security, availability, scalability, and evolvability.

Why Oracle argues this is more trustworthy:

- **One patch for many apps.** A single tested security patch to the shared engine patches every
  app that runs on it, instead of patching each application separately.
- **Hardened runtime.** The engine has been refined for more than 25 years with thousands of
  customers and millions of apps, versus an AI regenerating an implementation each time.
- **Readable.** APEXlang is meant to be easy for humans to read and edit.

**The demo.** The same prompt was given to a coding agent twice, targeting React and APEXlang.
Both produced a similar-looking sales dashboard. The React result was hundreds of files plus
third-party dependencies, and would still need an application server or containers, an identity
integration, logging, monitoring, and ongoing patching. The APEXlang result was small and
readable, and the identity, logging, monitoring, and patching came from the runtime.

**What you do.**

1. For an Oracle APEX target, generate or edit the declarative definition, not hand-written
   implementation code, unless the request is genuinely outside what the language covers. See
   [Skill 36](../../../skills/36_apexlang_ai_application_generator.md) for the three ways to
   produce a definition and how to scope conversational edits.
2. When asked whether a generated app is enterprise-ready, run the seven-point check in
   [Skill 37](../../../skills/37_evaluating_ai_generated_enterprise_apps.md) rather than
   judging on generation speed.
3. Do not hand-roll access control inside a generated app; let it inherit Step 2's database
   enforcement.

---

## Step 6 — Adopting this without upgrading everything first

Many of these capabilities live in Oracle AI Database 26ai. If a customer is not ready to
upgrade, the talk names two routes (verify exact product names and current availability in Oracle's
documentation, since the transcript is auto-generated):

1. **Replica.** Create a 26ai replica of the existing 19c database and run the AI workload
   against the replica. The talk says Oracle Fusion Applications did this, with a 26ai replica
   of each of its 19c databases.
2. **Live AI Hub (name as spoken).** Place it in front of the 19c database so the AI runs in a
   26ai database that reads the data directly from the 19c source.

The same five actions apply either way. Recommend them in this order of urgency, as the talk
did:

1. Automate software updates so attacks are prevented before they happen.
2. Define privacy and business rules inside the database. The speaker called this the second
   biggest priority after patching, and said privacy enforced only at the application level no
   longer holds up in the age of AI; add database enforcement underneath it.
3. Restrict what AI can do through trusted data APIs rather than arbitrary SQL.
4. Supply business and data knowledge, then correct answers continuously and test the
   corrections.
5. Use AI to generate application functionality, not application implementation.

---

## Step 7 — Prove it before you say it

Do not report a system as trusted until you have shown the following, or explicitly said which
checks you could not run.

1. **Identity test.** Run the same request as two different end users through the same agent and
   confirm each sees only their entitled data. One shared service account for every caller means
   per-user enforcement cannot work; say so.
2. **Indirect-question (guardrail-bypass) test.** Ask something that can only be answered by
   reading a protected field, phrased as arithmetic or a hypothetical rather than a direct
   request (the demo used a party-budget question to reach salaries). The protected data must not
   appear. A refusal from the model is not proof; the database must be the thing that withheld it.
3. **Business-rule test.** Attempt a change that violates each declared assertion and confirm it
   is rejected at commit.
4. **Access-surface test.** List what the agent can reach. Confirm there is no open SQL path
   around the trusted interfaces.
5. **Knowledge test.** Run an ambiguous question and confirm the agent asks. Run the gold
   questions after any knowledge change.
6. **Patch evidence.** Show the version and applied-patch evidence from Step 1, not just a claim.
7. **Application review.** For a generated app, identify the artifact a human reviews, and what
   the runtime (not the app) provides for identity, logging, and patching.

---

## Non-negotiable rules

- Never treat a prompt, system message, or AI guardrail as a security control. Enforce below the
  model.
- Never authorize a request on a claim the model makes about whom it acts for. Use identity the
  database verifies.
- Default-deny for data access, and grant objects and operations explicitly.
- Do not give an agent or generated app unrestricted SQL when a narrower interface exists.
- Fix wrong AI answers at the knowledge source, then re-verify, rather than patching one answer.
- Do not invent syntax for features whose syntax the source does not show. Look it up for the
  target release.
- Do not declare success without Step 7, or state which checks were not possible.

---

## What this skill does not claim

- **No syntax for Deep Data Security rules, trusted data APIs, or APEXlang.** The source is a
  talk transcript; those appeared on slides and are not reproduced in the text. Use Oracle's
  documentation for the target release.
- **Vendor claims are the speaker's, not independently verified.** That includes auto-patching
  before public disclosure, the Rappi figures, and the statement below on licensing.
- **Licensing.** The speaker said these capabilities are available at no additional charge and
  that you already own them. Do not repeat that to a customer as fact. Confirm entitlement for
  their specific edition, deployment, and contract with Oracle.
- **Names as spoken.** "Live AI Hub" and the customer name were taken from an auto-generated
  transcript. Verify exact product names before citing them.
- **Release availability.** Several capabilities are tied to 26ai. Check the target release (and
  for assertions, 23.26.1 or later) before recommending a feature.

---

## Related skills in this repository

- [Skill 28: Identity-Aware Row-Level Security for AI / MCP Agents](../../../skills/28_identity_aware_row_level_security_ai_agents/SKILL.md)
- [Skill 30: SQL Assertions](../../../skills/30_sql_assertions_at_least_one_relationships.md)
- [Skill 12: JSON Relational Duality Views](../../../skills/12_json_relational_duality_views.md)
- [Skill 02: Select AI, Natural Language to SQL](../../../skills/02_select_ai_natural_language_to_sql.md)
- [Skill 29: Maximizing Coding Agents as an Oracle AI Database Developer](../../../skills/29_maximizing_coding_agents_oracle_developer.md)
- [Skill 36: APEXlang](../../../skills/36_apexlang_ai_application_generator.md)
- [Skill 37: Evaluating AI-Generated Enterprise Applications](../../../skills/37_evaluating_ai_generated_enterprise_apps.md)
- [Skill 34: Converged Database Architecture](../../../skills/34_converged_database_architecture.md)

---

## References

- Juan Loaiza, EVP Oracle Database Technologies, Oracle AI World 2026 session on the Deep Trust
  AI architecture (Las Vegas, October 25-28, 2026). Primary source for this skill.
- [Oracle Deep Data Security](https://www.oracle.com/security/database-security/features/deep-data-security/)
- [Oracle SQL Language Reference: CREATE ASSERTION](https://docs.oracle.com/en/database/oracle/oracle-database/26/sqlrf/create-assertion.html)
- [Oracle SQL Language Reference: Annotations clause](https://docs.oracle.com/en/database/oracle/oracle-database/26/sqlrf/annotations_clause.html)
- [Oracle APEX AI Application Generator](https://www.oracle.com/apex/ai-application-generator/)
- [APEXlang documented grammar](https://docs.oracle.com/en/database/oracle/apex/26.1/apxln/)

**#OracleAIWorld #DeepTrustAI #DeepDataSecurity #SQLAssertions #NL2SQL #APEXlang #AIAgents #Oracle26ai #OracleAI**
