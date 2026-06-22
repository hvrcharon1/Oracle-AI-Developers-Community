# Skill 14 — Oracle Machine Learning (OML) AutoML In-Database

> **Capability:** Train, evaluate, and deploy machine learning models entirely inside Oracle Database — no Python infrastructure, no data export, no model server.

---

## What It Is

**Oracle Machine Learning (OML)** brings AutoML, explainability, and model deployment natively into the Oracle Database engine via the `DBMS_DATA_MINING` PL/SQL package and the OML4Py/OML4SQL APIs. Models train on data where it lives, predictions run as SQL functions, and there is zero latency from model serving because the model *is* the database.

With **OML AutoML UI** (built into APEX and OML Notebooks), non-ML experts can train production-quality models in minutes.

---

## In-Database ML Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Oracle Database 23ai                      │
│                                                             │
│  ┌───────────────┐    ┌────────────────┐    ┌───────────┐  │
│  │  Training     │    │  Model Store   │    │ Scoring   │  │
│  │  Data (SQL)   │───▶│  (DM$MODEL)   │───▶│ PREDICTION│  │
│  └───────────────┘    └────────────────┘    │ SQL Func  │  │
│                                             └───────────┘  │
│  DBMS_DATA_MINING  ◀──  AutoML  ──▶  OML Notebooks         │
└─────────────────────────────────────────────────────────────┘
```

---

## Hands-On: Train a Churn Prediction Model

### 1. Prepare Training View

```sql
CREATE OR REPLACE VIEW customer_features_v AS
SELECT
  c.cust_id,
  c.age,
  c.tenure_months,
  c.monthly_spend,
  COUNT(t.txn_id)         AS txn_count_90d,
  SUM(t.amount)           AS txn_vol_90d,
  MAX(t.txn_date)         AS last_txn_date,
  SYSDATE - MAX(t.txn_date) AS days_since_last_txn,
  c.churn_flag            -- target: 1=churned, 0=active
FROM customers c
LEFT JOIN transactions t
  ON t.cust_id = c.cust_id
  AND t.txn_date >= SYSDATE - 90
GROUP BY c.cust_id, c.age, c.tenure_months,
         c.monthly_spend, c.churn_flag;
```

### 2. Set Model Settings

```sql
BEGIN
  DELETE FROM churn_model_settings;

  INSERT INTO churn_model_settings VALUES
    (dbms_data_mining.algo_name,
     dbms_data_mining.algo_random_forest);

  INSERT INTO churn_model_settings VALUES
    (dbms_data_mining.prep_auto,
     dbms_data_mining.prep_auto_on);

  INSERT INTO churn_model_settings VALUES
    (dbms_data_mining.clas_weights_balanced,
     dbms_data_mining.clas_weights_balanced_on);

  COMMIT;
END;
/
```

### 3. Train the Model

```sql
BEGIN
  DBMS_DATA_MINING.CREATE_MODEL2(
    model_name          => 'CHURN_RF_MODEL',
    mining_function     => DBMS_DATA_MINING.CLASSIFICATION,
    data_query          => 'SELECT * FROM customer_features_v',
    set_list            => DBMS_DATA_MINING.SETTING_LIST(
                             'ALGO_NAME' =>
                             DBMS_DATA_MINING.ALGO_RANDOM_FOREST
                           ),
    case_id_column_name => 'CUST_ID',
    target_column_name  => 'CHURN_FLAG'
  );
END;
/
```

### 4. Score New Customers Inline in SQL

```sql
SELECT
  cust_id,
  name,
  PREDICTION(churn_rf_model USING *) AS predicted_churn,
  ROUND(PREDICTION_PROBABILITY(
    churn_rf_model, 1 USING *
  ) * 100, 1)                        AS churn_probability_pct,
  PREDICTION_DETAILS(
    churn_rf_model USING *
  )                                  AS top_drivers_xml
FROM customer_features_v
ORDER BY churn_probability_pct DESC
FETCH FIRST 50 ROWS ONLY;
```

### 5. AutoML — Let Oracle Choose the Best Algorithm

```sql
-- OML AutoML via PL/SQL (23ai+)
BEGIN
  DBMS_DATA_MINING.CREATE_MODEL2(
    model_name          => 'CHURN_AUTO_MODEL',
    mining_function     => DBMS_DATA_MINING.CLASSIFICATION,
    data_query          => 'SELECT * FROM customer_features_v',
    set_list            => DBMS_DATA_MINING.SETTING_LIST(
                             'ALGO_NAME' =>
                             DBMS_DATA_MINING.ALGO_AUTOML
                           ),
    case_id_column_name => 'CUST_ID',
    target_column_name  => 'CHURN_FLAG'
  );
END;
/
-- Oracle tries GLM, RF, XGBoost, SVM, Neural Net internally
-- and selects the champion model automatically
```

---

## Model Explainability

```sql
-- Global feature importance
SELECT *
FROM   TABLE(
  DBMS_DATA_MINING.GET_MODEL_DETAILS_GLOBAL('CHURN_RF_MODEL')
)
ORDER BY attribute_rank;

-- SHAP-style local explanation for one customer
SELECT XMLQUERY(
         '//ATTRIBUTE[RANK<=5]'
         PASSING PREDICTION_DETAILS(churn_rf_model USING *)
         RETURNING CONTENT
       ) AS top_5_drivers
FROM customer_features_v
WHERE cust_id = 42;
```

---

## Integrate with AI Vector Search (Hybrid ML)

```sql
-- Combine OML churn score + vector similarity for targeted offers
SELECT
  c.cust_id,
  PREDICTION_PROBABILITY(churn_rf_model, 1 USING c.*) AS churn_prob,
  VECTOR_DISTANCE(
    c.embedding,
    (SELECT embedding FROM product_catalog WHERE prod_id = 99),
    COSINE
  ) AS product_affinity
FROM customers c
WHERE PREDICTION(churn_rf_model USING c.*) = 1
ORDER BY churn_prob DESC, product_affinity ASC;
```

---

## References

- [Oracle OML Docs](https://docs.oracle.com/en/database/oracle/machine-learning/)
- [DBMS_DATA_MINING PL/SQL Reference](https://docs.oracle.com/en/database/oracle/oracle-database/23/arpls/DBMS_DATA_MINING.html)
- [OML Notebooks (ADB Cloud)](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/use-oml-notebooks.html)
- [OML AutoML UI Tutorial](https://apexapps.oracle.com/pls/apex/r/dbpm/livelabs/view-workshop?wid=786)
