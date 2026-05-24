# Skill 07: OCI Generative AI Service — Getting Started

**Category:** OCI | AI | **Level:** Beginner–Intermediate

---

## Overview

OCI Generative AI is Oracle Cloud Infrastructure's managed service for hosting and calling large language models. It provides API access to models from Cohere, Meta (Llama), and Oracle's own models — with enterprise security, data residency controls, and OCI-native IAM authentication. It is the LLM backbone for Select AI, APEX AI Assistant, and Oracle AI Vector Search embedding generation.

---

## Available Model Families (as of 2026)

| Model | Provider | Best For |
|---|---|---|
| `cohere.command-r-plus` | Cohere | RAG, long-context reasoning |
| `cohere.embed-english-v3.0` | Cohere | Text embeddings for vector search |
| `meta.llama-3-70b-instruct` | Meta | General chat, code, SQL generation |
| `meta.llama-3-8b-instruct` | Meta | Lightweight, low-latency tasks |
| `oracle.automl` | Oracle | Oracle-optimised inference |

---

## Step-by-Step

### 1. Set Up IAM Policies

In OCI Console → **Identity & Security** → **Policies**, create:

```
Allow group <your-group> to use generative-ai-family in compartment <compartment-name>
```

### 2. Call the API with Python (OCI SDK)

```python
import oci

config = oci.config.from_file()  # Uses ~/.oci/config
client = oci.generative_ai_inference.GenerativeAiInferenceClient(config=config)

response = client.chat(
    chat_details=oci.generative_ai_inference.models.CohereChatDetails(
        compartment_id="ocid1.compartment.oc1...",
        model_id="cohere.command-r-plus",
        chat_history=[],
        message="Explain Oracle AI Vector Search in simple terms.",
        max_tokens=500
    )
)

print(response.data.chat_response.text)
```

### 3. Generate Embeddings

```python
response = client.embed_text(
    embed_text_details=oci.generative_ai_inference.models.EmbedTextDetails(
        compartment_id="ocid1.compartment.oc1...",
        model_id="cohere.embed-english-v3.0",
        inputs=["Oracle Database supports vector similarity search natively."],
        input_type="SEARCH_DOCUMENT"
    )
)

embedding = response.data.embeddings[0]
print(f"Embedding dimension: {len(embedding)}")
```

### 4. Call OCI GenAI from Inside Oracle Database

Using `DBMS_CLOUD.SEND_REQUEST`:

```sql
DECLARE
  l_response CLOB;
BEGIN
  l_response := DBMS_CLOUD.SEND_REQUEST(
    credential_name => 'OCI_GENAI_CRED',
    uri             => 'https://inference.generativeai.<region>.oci.oraclecloud.com/20231130/actions/chat',
    method          => 'POST',
    body            => UTL_RAW.CAST_TO_RAW(JSON_OBJECT(
      'compartmentId' VALUE 'ocid1.compartment.oc1...',
      'servingMode' VALUE JSON_OBJECT(
        'modelId' VALUE 'meta.llama-3-70b-instruct',
        'servingType' VALUE 'ON_DEMAND'
      ),
      'chatRequest' VALUE JSON_OBJECT(
        'messages' VALUE JSON_ARRAY(JSON_OBJECT('role' VALUE 'USER', 'content' VALUE 'Hello!')),
        'maxTokens' VALUE 200
      )
    ))
  );
  DBMS_OUTPUT.PUT_LINE(l_response);
END;
/
```

---

## Best Practices

- Use **OCI Instance Principals** for compute-hosted apps to avoid managing API keys
- Cache embeddings in Oracle Database — regenerating them for every query is costly
- Set `max_tokens` conservatively during development to control costs
- Use **dedicated AI clusters** for production workloads requiring guaranteed throughput

---

## Related Skills

- [Skill 01: Oracle AI Vector Search](01_oracle_ai_vector_search.md)
- [Skill 08: RAG with Oracle AI Vector Search](08_rag_oracle_ai_vector_search.md)

**#OCI #GenerativeAI #LLM #Cohere #MetaLlama #OracleCloud**
