# Skill 23 — DBMS_VECTOR_CHAIN: Document Chunking & Text Processing for RAG

> **Capability:** Ingest, chunk, embed, and stage unstructured documents inside Oracle Database using the built-in `DBMS_VECTOR_CHAIN` PL/SQL package — no external pre-processing pipeline required.

---

## What It Is

`DBMS_VECTOR_CHAIN` (introduced in Oracle AI Database 23ai) is an in-database utility that handles the full document-to-vector lifecycle:

| Stage | Function |
|---|---|
| **Load** | Read from BLOB, CLOB, or OCI Object Storage |
| **Split / Chunk** | Paragraph, sentence, or fixed-size chunking |
| **Embed** | Call an OCI Generative AI embedding model |
| **Store** | Insert chunks + embeddings into a vector table |

---

## Prerequisites

- Oracle AI Database 23ai or later (on-premises or Autonomous)
- OCI Generative AI credential created in the schema
- A table with a `VECTOR` column (e.g., `doc_chunks`)

---

## Quick Start

### 1 — Create the target table

```sql
CREATE TABLE doc_chunks (
    chunk_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    doc_name   VARCHAR2(400),
    chunk_text CLOB,
    embedding  VECTOR
);
```

### 2 — Create the OCI Generative AI credential

```sql
BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
      credential_name => 'OCI_GENAI_CRED',
      user_ocid       => 'ocid1.user.oc1...',
      tenancy_ocid    => 'ocid1.tenancy.oc1...',
      private_key     => '<base64-encoded-pem>',
      fingerprint     => 'aa:bb:cc:...'
  );
END;
/
```

### 3 — Load, chunk, embed, and store in one pipeline

```sql
DECLARE
    l_doc_clob  CLOB := 'Paste or fetch your document text here...';
    l_params    CLOB := '{
        "by"         : "words",
        "max"        : 300,
        "overlap"    : 30,
        "split"      : "recursively",
        "model"      : "cohere.embed-multilingual-v3.0",
        "credential" : "OCI_GENAI_CRED",
        "endpoint"   : "https://inference.ai.us-chicago-1.oci.oraclecloud.com"
    }';
BEGIN
    INSERT INTO doc_chunks (doc_name, chunk_text, embedding)
    SELECT 'my_document',
           et.embed_data,
           et.embed_vector
    FROM   dbms_vector_chain.utl_to_embeddings(
               dbms_vector_chain.utl_to_chunks(
                   dbms_vector_chain.utl_to_text(l_doc_clob),
                   json(l_params)
               ),
               json(l_params)
           ) et;
    COMMIT;
END;
/
```

---

## Chunking Strategies

| Strategy | `"by"` value | Best For |
|---|---|---|
| Word-based | `"words"` | General prose |
| Sentence | `"sentence"` | Q&A over structured content |
| Paragraph | `"paragraph"` | Dense technical documents |
| Fixed characters | `"chars"` | Predictable token budgets |

---

## Query the Chunk Store (RAG Retrieval)

```sql
-- Retrieve the 5 most relevant chunks for a query embedding
SELECT chunk_id,
       chunk_text,
       VECTOR_DISTANCE(embedding, :query_vector, COSINE) AS similarity
FROM   doc_chunks
ORDER BY similarity ASC
FETCH FIRST 5 ROWS ONLY;
```

---

## Batch-Processing Multiple Documents

```sql
DECLARE
    CURSOR c_docs IS
        SELECT doc_id, content_clob FROM raw_documents WHERE processed = 'N';
    l_params CLOB := '{"by":"words","max":300,"overlap":30,...}';
BEGIN
    FOR rec IN c_docs LOOP
        INSERT INTO doc_chunks (doc_name, chunk_text, embedding)
        SELECT rec.doc_id,
               et.embed_data,
               et.embed_vector
        FROM   dbms_vector_chain.utl_to_embeddings(
                   dbms_vector_chain.utl_to_chunks(
                       dbms_vector_chain.utl_to_text(rec.content_clob),
                       json(l_params)
                   ),
                   json(l_params)
               ) et;

        UPDATE raw_documents SET processed = 'Y' WHERE doc_id = rec.doc_id;
        COMMIT;
    END LOOP;
END;
/
```

---

## Key Tips

- Use `overlap` (10–30 words) to prevent context loss at chunk boundaries.
- Set `max` to stay below the embedding model's token limit (typically 512 tokens).
- Index the `embedding` column with `CREATE VECTOR INDEX` for datasets > 100 k chunks.
- Chain with `DBMS_VECTOR_CHAIN.UTL_TO_SUMMARY` to auto-summarize each chunk before embedding for meta-RAG pipelines.
- For PDF or Office files stored as BLOBs, `UTL_TO_TEXT` handles extraction automatically on Autonomous Database.

---

## References

- [Oracle Docs — DBMS_VECTOR_CHAIN](https://docs.oracle.com/en/database/oracle/oracle-database/23/arpls/dbms_vector_chain.html)
- [Oracle AI Vector Search Developer Guide](https://docs.oracle.com/en/database/oracle/oracle-database/23/vecse/overview-ai-vector-search.html)
