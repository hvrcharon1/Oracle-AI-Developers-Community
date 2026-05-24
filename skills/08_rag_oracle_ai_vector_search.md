# Skill 08: RAG with Oracle AI Vector Search

**Category:** AI | RAG | **Level:** Intermediate

---

## Overview

Retrieval-Augmented Generation (RAG) combines semantic search with LLM generation to answer questions grounded in your own documents. Oracle AI Vector Search makes Oracle Database a fully capable RAG vector store — keeping your documents, embeddings, and business data in one system with SQL-accessible retrieval.

---

## RAG Architecture with Oracle

```
User Question
     │
     ▼
Generate Query Embedding (OCI GenAI)
     │
     ▼
Vector Similarity Search (Oracle AI Vector Search)
     │
     ▼
Retrieve Top-K Relevant Chunks
     │
     ▼
Build Prompt: [System] + [Retrieved Chunks] + [User Question]
     │
     ▼
LLM Generation (OCI GenAI / OpenAI)
     │
     ▼
Grounded Answer
```

---

## Step-by-Step

### 1. Set Up the Document Store Table

```sql
CREATE TABLE rag_documents (
  doc_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  title       VARCHAR2(500),
  chunk_text  CLOB,
  chunk_index NUMBER,
  source_url  VARCHAR2(1000),
  embedding   VECTOR(1024, FLOAT32)
);

CREATE VECTOR INDEX rag_hnsw_idx
  ON rag_documents (embedding)
  ORGANIZATION INMEMORY NEIGHBOR GRAPH
  DISTANCE COSINE
  WITH TARGET ACCURACY 95;
```

### 2. Chunk and Embed Documents (Python)

```python
import oci
import oracledb

def chunk_text(text, chunk_size=500, overlap=50):
    words = text.split()
    chunks = []
    for i in range(0, len(words), chunk_size - overlap):
        chunks.append(' '.join(words[i:i + chunk_size]))
    return chunks

def embed_chunks(client, compartment_id, chunks):
    response = client.embed_text(
        embed_text_details=oci.generative_ai_inference.models.EmbedTextDetails(
            compartment_id=compartment_id,
            model_id='cohere.embed-english-v3.0',
            inputs=chunks,
            input_type='SEARCH_DOCUMENT'
        )
    )
    return response.data.embeddings

# Insert into Oracle
def insert_chunks(conn, title, chunks, embeddings, source_url):
    with conn.cursor() as cur:
        cur.executemany(
            "INSERT INTO rag_documents (title, chunk_text, chunk_index, source_url, embedding) "
            "VALUES (:1, :2, :3, :4, :5)",
            [(title, chunk, i, source_url, emb) for i, (chunk, emb) in enumerate(zip(chunks, embeddings))]
        )
    conn.commit()
```

### 3. Retrieve Relevant Chunks at Query Time

```sql
-- Find top 5 most relevant chunks for a query embedding
SELECT doc_id, title, chunk_text, source_url,
       VECTOR_DISTANCE(embedding, :query_embedding, COSINE) AS score
FROM   rag_documents
ORDER BY score
FETCH FIRST 5 ROWS ONLY;
```

### 4. Generate the Final Answer (Python)

```python
def rag_query(user_question, conn, genai_client, compartment_id):
    # Embed the question
    q_embed = embed_chunks(genai_client, compartment_id, [user_question])[0]

    # Retrieve top chunks from Oracle
    with conn.cursor() as cur:
        cur.execute("""
            SELECT chunk_text FROM rag_documents
            ORDER BY VECTOR_DISTANCE(embedding, :1, COSINE)
            FETCH FIRST 5 ROWS ONLY
        """, [q_embed])
        chunks = [row[0] for row in cur.fetchall()]

    context = "\n---\n".join(chunks)
    prompt = f"""Use the following context to answer the question.\n\nContext:\n{context}\n\nQuestion: {user_question}\n\nAnswer:"""

    response = genai_client.chat(
        chat_details=oci.generative_ai_inference.models.CohereChatDetails(
            compartment_id=compartment_id,
            model_id='cohere.command-r-plus',
            message=prompt,
            max_tokens=800
        )
    )
    return response.data.chat_response.text
```

---

## Best Practices

- Chunk at **paragraph or section boundaries** rather than fixed word counts when possible
- Store **source metadata** (URL, document title, section heading) for citation in answers
- Use **hybrid retrieval**: combine vector similarity with keyword/BM25 for better recall
- Add a **reranking step** using a cross-encoder model before passing chunks to the LLM

---

## Related Skills

- [Skill 01: Oracle AI Vector Search](01_oracle_ai_vector_search.md)
- [Skill 07: OCI Generative AI Service](07_oci_generative_ai_service.md)

**#RAG #OracleAI #VectorSearch #GenerativeAI #LLM #EnterpriseAI**
