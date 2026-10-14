---
name: oracle-graphql-table-function
description: >
  Use this skill whenever a task involves querying Oracle AI Database 26ai / Oracle Database 23ai
  relational tables with GraphQL syntax through the SQL GRAPHQL table function: building nested
  JSON documents from tables without hand-writing JSON_OBJECT / JSON_ARRAYAGG, shaping output with
  directives (@link, @unnest, @where, @orderby, @array, @object, @nest, @generated, @alias),
  passing variables with PASSING, or choosing between the GraphQL table function, JSON-relational
  duality views, and ORDS GraphQL. Trigger on "graphql(" appearing in SQL, GraphQL directives on
  Oracle tables, GraphQL-defined duality views, or requests like "return each customer with their
  orders as JSON" straight from SQL. Works with any AI provider or model.
---

<!--
  CREDIT / ATTRIBUTION (kept here as a comment on purpose, not part of the skill body)

  Based on the article "GraphQL in Oracle Database 23ai/26ai" by Tim Hall, ORACLE-BASE (oracle-base.com):
  https://oracle-base.com/articles/23/graphql-23
  Article created 2024-09-29, last updated 2025-11-14.

  The topic coverage (table function, directives, variables, QBE filters, duality-view and ORDS
  relationships) and the documented limitation noted below originate from Tim Hall's article.
  All prose, the sample schema, and every code example in this skill were independently written
  and are not reproduced from the original post.
-->

# GraphQL Table Function in Oracle AI Database (23ai / 26ai)

## What you are doing here

You are shaping relational rows into nested JSON documents by describing the desired document in
GraphQL syntax and running it through the `GRAPHQL` table function from plain SQL. Oracle
translates the GraphQL text into SQL/JSON generation (`JSON_OBJECT`, `JSON_ARRAYAGG`) behind the
scenes, so you get nested results without writing that SQL by hand. Follow the workflow below in
order, and do not report success until Step 6 is done.

**Availability note.** The feature shipped in earlier 23ai releases but was only documented from
Oracle AI Database 26ai (23.26.0). Never assume it exists on the target database — Step 1 checks.

---

## Step 1 — Confirm the target database supports it

```sql
select banner_full from v$version;

-- Smoke test against any table the current user can read
select * from graphql('
t : dual
{
  x : dummy
}');
```

- If the smoke test returns a JSON row, continue.
- If it fails with an invalid-identifier or unknown-function error, stop and tell the user the
  feature is unavailable on this release rather than rewriting the request into something else.

---

## Step 2 — Sketch the JSON you want before writing GraphQL

Write the target document shape first (plain JSON, one example). Then map every key to a column:
the GraphQL selection set *is* that shape. Decide up front:

- Which table is the **root** (one JSON document is returned per root row)?
- Which keys are plain columns, which are **nested arrays** of child rows, which are a single
  nested **object**, and which are **computed**?

---

## Step 3 — Anatomy of a query

Sample schema used throughout this skill (independent of any real application):

```sql
create table customers (
  customer_id  number(6)    constraint pk_customers primary key,
  full_name    varchar2(80) not null,
  city         varchar2(40),
  tier         varchar2(10)
);

create table orders (
  order_id     number(8)    constraint pk_orders primary key,
  customer_id  number(6)    not null
               constraint fk_orders_customer references customers,
  order_date   date         not null,
  amount       number(10,2) not null,
  discount     number(10,2)
);

create index orders_customer_fk_i on orders (customer_id);
```

**Flat document** — `jsonKey : column`, one JSON document per row:

```sql
select * from graphql('
customer : customers
{
  id   : customer_id
  name : full_name
  city : city
}');
```

**Nested array of child rows** — wrap the child selection in `[{ ... }]`. The join is detected
automatically from the foreign key, so the FK must exist (and should be indexed):

```sql
select * from graphql('
customer : customers
{
  id   : customer_id
  name : full_name
  orders : orders
  [{
    orderId : order_id
    placed  : order_date
    amount  : amount
  }]
}');
```

Parents with no children come back with an empty array, not a missing key. `NULL` columns come
back as JSON `null`. Dates serialize as ISO 8601 strings with a time part.

**Child-to-parent, flattened** — use `@unnest` to lift parent columns into the child document:

```sql
select * from graphql('
purchase : orders
{
  orderId : order_id
  amount  : amount
  customers @unnest
  {
    customerName : full_name
  }
}');
```

---

## Step 4 — Control the output with directives

| Directive | Purpose | Notes |
|---|---|---|
| `@link` | Spell out the join when it cannot be inferred from a foreign key | Column names must be **uppercase**. A single column name works when both sides share the name; otherwise give an explicit `from` / `to` pair. Confirm which side `from` and `to` refer to in Oracle's GraphQL Table Function documentation for your release before relying on differently named columns |
| `@unnest` | Flatten a related table's columns into the current object | Shown above |
| `@where(sql: "...")` | SQL predicate filter, like a `WHERE` clause | Subqueries are allowed inside the predicate |
| `@orderby(sql: "...")` | Order the elements of a nested array | Demonstrated on arrays |
| `@array` | Same effect as the `[{ ... }]` wrapper | Use whichever reads better |
| `@object` | Nest a single related row as a JSON object | For to-one relationships |
| `@nest` | Group sibling columns of the same table under a new key | Pure reshaping, no join |
| `@generated(sql: "...")` | Add a computed field from a SQL expression | |
| `@alias(as: x)` | Give a table an alias so column references (`x.col`) are unambiguous | Useful when parent and child share column names |
| `@flex`, `@hidden` | Duality-view-only directives | **Not usable** in the table function |

```sql
-- Explicit join + ordering inside the array
select * from graphql('
customer : customers
{
  id   : customer_id
  name : full_name
  orders : orders @link (to: ["CUSTOMER_ID"]) @orderby(sql: "order_date desc")
  [{
    orderId : order_id
    placed  : order_date
  }]
}');

-- Filter the root with @where (note the doubled single quotes inside the SQL string)
select * from graphql('
customer : customers @where(sql: "tier = ''GOLD''")
{
  id   : customer_id
  name : full_name
}');

-- Computed field
select * from graphql('
purchase : orders
{
  orderId : order_id
  net @generated(sql: "amount - nvl(discount, 0)")
}');

-- Grouping columns under a new key
select * from graphql('
purchase : orders
{
  orderId : order_id
  money @nest
  {
    gross    : amount
    discount : discount
  }
}');

-- Single nested object
select * from graphql('
purchase : orders
{
  orderId : order_id
  buyer : customers @object
  {
    id   : customer_id
    name : full_name
  }
}');

-- Aliases for unambiguous references
select * from graphql('
customer : customers @alias(as: c)
{
  id   : c.customer_id
  name : c.full_name
  orders : orders @alias(as: o) @array
  {
    orderId : o.order_id
    amount  : o.amount
  }
}');
```

**Quoting tip.** The GraphQL text is an ordinary SQL string literal, so any single quote inside it
must be doubled, or you can switch the whole literal to `q'[ ... ]'` quoting to keep it readable.

---

## Step 5 — Filter and parameterize

Three ways to restrict rows, from simplest to most flexible:

1. **Field arguments** for plain equality on the root table:

   ```sql
   select * from graphql('
   customer : customers (customer_id: 42)
   {
     id   : customer_id
     name : full_name
   }');
   ```

2. **`@where(sql: ...)`** for anything SQL can express (ranges, `LIKE`, subqueries).

3. **QBE filter specifications** for comparison, logical, and item-method operators. The operator
   list and exact placement are defined in Oracle's *GraphQL Filter Specifications: QBE* page —
   look it up for the target release instead of guessing the syntax.

**Variables.** Declare a `$name` in the GraphQL text and supply the value with `PASSING`. The value
can be a literal or a bind variable:

```sql
select * from graphql('
customer : customers (customer_id: $v_id)
{
  id   : customer_id
  name : full_name
}'
passing 42 as "v_id");

-- With a SQL*Plus / SQLcl bind variable
variable b_id number
exec :b_id := 42;

select * from graphql('
customer : customers (customer_id: $v_id)
{
  id   : customer_id
  name : full_name
}'
passing :b_id as "v_id");
```

**Security rules.** `@where`, `@orderby`, and `@generated` accept raw SQL text. Never concatenate
user- or LLM-supplied strings into the GraphQL text or into any `sql:` argument. Pass values through
`PASSING` variables, and keep any dynamic piece to a fixed allow-list. See Skill 26 for the general
injection-prevention pattern.

---

## Step 6 — Validate before reporting success

1. Run the query and check that the JSON keys match the shape you sketched in Step 2.
2. Compare row counts and a few values against an equivalent hand-written SQL query.
3. Check the edge cases: a parent with no children (expect `[]`), `NULL` columns (expect `null`),
   and a filter that matches nothing.
4. If you used `@link` with differently named columns, test with data where the columns do not
   coincide, so a wrong direction cannot pass by accident.
5. If any step could not be tested, say so explicitly instead of declaring the query verified.

---

## Known limitations and gotchas

- **`limit` argument.** The documentation describes a `limit` argument, but on the release tested
  in the source material it failed with `ORA-00904: "LIMIT": invalid identifier`. Test it on the
  target release. A fallback that follows the demonstrated `@where` pattern is
  `@where(sql: "rownum <= 5")`; remember `ROWNUM` is applied before any ordering, so it is not a
  "top N by X" filter.
- **`@link` columns must be uppercase.** Lowercase or quoted-mixed-case names will not resolve.
- **`@flex` and `@hidden`** only apply to duality views.
- **`CHECK` argument on `@where`** is a duality-view option (it flips the filter result and defaults
  to true); the table function ignores it.
- **Read-side tool.** This skill covers querying through the table function. Do not assume it
  performs inserts, updates, or deletes — use duality views (Skill 12) for document-style writes.
- **Output column heading** differs between queries (a generated expression or `DATA`). Select the
  single JSON column by position or alias it in a wrapper query rather than by name.

---

## Choosing the right tool

| Need | Use |
|---|---|
| Ad-hoc nested JSON from relational tables inside SQL or PL/SQL | `GRAPHQL` table function (this skill) |
| Read **and write** whole JSON documents with automatic decomposition into tables | JSON-relational duality view — see [Skill 12](../12_json_relational_duality_views.md) |
| Define a duality view declaratively | Duality views also accept GraphQL syntax, converted to SQL behind the scenes |
| An HTTP GraphQL endpoint for external clients | ORDS GraphQL support (ORDS 23.3+) — a separate feature from the database function, worth a look only if ORDS is already in use |
| Joins that cannot be inferred, or fully custom document shaping | Hand-written `JSON_OBJECT` / `JSON_ARRAYAGG` |

---

## Non-negotiable rules

- Verify the feature on the target release (Step 1) before writing a single query.
- Make sure the foreign key exists, or use `@link`, before relying on a nested join.
- Never splice untrusted text into GraphQL or `sql:` arguments; use `PASSING` variables.
- Do not use duality-only directives in the table function.
- Do not claim a query is verified until Step 6 has been run.

---

## Related skills in this repository

- [Skill 12: JSON Relational Duality Views](../12_json_relational_duality_views.md)
- [Skill 26: Dynamic SQL — EXECUTE IMMEDIATE & DBMS_SQL](../26_dynamic_sql_execute_immediate.md)
- [Skill 21: Advanced SQL — CTE, PIVOT, MERGE, CONNECT BY](../21_advanced_sql_cte_pivot_merge.md)

---

## References

- [Oracle Docs — GraphQL Table Function (26ai)](https://docs.oracle.com/en/database/oracle/oracle-database/26/gphql/graphql-table-function.html)
- [Oracle Docs — GraphQL Queries (26ai)](https://docs.oracle.com/en/database/oracle/oracle-database/26/gphql/graphql-queries.html)
- [Oracle Docs — GraphQL Filter Specifications: QBE (26ai)](https://docs.oracle.com/en/database/oracle/oracle-database/26/gphql/graphql-filter-specifications-qbe.html)
- [Oracle Docs — GraphQL in Oracle REST Data Services](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/23.3/orddg/graphql-oracle-rest-data-services.html)
- [GraphQL language home](https://graphql.org/)

**#GraphQL #JSON #Oracle23ai #Oracle26ai #SQL #DualityViews #ORDS #OracleAI**
