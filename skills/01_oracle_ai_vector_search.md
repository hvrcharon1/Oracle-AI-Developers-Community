# Skill 01: Oracle AI Vector Search

**Category:** Database | **Level:** Beginner–Intermediate

---

## Overview

Oracle AI Vector Search is a native capability of Oracle Database 23ai and 26ai that allows you to store vector embeddings alongside relational data and run similarity searches using SQL. Unlike standalone vector databases, Oracle keeps your vectors, metadata, and business data in one place — enabling hybrid queries that combine semantic similarity with traditional filters.

---

## Key Concepts

- **Vector**: A numerical array (embedding) that represents the semantic meaning of text, image, or other content
- **VECTOR data type**: Oracle's native column type for storing embeddings (e.g., `VECTOR(1536, FLOAT32)`)
- **Vector Index**: An approximate nearest-neighbour (ANN) index (IVF or HNSW) for fast similarity search
- **Distance metrics**: `COSINE`, `EUCLIDEAN`, `DOT` — choose based on your embedding model

---

## Step-by-Step

### 1. Create a Table with a Vector Column

```sql
CREATE TABLE knowledge_base (
  id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  content     CLOB,
  source      VARCHAR2(500),
  category    VARCHAR2(100),
  embedding   VECTOR(1536, FLOAT32)
);
```

### 2. Generate and Insert Embeddings

Use `DBMS_VECTOR.UTL_TO_EMBEDDING` to generate embeddings inline using an OCI-hosted model:

```sql
INSERT INTO knowledge_base (content, source, category, embedding)
VALUES (
  'Oracle Autonomous Database automatically tunes itself using machine learning.',
  'oracle-docs',
  'database',
  DBMS_VECTOR.UTL_TO_EMBEDDING(
    'Oracle Autonomous Database automatically tunes itself using machine learning.',
    JSON_OBJECT('provider' VALUE 'OCIGenAI', 'model' VALUE 'cohere.embed-english-v3.0')
  )
);
```

### 3. Create a Vector Index

```sql
-- HNSW index (best for high-recall, low-latency queries)
CREATE VECTOR INDEX knowledge_base_hnsw_idx
  ON knowledge_base (embedding)
  ORGANIZATION INMEMORY NEIGHBOR GRAPH
  DISTANCE COSINE
  WITH TARGET ACCURACY 95;
```

### 4. Run a Similarity Search

```sql
SELECT id, content, source,
       VECTOR_DISTANCE(embedding, :query_vector, COSINE) AS similarity_score
FROM   knowledge_base
ORDER BY similarity_score
FETCH FIRST 5 ROWS ONLY;
```

### 5. Hybrid Search — Combine Vector + Relational Filters

```sql
SELECT id, content, source,
       VECTOR_DISTANCE(embedding, :query_vector, COSINE) AS score
FROM   knowledge_base
WHERE  category = 'database'
  AND  VECTOR_DISTANCE(embedding, :query_vector, COSINE) < 0.3
ORDER BY score
FETCH FIRST 10 ROWS ONLY;
```

---

## Best Practices

- Use **HNSW** indexes for interactive queries; use **IVF** for large batch workloads
- Always store the **source text** alongside the embedding — you will need it for RAG
- Choose the distance metric that **matches your embedding model's training objective**
- Use **partitioning** on large vector tables to improve manageability and query performance

---

## Related Skills

- [Skill 08: RAG with Oracle AI Vector Search](08_rag_oracle_ai_vector_search.md)
- [Skill 02: Select AI — Natural Language to SQL](02_select_ai_natural_language_to_sql.md)

**#OracleAI #VectorSearch #Oracle23ai #Oracle26ai #AIDatabase**
