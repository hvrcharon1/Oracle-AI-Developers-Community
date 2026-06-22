# Skill 12 — JSON Relational Duality Views (Oracle 23ai)

> **Capability:** Access the same normalized relational data simultaneously as JSON documents and SQL rows — without duplication, triggers, or synchronization.

---

## What It Is

JSON Relational Duality Views, introduced in Oracle 23ai, are one of the most architecturally significant features Oracle has ever shipped. A single **Duality View** lets you:

- **Read** data as JSON documents (REST, ORDS, SODA, Python, Node.js)
- **Write** full JSON documents back — Oracle handles decomposition into underlying normalized tables
- **Query** with SQL on the same rows, no data movement required

This eliminates the long-standing tradeoff between developer-friendly document APIs and DBA-friendly relational schemas.

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│             Duality View (ORDERS_DV)            │
│  ┌───────────────────┐  ┌─────────────────────┐ │
│  │  JSON Document    │  │   Relational SQL     │ │
│  │  (REST / SODA)    │  │   (SELECT / DML)     │ │
│  └────────┬──────────┘  └──────────┬──────────┘ │
│           └──────────┬─────────────┘            │
│                      ▼                           │
│         ┌────────────────────────────┐           │
│         │  Underlying Tables         │           │
│         │  ORDERS  ←→  ORDER_ITEMS  │           │
│         │  CUSTOMERS                │           │
│         └────────────────────────────┘           │
└─────────────────────────────────────────────────┘
```

---

## Hands-On: Create a Duality View

### 1. Base Tables

```sql
CREATE TABLE customers (
  cust_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       VARCHAR2(100) NOT NULL,
  email      VARCHAR2(200) UNIQUE
);

CREATE TABLE orders (
  order_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cust_id    NUMBER REFERENCES customers(cust_id),
  order_date DATE DEFAULT SYSDATE,
  status     VARCHAR2(20) DEFAULT 'PENDING'
);

CREATE TABLE order_items (
  item_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id   NUMBER REFERENCES orders(order_id),
  product    VARCHAR2(200),
  qty        NUMBER,
  price      NUMBER(10,2)
);
```

### 2. Define the Duality View

```sql
CREATE OR REPLACE JSON RELATIONAL DUALITY VIEW orders_dv AS
  orders @INSERT @UPDATE @DELETE
  {
    _id       : order_id,
    orderDate : order_date,
    status    : status,
    customer  : customers @JOIN (cust_id)
    {
      customerId : cust_id,
      name       : name,
      email      : email
    },
    items : order_items @INSERT @UPDATE @DELETE
    {
      itemId  : item_id,
      product : product,
      qty     : qty,
      price   : price
    }
  };
```

### 3. Insert via JSON Document

```sql
INSERT INTO orders_dv VALUES (
  '{"orderDate":"2025-06-01","status":"NEW",
    "customer":{"name":"Harshal Rasal","email":"hr@datacules.io"},
    "items":[
      {"product":"AgentDB Pro License","qty":1,"price":999.00}
    ]}'
);
COMMIT;
```

Oracle automatically inserts rows into `customers`, `orders`, and `order_items` — normalized and consistent.

### 4. Query as SQL

```sql
SELECT o.order_id, c.name, i.product, i.price
FROM   orders o
JOIN   customers c ON c.cust_id = o.cust_id
JOIN   order_items i ON i.order_id = o.order_id;
```

### 5. Query as JSON (ORDS REST endpoint)

```bash
curl -X GET \
  'https://<your-adb>.adb.us-phoenix-1.oraclecloudapps.com/ords/hr/orders_dv/' \
  -H 'Authorization: Bearer <token>'
```

Returns each order as a rich nested JSON document with embedded customer and items.

---

## AI + Duality Views

Use SELECT AI to query the view in plain English:

```sql
SELECT AI 'Show all pending orders placed by customers from Nagpur
            along with total order value'
FROM   orders_dv;
```

Because the AI sees a unified JSON schema, it can generate sophisticated JOIN-free queries.

---

## Key Benefits

| Concern | Before Duality Views | After |
|---|---|---|n| Data model | Choose: relational OR document | Both simultaneously |
| Sync | Triggers / ETL pipelines | Zero — single source of truth |
| REST API | Manual ORDS mapping | Auto-generated from view definition |
| AI queries | Fragmented schemas confuse LLMs | One coherent JSON schema |

---

## References

- [Oracle Docs — JSON-Relational Duality](https://docs.oracle.com/en/database/oracle/oracle-database/23/jsnvu/)
- [LiveLab: JSON Duality Views](https://apexapps.oracle.com/pls/apex/f?p=133:180:::::wid:3853)
- Oracle 23ai Free: [container.registry.oracle.com/database/free:latest](https://container-registry.oracle.com)
