# Skill 02: Select AI — Natural Language to SQL

**Category:** AI | **Level:** Beginner

---

## Overview

Select AI is a built-in Oracle Database feature that translates natural language questions into SQL queries and executes them — no middleware, no custom code. You configure an AI profile pointing to an LLM (OCI Generative AI, OpenAI, etc.), and then use special SQL syntax to ask questions in plain English.

---

## Key Concepts

- **AI Profile**: A named configuration that links an LLM provider, credentials, and database schema metadata
- **DBMS_CLOUD_AI**: The PL/SQL package used to create and manage AI profiles
- **SELECT AI syntax**: Special SQL clauses (`NARRATE`, `SHOWSQL`, `RUNSQL`) that route queries through an LLM

---

## Step-by-Step

### 1. Create OCI Generative AI Credentials

```sql
BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
    credential_name => 'OCI_GENAI_CRED',
    user_ocid       => 'ocid1.user.oc1...',
    tenancy_ocid    => 'ocid1.tenancy.oc1...',
    private_key     => '<your-pem-private-key>',
    fingerprint     => '<your-key-fingerprint>'
  );
END;
/
```

### 2. Create an AI Profile

```sql
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'SALES_AI',
    attributes   => '{
      "provider": "oci",
      "credential_name": "OCI_GENAI_CRED",
      "model": "meta.llama-3-70b-instruct",
      "object_list": [
        {"owner": "SALES", "name": "CUSTOMERS"},
        {"owner": "SALES", "name": "ORDERS"},
        {"owner": "SALES", "name": "PRODUCTS"}
      ]
    }'
  );
END;
/
```

### 3. Set the Active Profile for Your Session

```sql
BEGIN
  DBMS_CLOUD_AI.SET_PROFILE(profile_name => 'SALES_AI');
END;
/
```

### 4. Query in Natural Language

```sql
-- Show generated SQL without running it
SELECT AI SHOWSQL 'What were the top 5 customers by order value last quarter?';

-- Run the query and return results
SELECT AI RUNSQL 'What were the top 5 customers by order value last quarter?';

-- Return a natural language narrative answer
SELECT AI NARRATE 'Summarize sales performance by region for 2024.';
```

---

## Tips

- Include **table comments and column comments** in your schema — Select AI uses them to improve query accuracy
- Use `SHOWSQL` to review generated SQL before running it in production
- Limit the `object_list` to only the tables relevant to a use case to reduce hallucination risk
- You can create **multiple profiles** for different departments or use cases

---

## Related Skills

- [Skill 04: Building AI Agents with DBMS_CLOUD_AI_AGENT](04_building_ai_agents_dbms_cloud_ai_agent.md)
- [Skill 07: OCI Generative AI Service](07_oci_generative_ai_service.md)

**#SelectAI #OracleAI #NaturalLanguageSQL #DBMS_CLOUD_AI #OCI**
