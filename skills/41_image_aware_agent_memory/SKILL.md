---
name: oracle-image-aware-agent-memory
description: >
  Use this skill whenever a task involves giving an AI agent durable, searchable memory of images
  with Oracle AI Agent Memory (the oracleagentmemory Python package, release 26.8 or later) on
  Oracle AI Database: persisting screenshots, receipts, forms, or product photos as image records,
  attaching images to multimodal thread messages, finding images through their text descriptions or
  captions, keeping default retrieval free of raw bytes, and fetching bytes explicitly with
  include_bytes=True. Trigger on add_image_async, list_images_async, ImageContent,
  record_types=["image"], or requests like "make my support agent remember the screenshot the
  customer sent" or "let the agent search past receipts". Works with any AI provider or model.
---

<!--
  CREDIT / ATTRIBUTION (kept here as a comment on purpose, not part of the skill body)

  Based on the article "Image-Aware AI Agent Memory: From Visual Inputs to Searchable Context"
  by Daniela Pavlenco, Developer Advocate, Oracle, published October 12, 2026 on the Oracle
  Developers Blog:
  https://blogs.oracle.com/developers/image-aware-ai-agent-memory-from-visual-inputs-to-searchable-context

  The article's companion notebook (oracle-devrel/oracle-ai-developer-hub,
  notebooks/agent_memory/oracle_agent_memory_image_aware_memory.ipynb) is also the work of the
  Oracle Developer Relations team.

  The core ideas in this skill originate from Daniela Pavlenco's article: images persisted as
  managed DOCUMENT records, text-based (description/caption) image search rather than pixel
  similarity, default omission of raw bytes on readback with explicit hydration via
  include_bytes=True, ordered text-plus-image message content, and the reminder that metadata
  scoping is not authorization. The workflow structure, sample scenario, SQL, code examples, and
  all prose here were independently written and are not reproduced from the original post.
-->

# Image-Aware Agent Memory with Oracle AI Agent Memory

## What you are doing here

You are giving an agent memory for visual evidence — a screenshot a customer attached, a receipt,
a form, a product photo — so a later turn or a later session can find it again. Oracle AI Agent
Memory 26.8 stores the image bytes in Oracle AI Database as a record in its managed `DOCUMENT`
table. What makes the image *findable* is **text you attach to it** (a description or caption),
not the pixels. What keeps retrieval *light* is that raw bytes are **left out unless you ask**.

Follow the steps in order. Do not report success until Step 7 is done.

---

## Mental model

| Concern | How it works | Consequence |
|---|---|---|
| Persistence | Image stored as a managed `DOCUMENT` row (`document_type = image`) with bytes, MIME type, description, metadata, status | Durable across sessions; not a temp upload or local file |
| Searchability | The description or caption is the searchable representation | A vague description means an image nobody can find |
| Default readback | Raw bytes are omitted (`bytes` is `None`) | Normal search and list calls stay small and safe to pass around |
| Hydration | Request bytes with `include_bytes=True` | Only do this when you will render, forward, or inspect the original |
| Messages | Message content can be an ordered list of text and image parts | Keeps the image tied to the exact turn it arrived with |

**Search is text-based, not visual.** Searching "red error banner" finds an image only if its
description or caption says so. Image-to-image or pixel-similarity lookup is not what this feature
does.

---

## Step 1 — Confirm prerequisites

- Python package `oracleagentmemory` at release **26.8 or later** (`pip show oracleagentmemory`).
  Do not assume image methods exist on older releases.
- A connection pool to an Oracle AI Database the memory store can use (Autonomous AI Database or
  another Oracle AI Database environment). Read credentials from environment variables or a secret
  manager, never from source files.
- An embedder, because the store runs with vector search over the text representation.

The exact import paths and the construction of the `memory` and `thread` objects are in the Oracle
AI Agent Memory documentation for your release; look them up rather than guessing. The snippets
below assume `memory` and `thread` already exist.

---

## Step 2 — Initialize the store with a deliberate schema policy

The managed schema is created by the library, so decide who is allowed to change the database:

```python
# Illustrative: confirm exact names and imports in the oracleagentmemory docs for your release.
policy = (
    SchemaPolicy.REQUIRE_EXISTING            # production: schema changes are a deliberate act
    if SCHEMA_ALREADY_PROVISIONED
    else SchemaPolicy.CREATE_IF_NECESSARY    # dev/tutorial: the DB user may create objects
)

store = OracleDBMemoryStore(
    pool=db_pool,
    embedder=embedder,
    memory_store_id=MEMORY_STORE_ID,
    schema_policy=policy,
    search_strategy=SearchStrategy.VECTOR,
    vector_dim=EMBEDDING_DIMENSION,          # must match the embedder's output size
)
```

Rule of thumb: `CREATE_IF_NECESSARY` while experimenting, `REQUIRE_EXISTING` at production startup.

---

## Step 3 — Write the description before you write the code

The description is the only handle search has on the image, so treat it as the image's index entry.
Include what the image *shows*, the entities and values a future question might mention, and the
situation it belongs to:

| Weak | Strong |
|---|---|
| `"screenshot"` | `"Checkout page showing a payment-gateway timeout banner; order total 84.20 EUR; region eu-frankfurt-1; captured during support case 7731"` |
| `"receipt"` | `"Hotel receipt, 3 nights, total 412.00 USD, issued 2026-09-14, for expense report ER-2209"` |

The description can be written by the user, by your application, or by a vision-capable model your
workflow calls before storing. If a model writes it, store the model's output as the description —
and treat it as unverified text that can be wrong.

---

## Step 4 — Store a standalone image record

Use this when the image is evidence on its own, not part of a conversation turn:

```python
image_id = await memory.add_image_async(
    image=png_bytes,
    description=description,
    mime_type=ImageMimeType.PNG,
    image_id="case-7731-checkout-error",
    user_id=user_id,
    agent_id=agent_id,
    metadata={
        "case_id": "7731",
        "image_id": "case-7731-checkout-error",
        "tenant": tenant_id,
        "kind": "screenshot",
    },
)
```

Put every dimension you will later filter on into `metadata` — case, tenant, workflow, document
kind. Use a stable, meaningful `image_id` so you can address the record again.

---

## Step 5 — Or attach the image to a message

Use this when the image belongs to a specific conversation turn. Message content is an ordered
list; keep the text part before the image part so the stored turn reads the way the user sent it:

```python
content = [
    TextContent(text="Here is the error I see at checkout.")._to_dict(),
    ImageContent(
        bytes=png_bytes,
        mime_type=ImageMimeType.PNG,
        description=description,
    )._to_dict(),
]

message_ids = await thread.add_messages_async([{"role": "user", "content": content}])
```

Note: the source notebook builds the parts with `_to_dict()`. Check the documentation for your
release to see whether a public equivalent exists before depending on a leading-underscore method.

The image is persisted as its own `DOCUMENT` row linked to the message ID, so it is searchable
exactly like a standalone image.

---

## Step 6 — Search, then read back, then hydrate only if needed

**Search with natural language, restricted to image records and scoped:**

```python
hits = await memory.search_async(
    query="screenshot showing a payment timeout at checkout in Frankfurt",
    record_types=["image"],
    user_id=user_id,
    agent_id=agent_id,
    metadata_filter={"case_id": "7731"},
    max_results=5,
)
```

Always pass a `metadata_filter` when you know the case, tenant, or image ID. Without it, older
images in the same store that resemble the query can match and pollute the result.

**Default readback returns no bytes:**

```python
records = await memory.list_images_async(
    image_id=image_id, user_id=user_id, agent_id=agent_id,
    include_bytes=False,          # bytes come back as None — this is expected
)
```

**Hydrate only when you will actually use the original:**

```python
records = await memory.list_images_async(
    image_id=image_id, user_id=user_id, agent_id=agent_id,
    include_bytes=True,
)
```

Request bytes only when (a) the application will render, forward, or inspect the image, **and**
(b) the caller is authorized to see it. Print a short summary (length, MIME type), never the raw
payload, in logs and notebooks.

---

## Step 7 — Validate before reporting success

1. **Row exists.** Confirm in the database that the record is an image with real bytes. Replace the
   table name with your store's managed `DOCUMENT` table:

   ```sql
   select record_id,
          document_type,
          description,
          dbms_lob.getlength(blob) as byte_length,
          status,
          json_serialize(metadata returning varchar2(4000)) as metadata_json
   from   <your_store_prefix>_document
   where  record_id = :record_id;
   ```

   Expect `document_type = 'image'` and `byte_length > 0`.

2. **Search finds it.** Run a natural-language query that paraphrases the description (not a copy of
   it) and confirm the image is in the results.
3. **Default readback is light.** Confirm `bytes` is `None` with `include_bytes=False`.
4. **Hydration works.** Confirm bytes come back with `include_bytes=True` and the length matches
   the original.
5. **Message path.** For message-attached images, confirm one text part and one image part were
   submitted and exactly one image document is linked to the message ID.
6. If any check could not be run, say so instead of declaring the feature working.

---

## Security and governance

- **Metadata scoping is not authorization.** `user_id`, `agent_id`, case, and tenant values narrow
  what a search returns; they do not decide who may write, search, or hydrate. Enforce access in
  your application and database. For identity-aware enforcement see
  [Skill 28](../28_identity_aware_row_level_security_ai_agents/SKILL.md).
- **Hydration is the sensitive step.** Gate `include_bytes=True` behind an explicit permission
  check and keep it out of generic "recall" tools exposed to an LLM.
- **Descriptions are searchable text and travel through agent context.** Do not put secrets,
  full card numbers, or other data in a description that you would not allow in a prompt.
- **Test data.** For demos and CI, generate a synthetic image instead of using a real customer
  screenshot.
- **Validation limits.** The package validates images before persisting or processing them, with
  configurable limits. Look up the current limits for your release and handle rejections
  (oversized or unsupported files) explicitly instead of retrying blindly.

---

## Common pitfalls

| Symptom | Likely cause | Fix |
|---|---|---|
| `bytes` is `None` after `list_images_async` | Default behavior | Pass `include_bytes=True` only if you truly need the payload |
| The image never shows up in search | Description is vague or missing key terms | Rewrite the description (Step 3) and store again |
| Old demo images appear in results | No metadata filter | Add `metadata_filter` on case, tenant, or `image_id` |
| Searching for "an image that looks like X" returns nothing useful | Search compares text, not pixels | Describe the content in words, or generate a caption at ingest |
| Image attached to a message appears out of order | Parts were not listed in conversation order | Build the content list in the order the user sent it |
| Startup fails against a locked-down database | `CREATE_IF_NECESSARY` without create privileges | Provision the schema first, then use `REQUIRE_EXISTING` |

---

## When to use this versus other memory approaches

| Need | Use |
|---|---|
| Remember screenshots, forms, receipts, or photos across turns and sessions | Image-aware memory (this skill) |
| Remember text facts and conversation history | The text memory path of Oracle AI Agent Memory — see [Skill 11](../11_oracle_ai_database_26ai_unified_memory.md) |
| Retrieve passages from a document corpus | RAG over vector search — see [Skill 08](../08_rag_oracle_ai_vector_search.md) |
| Find images by visual similarity | Not what this feature does; use an image-embedding pipeline in addition |

---

## Non-negotiable rules

- Verify the package release supports image memory before writing code.
- Give every image a specific, searchable description.
- Scope with metadata, and enforce authorization separately.
- Keep `include_bytes=False` unless the original image is needed and the caller is allowed to see it.
- Never claim the workflow works until Step 7 has been run.

---

## Related skills in this repository

- [Skill 01: Oracle AI Vector Search](../01_oracle_ai_vector_search.md)
- [Skill 08: RAG with Oracle AI Vector Search](../08_rag_oracle_ai_vector_search.md)
- [Skill 10: Agentic Workflows with Oracle AI Database](../10_agentic_workflows_oracle_ai_database.md)
- [Skill 11: Oracle AI Database 26ai Unified Memory](../11_oracle_ai_database_26ai_unified_memory.md)
- [Skill 28: Identity-Aware Row-Level Security for AI / MCP Agents](../28_identity_aware_row_level_security_ai_agents/SKILL.md)

---

## References

- [Original article — Image-Aware AI Agent Memory: From Visual Inputs to Searchable Context (Daniela Pavlenco)](https://blogs.oracle.com/developers/image-aware-ai-agent-memory-from-visual-inputs-to-searchable-context)
- [Companion notebook — oracle-devrel/oracle-ai-developer-hub](https://github.com/oracle-devrel/oracle-ai-developer-hub/blob/main/notebooks/agent_memory/oracle_agent_memory_image_aware_memory.ipynb)
- [Oracle AI Agent Memory documentation (26.8)](https://docs.oracle.com/en/database/oracle/agent-memory/26.8/guide/api/agentmemory.html#oracle-agent-memory)
- [Using images with Oracle AI Agent Memory](https://docs.oracle.com/en/database/oracle/agent-memory/26.8/guide/int-use-images.html#GUID-8183F4E2-5696-54C2-995A-D1778D19C01E)
- [oracleagentmemory on PyPI](https://pypi.org/project/oracleagentmemory/)
- [Oracle AI Database 26ai documentation](https://docs.oracle.com/en/database/oracle/oracle-database/26/)

**#OracleAI #AgentMemory #MultimodalAI #AIAgents #OracleAIDatabase #VectorSearch #Oracle26ai #Python**
