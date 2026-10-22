---
name: oracle-apex-26-2-whats-new
description: >
  Use this skill whenever a task involves Oracle APEX 26.2 (released October 2026): importing individual
  APEXlang files into an existing application (apex import -files, the VS Code "Import File" button),
  integrating Oracle Deep Data Security with APEX apps and AI Agents, choosing a Provider API (Responses,
  Interactions, Generic, Chat Completions) for Generative AI Services, setting Reasoning Effort on AI Agents
  or through APEX_AI.GENERATE / APEX_AI.CHAT (p_reasoning_effort), letting APEX Web Credentials use DBMS_CLOUD
  credentials (Resource Principal or Database Tools Identity) instead of an OCI API private key, or upgrading
  an APEX 26.1 workspace to 26.2. Also trigger on "what's new in APEX 26.2". Works with any AI provider or model.
---

<!--
  CREDIT / ATTRIBUTION (kept here as a comment on purpose, not part of the skill body)

  Based on the Oracle APEX release video "What's New in Oracle APEX 26.2" (Oracle APEX product team,
  Oracle). The transcript was supplied by Harshal Vijay Rasal. Technical detail beyond the video was
  cross-checked against Oracle's own 26.2 material, listed in References below, in particular the posts
  by Michael Hichwa (SVP, Software Development), Chaitanya Koratamaddi, Roopesh Thokala and Ashwin Rao
  (Oracle APEX Product Management), all published on the Oracle APEX blog on October 6, 2026.

  The video's topic coverage and its Sales/Finance Deep Data Security example originate from Oracle.
  All prose, tables and code examples in this skill were independently written and are not reproduced
  from the video or the blog posts. The OCI REST test request in Feature 5 follows the pattern in
  Oracle's walkthrough because it is a documented public OCI API call.

  Transcript corrections applied (the source was an auto-generated caption track):
    "Apexlang" -> APEXlang | "resource principle" -> Resource Principal | "OCIM" -> OCI IAM
    "open AI for Google Gemini" -> OpenAI (Responses API) and Google Gemini (Interactions API)
    "database tools identity" -> Database Tools Identity | "Apex" -> APEX
-->

# What's New in Oracle APEX 26.2

## What you are doing here

You are helping a developer adopt, evaluate, or upgrade to **Oracle APEX 26.2**. Oracle's release video
groups the release into five headline capabilities: file-level import for APEXlang, Oracle Deep Data
Security integration, new generative AI provider APIs, Reasoning Effort control for AI Agents, and managed
identities for secure access to OCI services. This skill gives you, for each one, what it does, the exact
steps or commands, the gotchas Oracle documents, and how to verify it. Work through the sections that apply,
and do not report a feature as working until its check in **Verify before reporting success** has actually
been run. Where this skill says a detail was not verified, look it up in the 26.2 documentation instead of
guessing.

---

## 26.2 at a glance

| # | Headline capability | What it gives you | Section |
|---|---|---|---|
| 1 | File-level import for APEXlang | Import one page or shared component into an existing app; everything else stays untouched | Feature 1 |
| 2 | Oracle Deep Data Security integration | Row, column, and value-level data access enforced in the database, including for AI Agent requests | Feature 2 |
| 3 | Responses and Interactions APIs | Pick the provider API per Generative AI Service; APEX handles endpoints and formats | Feature 3 |
| 4 | Reasoning Effort | Control how much a supported model reasons, per AI Agent or per request | Feature 4 |
| 5 | Managed identities for OCI | Web Credentials backed by Resource Principal or Database Tools Identity, no OCI API private key in APEX | Feature 5 |

**Release facts (verified against Oracle's pages in October 2026):**

| Item | Detail |
|---|---|
| General availability | October 6, 2026 for on-premises download. Oracle stated that Autonomous AI Database and OCI / multicloud availability would follow in the weeks after. Check your own environment before assuming it has been upgraded |
| Download files | Oracle re-released the download files on October 9, 2026. If you downloaded earlier, fetch the current files |
| Database support | Fully supported on Oracle Database 19c and Oracle AI Database 26ai (EE, SE2) with a valid support agreement. Oracle Database 26ai Free (developer release) works but is supported through the Free forum only |
| Support window | General availability October 2026, support ends April 2028 |
| Static resources | CDN base `https://static.oracle.com/cdn/apex/26.2.0/` |

---

## Before you start: confirm what you are working on

```sql
select version_no from apex_release;      -- expect a 26.2.x value
select banner_full from v$version;        -- Deep Data Security is an Oracle AI Database 26ai feature
```

If the instance reports a release earlier than 26.2, the features below are not available yet. Say so instead of
writing code against them. Deep Data Security is documented for Oracle AI Database 26ai; one Oracle article cites
23.26.2 for a related client integration, so confirm the exact minimum release in the Deep Data Security guide
before promising it on a given database.

---

## Feature 1: File-level import for APEXlang

**What it does.** APEX 26.1 introduced APEXlang, a human-readable application definition format stored as `.apx`
files. Until now, applying even a one-page change meant importing the whole application. In 26.2 you can edit a
single page or shared component and import only that file. Other components stay unchanged, so you can make and
test updates without redeploying the whole app.

**Prerequisites.**

- The application must already exist in the target workspace. If it does not, the import fails.
- The APEXlang export must have been produced by APEX 26.2 or later.
- For the VS Code button, the SQL Developer extension must be connected to a database that has APEX 26.2 or later.

**Import from VS Code.** Open the exported application folder, open the `.apx` file you changed, and click
**Import File** in the editor toolbar (it sits next to **Import Application**). Only the file open in the editor
is imported.

**Import with SQLcl.** The new `-files` argument takes one or more paths, separated by spaces:

```
# from the folder that contains the exported application
apex import -input orders-app/ -files orders-app/pages/p00010-orders.apx

# or change into the application folder and use relative paths; list several files in one command
cd orders-app
apex import -files pages/p00010-orders.apx shared-components/lovs/status-lov.apx
```

Paths are relative to the current working directory. When you list several files, order does not matter: SQLcl
resolves dependencies and imports them in the right sequence.

**Review before you import.** Two developers can touch the same page, one in App Builder and one in VS Code.
Before importing a local file, compare it with the application in the connected workspace and pull in the
changes others made, then validate and import the reconciled file. Oracle documents this compare-and-pull
workflow for SQL Developer for VS Code 26.3 and later. Without it, an import can overwrite a colleague's work.

**Limits to state out loud.**

| Limit | Detail |
|---|---|
| Where it runs | SQL Developer for VS Code and SQLcl only. Not available in App Builder |
| What can be imported | Pages and shared components. Themes, templates, plug-ins, and workspace components are not supported |
| New dependencies | A page that depends on a shared component not yet in the app needs that component's `.apx` imported too: first in VS Code, or in the same `-files` list in SQLcl |
| Intended use | Development and testing. For production, use your normal full-application deployment so changes are complete, tested, and recoverable |
| Working Copies | Teams that isolate work in Application Working Copies can import files repeatedly into the copy, then merge into the main app through App Builder |

**Known issue at the time of writing.** Oracle's 26.2 known-issues page lists bug 40091133: a single-file deploy
of `application.apx` can unexpectedly change the application alias and remove the current theme. The documented
workaround is a full APEXlang import to restore the theme and alias. Check the known-issues page before relying on
single-file deploys of the application definition file itself.

---

## Feature 2: Oracle Deep Data Security integration

**What it does.** Oracle Deep Data Security enforces data access inside the database at the row, column, and
individual value level. In 26.2, APEX passes the verified end-user identity (and the application identity) to the
database. The database establishes an end-user security context and applies declarative **Data Roles** and
**Data Grants** to the SQL that runs.

**The video's example, as a test scenario.**

| Actor | Reads customers | Sensitive fields | Changes a customer's credit limit |
|---|---|---|---|
| Sales | Only customers assigned to them | Hidden | Blocked |
| Finance | Per its grants | Per its grants | Allowed, because its permissions allow it |

The same rules apply when the request arrives through an **AI Agent**. SQL executed by supported APEX AI Agent
tools runs under the requesting user's security context, so asking the agent for more data does not grant more
access. The database Data Grant still decides what the request can read or change.

**How it relates to APEX authorization.** It complements rather than replaces it. APEX authorization schemes decide
what a user may see or do in the application. Deep Data Security decides what data SQL may read or change, on every
access path: reports, forms, background processes, MCP, AI Agents, and other database clients.

**Workflow.**

1. Define the Data Roles and Data Grants in the database. Use the syntax from Oracle's Deep Data Security guide for
   your release; do not guess it.
2. Enable the Deep Data Security integration for the application. The exact App Builder setting names are listed in
   the 26.2 release notes under **Security and Compliance**. They were not verified for this skill, so look them up.
3. Run the test matrix: for each role (Sales, Finance), try a report read, a hidden-column read, a form update, and
   the same request through an AI Agent tool. The agent path must give the same outcome as the direct path.

**Do not** copy row-filter logic into region `WHERE` clauses as a second source of truth. Keep policy in the database
and let APEX authorization handle UI concerns. For the earlier VPD-based pattern of propagating identity into the
database session, see [Skill 28](../skills/28_identity_aware_row_level_security_ai_agents/SKILL.md).

---

## Feature 3: Responses and Interactions APIs for Generative AI Services

**What it does.** APEX talks to AI providers over REST. Until 26.2 it used OpenAI's Chat Completions API, Gemini's
`generateContent` API, and OCI Generative AI's Generic API. 26.2 adds the **Responses API** (OpenAI and compatible
providers, plus supported OCI Generative AI models) and the **Interactions API** (Google Gemini). APEX handles the
provider-specific endpoints and request and response formats, and the agent's tool-execution flow stays the same.
This is not a new APEX REST API; it is a choice of which provider API a service uses.

**Provider API choices.**

| AI provider | Choices in APEX | Default for new services |
|---|---|---|
| OpenAI | Responses, Chat Completions | Responses |
| Generic OpenAI Compatible | Responses, Chat Completions | Responses |
| Ollama | Responses, Chat Completions | Responses |
| OCI Generative AI Service | Generic, Responses | Generic |
| Google Gemini | Interactions, legacy `generateContent` | Interactions |
| Anthropic Claude, Mistral AI, Cohere | No Provider API choice added | Unchanged |

APEX marks the Chat Completions and Gemini content-generation choices as deprecated.

**Set it.** Go to **Workspace Utilities → Generative AI Services**, create or edit a service, expand **Advanced**,
and set **Provider API**. Then **Test Connection** and save.

**Gotchas.**

- Do not append `/responses` (or `/openai/v1` for OCI) to the Base URL. APEX adds the request path itself.
- Before choosing Responses for a **Generic OpenAI Compatible** or **Ollama** service, confirm the endpoint really
  implements that API.
- **OCI Generative AI** stays on Generic by default because support varies by model. Choose Responses when the model
  and use case need it. Responses on OCI requires a **Project ID** (the OCID of an OCI Generative AI project), a
  supported model in your region, and the right IAM permissions. A Project ID does not turn on provider-hosted
  conversation history or memory in APEX.
- OCI configuration is simpler in 26.2: Compartment ID, AI Model, and **Serving Mode** (On-Demand or Dedicated) are
  now service properties instead of values inside Additional Attributes JSON.

**Upgrade behavior.** On upgrade, APEX switches eligible OpenAI services to Responses and eligible Gemini services
to Interactions, but only when the service has no custom Additional Attributes and no custom HTTP Headers. Generic
OpenAI Compatible and Ollama services without Additional Attributes are also eligible for Responses. Services with
custom settings keep their legacy API, so review them and update API-specific attributes or headers before switching
by hand. OCI services stay on Generic, and their compartment, model, and serving-mode values move out of Additional
Attributes into the new properties.

---

## Feature 4: Reasoning Effort

**What it does.** Reasoning Effort (also called Thinking Level) controls how much reasoning a supported model uses
before it answers or picks its next tool call. Lower effort can cut response time and token use; higher effort suits
complex work but costs more time and tokens. The available levels depend on the provider, the API, and the model.

**Three places to set it.**

| Where | How |
|---|---|
| AI Agent | Under **Advanced**, set **Reasoning Effort**. Each agent has its own value, so two agents on one service can differ |
| PL/SQL | Pass `p_reasoning_effort` to `APEX_AI.GENERATE` or `APEX_AI.CHAT` |
| AI Request Handler | Set `p_result.request.reasoning_effort` at runtime for the outgoing request |

**Settings.** The UI lists every value for every provider and does not filter by model, so the value you pick must be
supported by the model you call.

| Setting | Value APEX sends |
|---|---|
| Default | Nothing (`NULL`). The provider and model decide; this does not switch reasoning off. Existing agents keep this after upgrade |
| None / Minimal (provider specific) | `none` / `minimal` |
| Low / Medium / High | `low` / `medium` / `high` |
| Extra High / Maximum (provider specific) | `xhigh` / `max` |

PL/SQL constants use the prefix `apex_ai.c_reasoning_effort_` (for example `apex_ai.c_reasoning_effort_low`).

**Provider support.**

| Service | What to know |
|---|---|
| OpenAI | Use the Responses Provider API for the reasoning-effort integration |
| OCI Generative AI | Responses for OpenAI models; other compatible models use the Generic API's reasoning control |
| Google Gemini | Thinking levels on compatible models, through the Interactions integration |
| Anthropic Claude, Mistral AI | Supported through their existing integrations; no Responses selection needed |
| Ollama, Generic OpenAI Compatible | The endpoint and model must implement both the API and the reasoning control |
| Cohere (native) | Not supported by this setting |

**PL/SQL example.**

```sql
declare
  l_answer clob;
begin
  l_answer := apex_ai.generate(
                p_prompt            => 'List the risks in this rollout order: build, test, deploy, announce.',
                p_service_static_id => 'my-openai-service',
                p_reasoning_effort  => apex_ai.c_reasoning_effort_low );
  dbms_output.put_line( substr( l_answer, 1, 2000 ) );
end;
/
```

**Choose the effort at runtime with an AI Request Handler.** Create the procedure, then register it under
**Edit Application Definition → AI → Request Handler Procedure**. APEX calls it for every AI request in the
application, so restrict the change with a condition. If the value comes from a page item, add that item to the AI
component's **Items to Submit**.

```sql
create or replace procedure app_ai_request_handler (
  p_param  in            apex_ai.t_chat_request_handler_param,
  p_result in out nocopy apex_ai.t_chat_request_handler_result )
as
begin
  if p_param.component.static_id = 'support-assistant' then
    p_result.request.reasoning_effort :=
      case v('P10_ANALYSIS_DEPTH') when 'DEEP' then 'high' else 'low' end;
  end if;
end app_ai_request_handler;
/
```

**Choosing a level.** Start low for lookups, status questions, and simple classification. Use high for multi-step
planning or dependency analysis. Compare answer quality, response time, and token usage on the same task at two
levels before raising effort as a default.

---

## Feature 5: Managed identities for OCI services

**What it does.** APEX Web Credentials can now reference a **DBMS_CLOUD credential** that uses **OCI Native
Authentication**, including **Resource Principal** (Autonomous AI Database) and **Database Tools Identity**. APEX
apps can then call services such as OCI Object Storage and OCI Generative AI without storing an individual user's
API private key in an APEX Web Credential. OCI IAM still decides what the identity may reach; the database manages
the credential APEX uses; for Autonomous Database Resource Principal, OCI also manages and rotates the underlying
credentials.

**Keep the three layers straight.**

| Layer | Role |
|---|---|
| OCI identity and IAM policies | Who is calling, and which OCI resources it may use |
| Database credential | Makes the managed authentication available inside the database |
| APEX Web Credential | References the database credential and gives APEX components and APIs a name and Static ID |

Creating the credential grants nothing by itself. The IAM policy sets the permissions.

**Option A: Database Tools Identity (works for any Oracle cloud database service).**

1. In OCI IAM, create a dynamic group for Database Tools connections
   (`ALL { resource.type = 'databasetoolsconnection', resource.compartment.id = '<compartment_ocid>' }`) and a
   policy that lets it read secrets in the compartment holding the database password and wallet secrets.
2. Create a second dynamic group for identities
   (`ALL { resource.type = 'databasetoolsidentity', resource.compartment.id = '<compartment_ocid>' }`) and grant it
   the least-privilege policy the target service needs.
3. Create a Database Tools connection to the APEX database as the parsing-schema user. That user needs
   `CREATE CREDENTIAL` and access to `DBMS_CLOUD`. Under Advanced Options, turn on **Enable Runtime Support** and
   choose **Resource Principal** as the runtime identity.
4. On the connection, open **Identities → Create Identity**. The **Credential Key** you enter becomes the database
   credential name. The identity moves from Creating to Active.
5. Verify the credential exists, then **Refresh** and **Validate** the identity:

   ```sql
   select credential_name from user_credentials where credential_name = 'APEX_OCI_MANAGED';
   ```

**Option B: Resource Principal on Autonomous AI Database.** Create an IAM dynamic group that includes the database
resource, grant it the permissions the target service needs, then enable it (the credential appears as
`OCI$RESOURCE_PRINCIPAL`):

```sql
begin
  dbms_cloud_admin.enable_resource_principal;                               -- as ADMIN
  dbms_cloud_admin.enable_resource_principal( username => 'APP_SCHEMA' );
end;
/
```

**Create the APEX Web Credential.** In **Workspace Utilities → Web Credentials**, create a credential, set
**Authentication Type** to **OCI Native Authentication**, switch on **Use Database Credential**, and choose a scope:

- **Schema** scope: usable only by workspaces whose parsing schema can reach the credential. The credential must be
  owned by that schema, or the schema needs `EXECUTE` on it plus a local or public synonym. Enter the bare name
  (`APEX_OCI_MANAGED` or `OCI$RESOURCE_PRINCIPAL`), never `SCHEMA.NAME`.
- **Instance** scope: usable across workspaces. Turn on instance database credentials and expose the credential to
  the APEX engine schema (Oracle Database 23ai / 26ai):

```sql
begin
  apex_instance_admin.set_parameter( 'INSTANCE_DBMS_CREDENTIAL_ENABLED', 'Y' );
end;
/
grant  execute on app_schema.apex_oci_managed to apex_260200;
create synonym apex_260200.apex_oci_managed for app_schema.apex_oci_managed;
```

`APEX_260200` is the 26.2.0 engine schema in Oracle's example; confirm the engine schema name in your environment.
On Oracle Database 19c, create the instance credential directly in the APEX schema, because the synonym approach does
not work there.

**Test it.** Call any OCI REST endpoint the identity is allowed to use, referencing the Web Credential's Static ID,
not the database credential name:

```sql
select apex_web_service.make_rest_request(
         p_url                  => 'https://identity.<region>.oci.oraclecloud.com/20160918/compartments/'
                                   || '?compartmentId=<tenancy_ocid>',
         p_http_method          => 'GET',
         p_credential_static_id => 'oci-managed-id' ) as response
from   dual;
```

This call needs a policy such as `Allow dynamic-group <identities_group> to inspect compartments in tenancy`. The same
Web Credential then works in REST Data Sources and `APEX_WEB_SERVICE` calls.

**Gotchas.**

- With a database-credential-backed Web Credential, the HTTP request runs as the application's **parsing schema**, so
  that schema needs the network ACL and HTTPS access to the OCI endpoint.
- **Valid for URLs** is not enforced for Web Credentials backed by database credentials.
- IAM changes can take time to take effect. Refresh the Database Tools identity, and allow for Resource Principal
  token caching on Autonomous AI Database.

| Symptom | Check |
|---|---|
| Identity stuck in Creating | Connection reachability, the password secret, `CREATE CREDENTIAL` |
| APEX cannot resolve the credential | Name, scope, `EXECUTE` privilege, synonym |
| OCI rejects the request | Identity state, dynamic group membership, IAM policy, target tenancy or resource |
| Request never reaches OCI | Outbound connectivity, network ACLs, TLS |

---

## Also new in 26.2 (not covered in the video)

Oracle's announcement and What's New page also list these. Mention them when relevant, and send people to the release
notes for detail.

- **AI Agent navigation:** agents can point users to a relevant page. Developers define the allowed destinations and
  parameters, and trusted application code builds the final APEX URL and checksum so session details stay out of
  model messages.
- **Interactive Reports refresh:** modernized layout, multi-select filters, better numeric and date filtering,
  drag-and-drop column ordering, and AI Interactive Reports that run common commands (filter, sort, hide columns,
  control breaks, reset) from configurable key phrases without an AI call, plus natural-language computed columns.
- **APEXlang:** preserved translations and Working Copy metadata, subscription mapping across workspaces, new PL/SQL
  APIs for application locking and Working Copies, and static analysis with SQLcl CodeScan.
- **Platform:** workflow improvements (Draft activities, custom outcomes for Action Tasks, instance migration, diagram
  export), Universal Theme 26.2 (including Pillar Light and Pillar Dark Iris appearances), chart improvements, better
  Human Task error handling, Mail Queue reporting, and stronger network access controls.

---

## Upgrade checklist (26.1 to 26.2)

1. Read **Important Information if Updating from a Release Prior to 26.2** and the **Changed Behavior** list in the
   26.2 release notes. It covers Static ID changes, export wizard changes, translation repository data in the APEXlang
   export, Interactive Report search bar and report-settings changes, the "Enable RESTful Services" instance setting,
   and tighter scope-and-token handling for OAuth in REST web service calls.
2. Inventory Generative AI Services that have custom Additional Attributes or HTTP Headers. They keep their legacy
   Provider API and may need manual changes.
3. Re-export applications as APEXlang with 26.2 before relying on file-level import.
4. Check the known-issues page and make sure you have the October 9 download files.
5. Test in a non-production workspace first. For a local environment, the
   [APEX 26.1 Docker guide](oracle-apex-261-docker-setup.md) shows the setup pattern; use the 26.2 download files, and
   remember that 26.2 on the Free developer release is supported through the Free forum only.

---

## Verify before reporting success

1. File-level import: change one page, import only that file, and confirm unrelated components did not change.
2. Deep Data Security: run the Sales and Finance test matrix, including the AI Agent path, and confirm the blocked
   credit-limit change stays blocked for Sales.
3. Provider API: **Test Connection** passes, and one real agent request round-trips through the chosen API.
4. Reasoning Effort: run the same task at two levels and compare answer, latency, and token usage.
5. Managed identity: the REST test returns data, and removing the IAM policy makes it fail, which proves IAM is the
   gate.
6. If any check could not be run (for example, no Deep Data Security policies exist yet), say so explicitly instead
   of declaring the feature verified.

---

## Non-negotiable rules

- Confirm the APEX release before writing code against a 26.2 feature.
- Treat file-level import as a development and test tool, not a production deployment method.
- Never guess Deep Data Security syntax or App Builder setting names; take them from the guide for the release in use.
- Never choose Responses for a service whose endpoint you have not confirmed supports it.
- Never pick a Reasoning Effort value the provider, API, and model do not support.
- Never store an OCI user's API private key in APEX when a managed identity is available.
- Do not claim a feature is verified until its check in the Verify section has been run.

---

## Related skills in this repository

- [Skill 36: APEXlang, Declarative Application Definitions for AI-Generated Enterprise Apps](../skills/36_apexlang_ai_application_generator.md)
- [Skill 37: Evaluating AI-Generated Enterprise Applications](../skills/37_evaluating_ai_generated_enterprise_apps.md)
- [Skill 28: Identity-Aware Row-Level Security for AI / MCP Agents](../skills/28_identity_aware_row_level_security_ai_agents/SKILL.md)
- [Skill 06: Oracle APEX AI Assistant](../skills/06_oracle_apex_ai_assistant.md)
- [Skill 39: Integrating AI Providers with Select AI on Oracle AI Database 26ai Free](../skills/39_ai_provider_integration_select_ai.md)
- [Oracle APEX 26.1 on Docker with Oracle AI Database 26ai Free](oracle-apex-261-docker-setup.md)

---

## References

- Oracle APEX 26.2 release video playlist: [apex.oracle.com/go/playlist-262](http://apex.oracle.com/go/playlist-262)
- Michael Hichwa, ["Announcing Oracle APEX 26.2 General Availability"](https://blogs.oracle.com/apex/announcing-oracle-apex-262), Oracle APEX blog, October 6, 2026
- Chaitanya Koratamaddi and Ashwin Rao, ["Introducing File-Level Import with APEXlang in Oracle APEX 26.2"](https://blogs.oracle.com/apex/introducing-file-level-import-with-apexlang-in-oracle-apex), October 6, 2026
- Chaitanya Koratamaddi and Roopesh Thokala, ["Working with Generative AI Provider APIs and Reasoning Effort"](https://blogs.oracle.com/apex/working-with-generative-ai-provider-apis-and-reasoning-effort), October 6, 2026
- Chaitanya Koratamaddi and Roopesh Thokala, ["Using DBMS_CLOUD Credentials with Resource Principal and DBTools Identity"](https://blogs.oracle.com/apex/using-dbms_cloud-credentials-with-resource-principal-and-dbtools-identity), October 6, 2026
- [APEXlang in practice: export, edit, validate, and import](https://blogs.oracle.com/apex/apexlang-in-practice-export-edit-validate-and-import-oracle-apex-applications)
- [Oracle APEX 26.2: What's New](https://www.oracle.com/apex/whats-new/) and the [26.2 Release Notes](https://docs.oracle.com/en/database/oracle/apex/26.2/htmrn/index.html)
- [APEX_AI API reference, 26.2](https://docs.oracle.com/en/database/oracle/apex/26.2/aeapi/APEX_AI.html)
- [Oracle APEX downloads](https://www.oracle.com/tools/downloads/apex-downloads/) and [APEX 26.2 known issues](https://www.oracle.com/tools/downloads/apex-downloads/apex-262-known-issues/)
- [What is Oracle Deep Data Security (guide)](https://docs.oracle.com/en/database/oracle/oracle-database/26/ddscg/what-is-oracle-deep-data-security.html) and the [Deep Data Security overview](https://www.oracle.com/security/database-security/features/deep-data-security/)
- [OCI Database Tools: Creating an Identity](https://docs.oracle.com/iaas/database-tools/doc/creating-identity.html) and [Using Resource Principal with Autonomous AI Database](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/resource-principal.html)
- [OCI Generative AI Responses API guide](https://docs.oracle.com/en-us/iaas/Content/generative-ai/responses-api.htm) and [Gemini Interactions API overview](https://ai.google.dev/gemini-api/docs/interactions-overview)

**#OracleAPEX #APEX262 #APEXlang #DeepDataSecurity #GenerativeAI #ResponsesAPI #ReasoningEffort #OCI #OracleAI**
