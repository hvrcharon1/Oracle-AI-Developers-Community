# Skill 39: Integrating AI Providers with Select AI on Oracle AI Database 26ai Free (Windows 11)

**Category:** AI | Providers | **Level:** Beginner–Intermediate

---

## Overview

Select AI (`DBMS_CLOUD_AI`) is Oracle's provider-agnostic bridge between your database and an external LLM. Every Select AI capability — natural language to SQL, chat, summarization, translation, embeddings, RAG, and `DBMS_CLOUD_AI_AGENT` tool calling — is powered by the same building block: an **AI profile** that points at one provider and one model. Swapping providers is a config change, not a rewrite.

Because Oracle AI Database 26ai Free is a **customer-managed, on-premises install** (not Autonomous Database), it does not ship with `DBMS_CLOUD_AI` preinstalled or with cloud egress pre-wired. This skill assumes the native Windows 11 install path from [Skill 38](38_migrating_23ai_free_to_26ai_free_windows.md) — `setup.exe` extracted to `C:\app\oracle\product\26ai\dbhomeFree`, SID `FREE`, listener on port 1521, PDB `freepdb1` — and covers the one-time setup that install needs before Select AI works at all, then walks through connecting Select AI to each major provider family: OCI Generative AI, AWS Bedrock (Claude Opus/Sonnet), OpenAI, Azure OpenAI Service (the engine behind Microsoft Copilot, now sold under Microsoft Foundry), Anthropic direct, Google Gemini, Cohere, Hugging Face, and any OpenAI-compatible endpoint (xAI Grok, DeepSeek, and others) — plus how to point other in-database AI features at the same profile.

**Free edition caveat:** Free caps itself at 2 CPUs / 2 GB RAM / 12 GB user data regardless of host specs. None of the steps below are blocked by that cap, but large `object_list` scans, big RAG ingestion pipelines, or a heavy `DBMS_CLOUD_AI_AGENT` workload will feel it well before a paid edition would.

---

## Key Concepts

- **AI Profile** (`DBMS_CLOUD_AI.CREATE_PROFILE`): a named JSON config — `provider`, `credential_name`, `model`, `object_list` (which tables the LLM is allowed to see) — that every Select AI action reads. The database sends schema metadata (table/column names, comments) to the LLM, never row data, when generating SQL.
- **Credential** (`DBMS_CLOUD.CREATE_CREDENTIAL`): stores the provider secret (API key, or AWS access key/secret pair) inside the Oracle credential store — never in the profile JSON itself.
- **Network ACL** (`DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE`): on-prem/Free databases must be explicitly granted outbound HTTPS access to each provider's host — this is the step people forget and then get `ORA-29024`/connection-refused errors chasing the wrong fix. OCI Generative AI is the one exception (traffic stays inside Oracle's network).
- **`provider_endpoint`**: the escape-hatch attribute that lets *any* OpenAI-compatible API work with Select AI, even providers Oracle hasn't named individually — this is how Grok and DeepSeek plug in.
- **`additional_instructions`**: an attribute (settable on the profile or passed inline to `GENERATE`) for handing the LLM business rules, glossary terms, or column-usage guidance. In practice this improves NL2SQL accuracy more than switching providers does.
- One profile → many capabilities: NL2SQL, `chat`, `narrate`, `summarize`, `translate`, `embedding`, RAG, and `DBMS_VECTOR_CHAIN` text/embedding calls can all reuse the same credential and profile infrastructure.

---

## Step 0: Install DBMS_CLOUD on 26ai Free (one-time, on-prem only)

Skip this section if you're on Autonomous Database — `DBMS_CLOUD_AI` is preinstalled there. On the customer-managed 26ai Free install, the `DBMS_CLOUD` family (`DBMS_CLOUD`, `DBMS_CLOUD_AI`, `DBMS_CLOUD_NOTIFICATION`, `DBMS_CLOUD_PIPELINE`, `DBMS_CLOUD_REPO`) has to be installed manually as SYS — it isn't preinstalled, and it only offers a subset of the functionality Autonomous Database gets.

Open **Command Prompt as Administrator** and set the environment for your 26ai Free home:

```cmd
set ORACLE_HOME=C:\app\oracle\product\26ai\dbhomeFree
set ORACLE_SID=FREE
mkdir C:\Temp\dbms_cloud_install
```

Run the install using the Perl interpreter that ships inside the Oracle Home (on Windows this is `%ORACLE_HOME%\perl\bin\perl.exe`, not a system Perl):

```cmd
%ORACLE_HOME%\perl\bin\perl %ORACLE_HOME%\rdbms\admin\catcon.pl -u sys/<sys_password> --force_pdb_mode "READ WRITE" -b dbms_cloud_install -d %ORACLE_HOME%\rdbms\admin -l C:\Temp\dbms_cloud_install catclouduser.sql dbms_cloud_install.sql
```

Then verify:

```cmd
%ORACLE_HOME%\bin\sqlplus sys/<sys_password>@localhost:1521/freepdb1 as sysdba
```

```sql
DESC C##CLOUD$SERVICE.DBMS_CLOUD_AI;
```

Two things that trip people up on Windows specifically:

- **No SSL wallet needed.** Older Oracle releases required creating and configuring an Oracle wallet before `DBMS_CLOUD`/`UTL_HTTP` could reach an HTTPS endpoint. Starting with 26ai, the database uses the Windows OS certificate store instead, so that step is gone — if a tutorial you find online has you creating a wallet first, it's describing an older release.
- **Corporate firewall / Windows Defender Firewall.** Before troubleshooting a profile error, confirm the host can actually reach the provider on port 443. From an elevated PowerShell prompt: `Test-NetConnection api.openai.com -Port 443`. A failed connection here — not a bad ACL or credential — is the single most common cause of `ORA-29024` and "the model won't respond" symptoms on Free/on-prem Windows installs, since none of the provider hosts below are reachable by default the way they are inside an OCI VCN.

## Step 1: Grant Privileges

```sql
GRANT EXECUTE ON DBMS_CLOUD_AI TO ADB_USER;
GRANT EXECUTE ON DBMS_CLOUD TO ADB_USER;
GRANT EXECUTE ON DBMS_CLOUD_PIPELINE TO ADB_USER; -- needed for RAG ingestion (Skill 08)
```

---

## Step 2: Configure a Provider

Every provider below follows the same three-part pattern: **credential → network ACL → profile**. Replace `ADB_USER` with your working schema.

### OCI Generative AI (native — no external ACL needed)

Traffic to OCI Generative AI stays inside Oracle's network, so no `APPEND_HOST_ACE` call is required. See [Skill 07: OCI Generative AI Service](07_oci_generative_ai_service.md) for full credential setup.

```sql
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'OCI_PROFILE',
    attributes   => '{"provider": "oci",
      "credential_name": "OCI_GENAI_CRED",
      "object_list": [{"owner": "ADB_USER", "name": "ORDERS"}]}');
END;
/
```

### AWS Bedrock — Claude Opus & Sonnet

Bedrock gives you a single credential that can reach Claude, Nova, Llama, and 100+ other models — useful if you want to A/B test Claude against other model families without re-plumbing credentials.

```sql
-- 1. Credential: AWS access key ID / secret access key
BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
    credential_name => 'AWS_CRED',
    username        => '<aws_access_key_id>',
    password        => '<aws_secret_access_key>');
END;
/

-- 2. Network ACL
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
    host => 'bedrock-runtime.us-east-1.amazonaws.com',
    ace  => xs$ace_type(privilege_list => xs$name_list('http'),
              principal_name => 'ADB_USER',
              principal_type => xs_acl.ptype_db));
END;
/

-- 3. Profile — Claude Sonnet (global cross-region inference profile)
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'AWS_CLAUDE_SONNET',
    attributes   => '{"provider": "aws",
      "credential_name": "AWS_CRED",
      "object_list": [{"owner": "ADB_USER", "name": "ORDERS"}],
      "model": "global.anthropic.claude-sonnet-5"}');
END;
/

-- Profile — Claude Opus (heavier reasoning, higher cost)
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'AWS_CLAUDE_OPUS',
    attributes   => '{"provider": "aws",
      "credential_name": "AWS_CRED",
      "object_list": [{"owner": "ADB_USER", "name": "ORDERS"}],
      "model": "global.anthropic.claude-opus-5"}');
END;
/
```

**Notes:**
- `model` is **required** for AWS — there is no default.
- Grant your IAM identity `bedrock:InvokeModel` / `bedrock:InvokeModelWithResponseStream` on the target model, and enable model access for Claude in the Bedrock console first.
- **Model-ID naming changed with the Claude 5 generation.** Older Claude releases on Bedrock (Sonnet 4.5, Sonnet 4.6, Opus 4.7, Opus 4.8, etc.) use *dated, region-prefixed* cross-region inference profile IDs, e.g. `jp.anthropic.claude-sonnet-4-6`. The current Claude 5 line (Opus 5, Sonnet 5) instead ships as an *undated* base model ID (`anthropic.claude-opus-5`) reached through `us.`/`eu.`/`global.` cross-region inference profiles — no dated suffix. The `global.` profile is usually the right default: it routes to whichever supported region has capacity and is priced roughly 10% below the geographic `us.`/`eu.` profiles. Whichever generation you target, confirm the exact profile ID in the Bedrock console before hardcoding it into production DDL — AWS adds and retires profiles on its own schedule, independent of Oracle's release cycle.
- Bedrock's **imported/custom models are not supported** through the Converse API path Select AI uses.

### OpenAI (ChatGPT models)

```sql
BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
    credential_name => 'OPENAI_CRED', username => 'OPENAI', password => '<sk-...>');
END;
/
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
    host => 'api.openai.com',
    ace  => xs$ace_type(privilege_list => xs$name_list('http'),
              principal_name => 'ADB_USER', principal_type => xs_acl.ptype_db));
END;
/
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'OPENAI_PROFILE',
    attributes   => '{"provider": "openai",
      "credential_name": "OPENAI_CRED",
      "object_list": [{"owner": "ADB_USER", "name": "ORDERS"}],
      "model": "gpt-5.6"}');
END;
/
```

OpenAI's current flagship family is GPT-5.6 (Sol/Terra/Luna tiers, shipped July 2026), superseding the GPT-5.1–5.5 line from late 2025/early 2026. OpenAI ships new model snapshots every few weeks — confirm the exact current model string at `platform.openai.com/docs/models` before deploying to production rather than trusting a hardcoded value here.

### Azure OpenAI Service — the engine behind Microsoft Copilot

There is no direct "Microsoft Copilot" API you can point Select AI at — Copilot is a packaged end-user product. The models that power it are served through **Azure OpenAI Service**, which Microsoft folded into the broader **Microsoft Foundry** platform (renamed from Azure AI Foundry at Microsoft Ignite, November 2025) as "Foundry Models sold by Azure." Enabling this profile gives you the same underlying OpenAI models Copilot uses, with Azure-native governance and data residency controls.

```sql
BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
    credential_name => 'AZURE_CRED', username => 'AZUREAI', password => '<azure_api_key>');
END;
/
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
    host => '<azure_resource_name>.openai.azure.com',
    ace  => xs$ace_type(privilege_list => xs$name_list('http'),
              principal_name => 'ADB_USER', principal_type => xs_acl.ptype_db));
END;
/
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'AZURE_PROFILE',
    attributes   => '{"provider": "azure",
      "azure_resource_name": "<azure_resource_name>",
      "azure_deployment_name": "<azure_deployment_name>",
      "credential_name": "AZURE_CRED",
      "object_list": [{"owner": "ADB_USER", "name": "ORDERS"}]}');
END;
/
```

`azure_resource_name` and `azure_deployment_name` come from the model deployment you create in the Azure/Microsoft Foundry portal — not from a model string. There's a matching `azure_embedding_deployment_name` attribute if you also want Azure to serve embeddings for vector search.

**Worth knowing:** Microsoft Foundry's model catalog has grown well beyond OpenAI — it now also serves Anthropic Claude, xAI Grok, DeepSeek, Cohere, and Meta/Mistral models through the same Azure resource. Select AI's documented `azure` provider attribute, however, targets the Azure OpenAI / "Foundry Models sold by Azure" deployment pattern specifically (the `azure_resource_name`/`azure_deployment_name` pair above). For a non-OpenAI model you've deployed inside Foundry, there isn't a first-class Select AI `azure`-provider path yet — use that vendor's own Select AI provider (`aws`, `anthropic`) or the generic `provider_endpoint` mechanism instead.

### Anthropic (direct Claude API)

A lighter-weight alternative to Bedrock when you don't need AWS-native billing/IAM — just an Anthropic API key.

```sql
BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
    credential_name => 'ANTHROPIC_CRED', username => 'ANTHROPIC', password => '<anthropic_api_key>');
END;
/
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
    host => 'api.anthropic.com',
    ace  => xs$ace_type(privilege_list => xs$name_list('http'),
              principal_name => 'ADB_USER', principal_type => xs_acl.ptype_db));
END;
/
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'ANTHROPIC_PROFILE',
    attributes   => '{"provider": "anthropic",
      "credential_name": "ANTHROPIC_CRED",
      "object_list": [{"owner": "ADB_USER", "name": "ORDERS"}]}');
END;
/
```

`model` is optional here — Select AI falls back to a current default Claude model if omitted. Set it explicitly (e.g. to a specific Sonnet or Opus snapshot from the Anthropic API docs) if you need a pinned, reproducible version.

### Google (Gemini)

```sql
BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
    credential_name => 'GOOGLE_CRED', username => 'GOOGLE', password => '<google_ai_studio_key>');
END;
/
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
    host => 'generativelanguage.googleapis.com',
    ace  => xs$ace_type(privilege_list => xs$name_list('http'),
              principal_name => 'ADB_USER', principal_type => xs_acl.ptype_db));
END;
/
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'GOOGLE_PROFILE',
    attributes   => '{"provider": "google",
      "credential_name": "GOOGLE_CRED",
      "model": "gemini-3-pro",
      "object_list": [{"owner": "ADB_USER", "name": "ORDERS"}]}');
END;
/
```

Google's Gemini 3 family (Pro and several Flash tiers — 3, 3.1, 3.5, 3.6, 3.7 Flash all shipped across 2026) updates faster than most other providers. Check the current model list at `ai.google.dev/gemini-api/docs/models` before deploying.

### Cohere

Cohere was one of the two providers Select AI originally shipped with (alongside OpenAI), and it's still a solid low-cost option for NL2SQL and embeddings.

```sql
BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
    credential_name => 'COHERE_CRED', username => 'COHERE', password => '<cohere_api_key>');
END;
/
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
    host => 'api.cohere.ai',
    ace  => xs$ace_type(privilege_list => xs$name_list('http'),
              principal_name => 'ADB_USER', principal_type => xs_acl.ptype_db));
END;
/
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'COHERE_PROFILE',
    attributes   => '{"provider": "cohere",
      "credential_name": "COHERE_CRED",
      "object_list": [{"owner": "ADB_USER", "name": "ORDERS"}]}');
END;
/
```

### Hugging Face

Same pattern — `provider: "huggingface"`, ACL host `api-inference.huggingface.co`, credential holds your Hugging Face token. Useful for open-weight models you don't want to self-host.

### OpenAI-Compatible Providers — xAI Grok & DeepSeek

Any provider that exposes an OpenAI-compatible `/chat/completions` endpoint works via the `provider_endpoint` attribute — this is the same mechanism Oracle documents for Fireworks AI, and it covers Grok and DeepSeek identically since both expose OpenAI-compatible APIs.

```sql
-- xAI Grok
BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
    credential_name => 'GROK_CRED', username => 'XAI', password => '<xai_api_key>');
END;
/
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
    host => 'api.x.ai',
    ace  => xs$ace_type(privilege_list => xs$name_list('http'),
              principal_name => 'ADB_USER', principal_type => xs_acl.ptype_db));
END;
/
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'GROK_PROFILE',
    attributes   => '{"credential_name": "GROK_CRED",
      "object_list": [{"owner": "ADB_USER", "name": "ORDERS"}],
      "model": "grok-4.6",
      "provider_endpoint": "api.x.ai/v1"}');
END;
/

-- DeepSeek
BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
    credential_name => 'DEEPSEEK_CRED', username => 'DEEPSEEK', password => '<deepseek_api_key>');
END;
/
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
    host => 'api.deepseek.com',
    ace  => xs$ace_type(privilege_list => xs$name_list('http'),
              principal_name => 'ADB_USER', principal_type => xs_acl.ptype_db));
END;
/
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'DEEPSEEK_PROFILE',
    attributes   => '{"credential_name": "DEEPSEEK_CRED",
      "object_list": [{"owner": "ADB_USER", "name": "ORDERS"}],
      "model": "deepseek-v4-flash",
      "provider_endpoint": "api.deepseek.com/v1"}');
END;
/
```

**Notes:**
- `model` and `provider_endpoint` are both **required** for this path — there's no default.
- `provider_endpoint` is the base URL *without* the trailing `/chat/completions` — Select AI appends that itself.
- xAI now operates under its parent SpaceXAI following the 2026 SpaceX–xAI merger, but the `api.x.ai` endpoint and credential flow are unchanged. Current flagship is `grok-4.6` (August 2026); check `docs.x.ai/developers/models` for the latest.
- DeepSeek retired its `deepseek-chat`/`deepseek-reasoner` aliases in favor of versioned `deepseek-v4-*` names (`deepseek-v4-flash`, `deepseek-v4-pro`) through 2026 — check DeepSeek's API docs before hardcoding into production DDL, since both providers version aggressively.

---

## Provider Quick Reference

| Provider | `provider` value | Network ACL host | `model` required? |
|---|---|---|---|
| OCI Generative AI | `oci` | none (in-VCN) | no (has default) |
| AWS Bedrock | `aws` | `bedrock-runtime.<region>.amazonaws.com` | **yes** |
| OpenAI | `openai` | `api.openai.com` | no (has default) |
| Azure OpenAI / Microsoft Foundry | `azure` | `<resource>.openai.azure.com` | via `azure_deployment_name` |
| Anthropic (direct) | `anthropic` | `api.anthropic.com` | no (has default) |
| Google Gemini | `google` | `generativelanguage.googleapis.com` | no (has default) |
| Cohere | `cohere` | `api.cohere.ai` | no (has default) |
| Hugging Face | `huggingface` | `api-inference.huggingface.co` | no (has default) |
| xAI / DeepSeek / any OpenAI-compatible | *(omit — implied by `provider_endpoint`)* | provider's API host | **yes**, plus `provider_endpoint` |

---

## Beyond NL2SQL: Every Select AI Action, and What Else 26ai Free Can Do With the Same Profile

Once a profile exists, it's reusable well beyond generating SQL:

```sql
-- Set once per session
EXEC DBMS_CLOUD_AI.SET_PROFILE('AWS_CLAUDE_SONNET');
```

| Action | What it does |
|---|---|
| `showsql` | Generates SQL from the prompt without running it — **this is the default action** if none is specified |
| `runsql` | Generates and executes the SQL, returning results |
| `narrate` | Runs the SQL and returns a natural-language summary of the results |
| `explainsql` | Generates SQL and explains what it does, in plain language |
| `chat` | General-purpose conversation with the underlying LLM — no SQL involved |
| `summarize` | Summarizes supplied text using the profile's LLM |
| `translate` | Translates supplied text to the profile's configured target language |
| `embedding` | Returns a vector embedding for supplied text, for use with AI Vector Search |
| `feedback` | Records positive/negative feedback (optionally with corrected SQL) against a past result, so future NL2SQL generations improve |

```sql
SELECT AI SHOWSQL    'Top 5 customers by order value last quarter';
SELECT AI EXPLAINSQL 'Top 5 customers by order value last quarter';
SELECT AI NARRATE    'Summarize sales performance by region';
SELECT AI CHAT       'Explain what a materialized view is';

-- Stateless equivalent (specify profile per call — useful in APEX or a connection pool)
SELECT DBMS_CLOUD_AI.GENERATE(
  prompt      => 'Top 5 customers by order value',
  profile_name => 'AWS_CLAUDE_SONNET',
  action      => 'showsql') FROM dual;
```

- **AI agents (Select AI Agent / `DBMS_CLOUD_AI_AGENT`):** [Skill 04: Building AI Agents with DBMS_CLOUD_AI_AGENT](04_building_ai_agents_dbms_cloud_ai_agent.md) registers tools, tasks, and multi-agent "teams" against this same profile/credential infrastructure — Oracle's own examples show agents built on OpenAI, Google, and Grok profiles. **Caveat for Free/on-prem:** the customer-managed `DBMS_CLOUD` package family installed in Step 0 (`DBMS_CLOUD`, `DBMS_CLOUD_AI`, `DBMS_CLOUD_NOTIFICATION`, `DBMS_CLOUD_PIPELINE`, `DBMS_CLOUD_REPO`) does not list `DBMS_CLOUD_AI_AGENT` among the packages it provisions, and Select AI Agent's documentation lives under the Autonomous AI Database library. Run `DESC DBMS_CLOUD_AI_AGENT;` after Step 0 to check whether it's present on your specific 26ai Free build before planning around it — if it isn't, every profile you created above still works for the full action table above.
- **RAG and document chunking:** [Skill 08: RAG with Oracle AI Vector Search](08_rag_oracle_ai_vector_search.md) and [Skill 23: DBMS_VECTOR_CHAIN](23_dbms_vector_chain_text_processing.md) can call the same provider credential to generate embeddings and summarize chunks during ingestion — point the embedding step at `azure_embedding_deployment_name` (Azure) or the provider's embedding model ID (OpenAI, Cohere, OCI) rather than standing up a second credential.
- **Vector Search:** [Skill 01: Oracle AI Vector Search](01_oracle_ai_vector_search.md) covers storing and querying the embeddings these providers generate — including Oracle's in-database ONNX embedding models, which run entirely offline with no provider, credential, or network ACL at all, worth knowing if you ever need Select AI-adjacent AI capability with zero external egress.

---

## Tips

- Store every secret through `DBMS_CLOUD.CREATE_CREDENTIAL` — never inline an API key in profile JSON or application code.
- On Free/on-prem Windows installs, verify outbound HTTPS egress with `Test-NetConnection <host> -Port 443` in PowerShell *before* debugging profile errors — most "the model won't respond" issues are a firewall or network ACL problem, not a profile misconfiguration.
- `model` is optional (has a sane default) for OCI, OpenAI, Anthropic, Google, Cohere, and Hugging Face — but **mandatory** for AWS Bedrock and any `provider_endpoint`-based OpenAI-compatible integration.
- Use `SHOWSQL` before `RUNSQL` in any workflow touching production data, regardless of which provider generated the SQL.
- Keep one profile per provider/model pair (e.g., `AWS_CLAUDE_SONNET` vs. `AWS_CLAUDE_OPUS`) so you can `SET_PROFILE` to A/B test quality, latency, and cost without touching application code.
- To rotate a credential, drop and recreate it with `DBMS_CLOUD.DROP_CREDENTIAL` / `CREATE_CREDENTIAL` rather than editing in place.
- Model IDs and version strings across every provider in this skill change on a timescale of weeks, not years — treat every model string here as an illustrative example current as of August 2026, not a value to copy verbatim into production DDL without checking the provider's docs first.

---

## Related Skills

- [Skill 01: Oracle AI Vector Search](01_oracle_ai_vector_search.md)
- [Skill 02: Select AI — Natural Language to SQL](02_select_ai_natural_language_to_sql.md)
- [Skill 04: Building AI Agents with DBMS_CLOUD_AI_AGENT](04_building_ai_agents_dbms_cloud_ai_agent.md)
- [Skill 07: OCI Generative AI Service](07_oci_generative_ai_service.md)
- [Skill 08: RAG with Oracle AI Vector Search](08_rag_oracle_ai_vector_search.md)
- [Skill 11: Oracle AI Database 26ai Unified Memory](11_oracle_ai_database_26ai_unified_memory.md)
- [Skill 23: DBMS_VECTOR_CHAIN: Document Chunking & Text Processing](23_dbms_vector_chain_text_processing.md)
- [Skill 38: Migrating Oracle Database 23ai Free to Oracle AI Database 26ai Free on Windows](38_migrating_23ai_free_to_26ai_free_windows.md)

## References

- [Oracle AI Database Select AI User's Guide, Release 26ai](https://docs.oracle.com/en/database/oracle/oracle-database/26/selai/oracle-database-select-ai-users-guide.pdf)
- [20 DBMS_CLOUD Family of Packages — Installing DBMS_CLOUD](https://docs.oracle.com/en/database/oracle/oracle-database/26/sutil/installing-dbms_cloud.html)
- [DBMS_CLOUD_AI Package Reference](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/dbms-cloud-ai-package.html)
- [DBMS_CLOUD_AI_AGENT Package Reference](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/dbms-cloud-ai-agent-package.html)
- [Claude on Amazon Bedrock — model IDs and cross-region inference profiles](https://platform.claude.com/docs/en/build-with-claude/claude-on-amazon-bedrock-legacy)
- [Microsoft Foundry — Foundry Models sold by Azure](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/concepts/models-sold-directly-by-azure)
- [xAI (SpaceXAI) Grok models and pricing](https://docs.x.ai/developers/models)
- Ron Ekins, ["Getting started with DBMS_CLOUD and Oracle AI Database 26ai"](https://ronekins.com/2026/06/10/getting-started-with-dbms_cloud-and-oracle-ai-database-26ai/) — confirms the OS-certificate-store change that removes the wallet step on 26ai

**#SelectAI #AIProviders #OracleAIDatabase #Windows11 #AWSBedrock #Claude #OpenAI #AzureOpenAI #MicrosoftFoundry #MicrosoftCopilot #Cohere #DeepSeek #Grok #Gemini #DBMS_CLOUD_AI**
