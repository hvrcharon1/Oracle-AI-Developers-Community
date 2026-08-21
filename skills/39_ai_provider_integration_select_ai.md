# Skill 39: Integrating AI Providers with Select AI on Oracle AI Database 26ai Free

**Category:** AI | Providers | **Level:** Beginner–Intermediate

---

## Overview

Select AI (`DBMS_CLOUD_AI`) is Oracle's provider-agnostic bridge between your database and an external LLM. Every Select AI capability — natural language to SQL, chat, RAG, synthetic data generation, summarization/translation, and `DBMS_CLOUD_AI_AGENT` tool calling — is powered by the same building block: an **AI profile** that points at one provider and one model. Swapping providers is a config change, not a rewrite.

Because Oracle AI Database 26ai Free is a **customer-managed, on-premises install** (not Autonomous Database), it does not ship with `DBMS_CLOUD_AI` preinstalled or with cloud egress pre-wired. This skill covers the one-time setup Free edition needs, then walks through connecting Select AI to each major provider family: OCI Generative AI, AWS Bedrock (Claude Opus/Sonnet), OpenAI, Azure OpenAI Service (the engine behind Microsoft Copilot), Anthropic direct, Google Gemini, Hugging Face, and any OpenAI-compatible endpoint (xAI Grok, DeepSeek, Mistral, and others) — plus how to point other in-database AI features at the same profile.

---

## Key Concepts

- **AI Profile** (`DBMS_CLOUD_AI.CREATE_PROFILE`): a named JSON config — `provider`, `credential_name`, `model`, `object_list` (which tables the LLM is allowed to see) — that every Select AI action reads
- **Credential** (`DBMS_CLOUD.CREATE_CREDENTIAL`): stores the provider secret (API key, or AWS access key/secret pair) inside the Oracle credential store — never in the profile JSON itself
- **Network ACL** (`DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE`): on-prem/Free databases must be explicitly granted outbound HTTPS access to each provider's host — this is the step people forget and then get `ORA-29024`/connection-refused errors chasing the wrong fix
- **`provider_endpoint`**: the escape-hatch attribute that lets *any* OpenAI-compatible API work with Select AI, even providers Oracle hasn't named individually — this is how Grok and DeepSeek plug in
- One profile → many capabilities: NL2SQL, `chat`, `narrate`, RAG, `DBMS_CLOUD_AI_AGENT`, and `DBMS_VECTOR_CHAIN` text/embedding calls can all reuse the same credential and profile infrastructure

---

## Step 0: Install DBMS_CLOUD on 26ai Free (one-time, on-prem only)

Skip this section if you're on Autonomous Database — `DBMS_CLOUD_AI` is preinstalled there. On Oracle AI Database 26ai Free, install it manually as SYS:

```bash
$ORACLE_HOME/perl/bin/perl $ORACLE_HOME/rdbms/admin/catcon.pl \
  -u sys/<sys_password> \
  --force_pdb_mode 'READ WRITE' \
  -b dbms_cloud_install \
  -d $ORACLE_HOME/rdbms/admin/ \
  -l /tmp \
  catclouduser.sql dbms_cloud_install.sql
```

Then verify:

```sql
CONNECT sys/<sys_password>@localhost:1521/FREEPDB1 AS SYSDBA
DESC C##CLOUD$SERVICE.DBMS_CLOUD_AI;
```

If your Free install sits behind a corporate proxy or firewall, confirm outbound HTTPS (443) is actually reachable before troubleshooting profile errors — this is the single most common blocker on Free/on-prem installs, since none of the provider hosts below are reachable by default the way they are inside an OCI VCN.

## Step 1: Grant Privileges

```sql
GRANT EXECUTE ON DBMS_CLOUD_AI TO ADB_USER;
GRANT EXECUTE ON DBMS_CLOUD TO ADB_USER;
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

Bedrock gives you a single credential that can reach Claude, Llama, Nova, and 100+ other models — useful if you want to A/B test Claude against other model families without re-plumbing credentials.

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

-- 3. Profile — Claude Sonnet
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'AWS_CLAUDE_SONNET',
    attributes   => '{"provider": "aws",
      "credential_name": "AWS_CRED",
      "object_list": [{"owner": "ADB_USER", "name": "ORDERS"}],
      "model": "us.anthropic.claude-sonnet-4-5-20250929-v1:0"}');
END;
/

-- Profile — Claude Opus (heavier reasoning, higher cost)
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'AWS_CLAUDE_OPUS',
    attributes   => '{"provider": "aws",
      "credential_name": "AWS_CRED",
      "object_list": [{"owner": "ADB_USER", "name": "ORDERS"}],
      "model": "us.anthropic.claude-opus-4-5-20251101-v1:0"}');
END;
/
```

**Notes:**
- `model` is **required** for AWS — there is no default.
- Grant your IAM identity `bedrock:InvokeModel` / `bedrock:InvokeModelWithResponseStream` on the target model ARN, and enable model access for Claude in the Bedrock console first.
- Newer Claude releases on Bedrock are served through **cross-region inference profiles**, not the bare base model ID. Use the `us.` (or `global.`) prefix as shown above — passing the bare `anthropic.claude-...` ID without a prefix returns an HTTP 400. Check the current inference-profile ID for the Claude version you want in the Bedrock console, since Anthropic and AWS ship new dated snapshots regularly.
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
      "model": "gpt-5.1"}');
END;
/
```

OpenAI ships new model snapshots every few weeks — confirm the current model name at `platform.openai.com/docs/models` before deploying to production rather than trusting a hardcoded string.

### Azure OpenAI Service — the engine behind Microsoft Copilot

There is no direct "Microsoft Copilot" API you can point Select AI at — Copilot is a packaged end-user product. The models that power it are served through **Azure OpenAI Service** (rebranded **Microsoft Foundry Models** in Microsoft's January 2026 product terms), and that's the provider Select AI actually integrates with. Enabling this profile gives you the same underlying OpenAI models Copilot uses, with Azure-native governance and data residency controls.

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
      "model": "gemini-3-flash-preview",
      "object_list": [{"owner": "ADB_USER", "name": "ORDERS"}]}');
END;
/
```

### Hugging Face

Same pattern — `provider: "huggingface"`, ACL host `api-inference.huggingface.co`, credential holds your Hugging Face token. Useful for open-weight models you don't want to self-host.

### OpenAI-Compatible Providers — xAI Grok & DeepSeek

Any provider that exposes an OpenAI-compatible `/chat/completions` endpoint works via the `provider_endpoint` attribute — this is the same mechanism Oracle documents for Mistral AI and Fireworks AI, and it covers Grok and DeepSeek identically since both expose OpenAI-compatible APIs.

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
      "model": "grok-4",
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
- Model names on both Grok and DeepSeek change frequently (DeepSeek retired its `deepseek-chat`/`deepseek-reasoner` aliases in favor of versioned `deepseek-v4-*` names in 2026); check each provider's current docs before hardcoding into production DDL.

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
| Hugging Face | `huggingface` | `api-inference.huggingface.co` | no (has default) |
| xAI / DeepSeek / any OpenAI-compatible | *(omit — implied by `provider_endpoint`)* | provider's API host | **yes**, plus `provider_endpoint` |

---

## Powering Other AI Capabilities From the Same Profile

Once a profile exists, it's reusable well beyond NL2SQL:

```sql
-- Set once per session
EXEC DBMS_CLOUD_AI.SET_PROFILE('AWS_CLAUDE_SONNET');

SELECT AI SHOWSQL  'Top 5 customers by order value last quarter';
SELECT AI RUNSQL    'Top 5 customers by order value last quarter';
SELECT AI NARRATE   'Summarize sales performance by region';
SELECT AI CHAT       'Explain what a materialized view is';

-- Stateless equivalent (specify profile per call — useful in APEX or a connection pool)
SELECT DBMS_CLOUD_AI.GENERATE(
  prompt      => 'Top 5 customers by order value',
  profile_name => 'AWS_CLAUDE_SONNET',
  action      => 'showsql') FROM dual;
```

- **AI agents:** [Skill 04: Building AI Agents with DBMS_CLOUD_AI_AGENT](04_building_ai_agents_dbms_cloud_ai_agent.md) registers tools against this same profile/credential infrastructure.
- **RAG and document chunking:** [Skill 08: RAG with Oracle AI Vector Search](08_rag_oracle_ai_vector_search.md) and [Skill 23: DBMS_VECTOR_CHAIN](23_dbms_vector_chain_text_processing.md) can call the same provider credential to generate embeddings and summarize chunks during ingestion — point the embedding step at `azure_embedding_deployment_name` (Azure) or the provider's embedding model ID (OpenAI, Cohere, OCI) rather than standing up a second credential.
- **Vector Search:** [Skill 01: Oracle AI Vector Search](01_oracle_ai_vector_search.md) covers storing and querying the embeddings these providers generate.

---

## Tips

- Store every secret through `DBMS_CLOUD.CREATE_CREDENTIAL` — never inline an API key in profile JSON or application code.
- On Free/on-prem installs, verify outbound HTTPS egress *before* debugging profile errors — most "the model won't respond" issues on Free edition are network ACL or firewall problems, not profile misconfiguration.
- `model` is optional (has a sane default) for OCI, OpenAI, Anthropic, Google, and Hugging Face — but **mandatory** for AWS Bedrock and any `provider_endpoint`-based OpenAI-compatible integration.
- Use `SHOWSQL` before `RUNSQL` in any workflow touching production data, regardless of which provider generated the SQL.
- Keep one profile per provider/model pair (e.g., `AWS_CLAUDE_SONNET` vs. `AWS_CLAUDE_OPUS`) so you can `SET_PROFILE` to A/B test quality, latency, and cost without touching application code.
- To rotate a credential, drop and recreate it with `DBMS_CLOUD.DROP_CREDENTIAL` / `CREATE_CREDENTIAL` rather than editing in place.

---

## Related Skills

- [Skill 01: Oracle AI Vector Search](01_oracle_ai_vector_search.md)
- [Skill 02: Select AI — Natural Language to SQL](02_select_ai_natural_language_to_sql.md)
- [Skill 04: Building AI Agents with DBMS_CLOUD_AI_AGENT](04_building_ai_agents_dbms_cloud_ai_agent.md)
- [Skill 07: OCI Generative AI Service](07_oci_generative_ai_service.md)
- [Skill 08: RAG with Oracle AI Vector Search](08_rag_oracle_ai_vector_search.md)
- [Skill 23: DBMS_VECTOR_CHAIN: Document Chunking & Text Processing](23_dbms_vector_chain_text_processing.md)
- [Skill 38: Migrating Oracle Database 23ai Free to Oracle AI Database 26ai Free on Windows](38_migrating_23ai_free_to_26ai_free_windows.md)

**#SelectAI #AIProviders #OracleAIDatabase #AWSBedrock #Claude #OpenAI #AzureOpenAI #MicrosoftCopilot #DeepSeek #Grok #Gemini #DBMS_CLOUD_AI**
