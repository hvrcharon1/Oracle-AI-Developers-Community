# Skill 26 — Dynamic SQL: EXECUTE IMMEDIATE & DBMS_SQL

> **Capability:** Build and execute SQL statements whose text is not known at compile time — safely, efficiently, and without SQL injection risk.

---

## What It Is

Dynamic SQL lets you construct query or DDL strings at runtime. Oracle provides two complementary mechanisms:

| Mechanism | Best For |
|---|---|
| `EXECUTE IMMEDIATE` | Simple, one-shot DDL / DML / single-row queries |
| `OPEN cursor FOR` | Multi-row queries with dynamic text |
| `DBMS_SQL` | Truly unknown column count; streaming large result sets; reusable parsed cursors |

---

## EXECUTE IMMEDIATE

### DDL (no bind variables needed)

```sql
BEGIN
  EXECUTE IMMEDIATE
      'CREATE TABLE temp_staging (id NUMBER, payload VARCHAR2(4000))';
END;
/
```

### DML with bind variables — always bind values, never concatenate

```sql
DECLARE
    l_table  VARCHAR2(30) := 'EMPLOYEES';   -- validated before use
    l_dept   NUMBER       := 10;
    l_raise  NUMBER       := 0.05;
BEGIN
  EXECUTE IMMEDIATE
      'UPDATE ' || DBMS_ASSERT.SIMPLE_SQL_NAME(l_table) ||
      ' SET salary = salary * (1 + :raise) WHERE department_id = :dept'
  USING l_raise, l_dept;
  COMMIT;
END;
/
```

> **Rule:** Table and column names cannot be bound — validate them with `DBMS_ASSERT` or a whitelist, then concatenate. All *values* must use bind variables (`:name`).

### Single-row query with INTO

```sql
DECLARE
    l_count NUMBER;
BEGIN
  EXECUTE IMMEDIATE
      'SELECT COUNT(*) FROM employees WHERE department_id = :dept AND status = :s'
  INTO  l_count
  USING 10, 'ACTIVE';

  DBMS_OUTPUT.PUT_LINE('Active count: ' || l_count);
END;
/
```

---

## OPEN Cursor FOR — Multi-row Dynamic Queries

```sql
DECLARE
    TYPE t_ref IS REF CURSOR;
    l_cur     t_ref;
    l_name    VARCHAR2(100);
    l_salary  NUMBER;
    l_sql     VARCHAR2(200);
BEGIN
  l_sql := 'SELECT last_name, salary FROM employees WHERE department_id = :dept';

  OPEN l_cur FOR l_sql USING 50;

  LOOP
    FETCH l_cur INTO l_name, l_salary;
    EXIT WHEN l_cur%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE(l_name || ' — ' || l_salary);
  END LOOP;
  CLOSE l_cur;
EXCEPTION
  WHEN OTHERS THEN
    IF l_cur%ISOPEN THEN CLOSE l_cur; END IF;
    RAISE;
END;
/
```

---

## DBMS_SQL — When Column Structure Is Unknown at Compile Time

Use `DBMS_SQL` when you need to introspect the result set structure (e.g., a generic report engine where the query is supplied by the caller).

```sql
DECLARE
    l_cursor   INTEGER;
    l_col_cnt  INTEGER;
    l_desc_tab DBMS_SQL.DESC_TAB;
    l_value    VARCHAR2(4000);
    l_status   INTEGER;
BEGIN
  l_cursor := DBMS_SQL.OPEN_CURSOR;

  DBMS_SQL.PARSE(
      l_cursor,
      'SELECT last_name, first_name, hire_date FROM employees WHERE rownum <= 5',
      DBMS_SQL.NATIVE
  );

  -- Discover how many columns there are
  DBMS_SQL.DESCRIBE_COLUMNS(l_cursor, l_col_cnt, l_desc_tab);

  -- Define a VARCHAR2 buffer for each column
  FOR i IN 1 .. l_col_cnt LOOP
    DBMS_SQL.DEFINE_COLUMN(l_cursor, i, l_value, 4000);
  END LOOP;

  l_status := DBMS_SQL.EXECUTE(l_cursor);

  WHILE DBMS_SQL.FETCH_ROWS(l_cursor) > 0 LOOP
    FOR i IN 1 .. l_col_cnt LOOP
      DBMS_SQL.COLUMN_VALUE(l_cursor, i, l_value);
      DBMS_OUTPUT.PUT(RPAD(l_desc_tab(i).col_name, 15) || '= ' || l_value || '  ');
    END LOOP;
    DBMS_OUTPUT.NEW_LINE;
  END LOOP;

  DBMS_SQL.CLOSE_CURSOR(l_cursor);
EXCEPTION
  WHEN OTHERS THEN
    IF DBMS_SQL.IS_OPEN(l_cursor) THEN
      DBMS_SQL.CLOSE_CURSOR(l_cursor);
    END IF;
    RAISE;
END;
/
```

---

## SQL Injection Prevention Checklist

| Technique | When to Apply |
|---|---|
| Bind variables (`:name`) | **Always** for all values (strings, numbers, dates) |
| `DBMS_ASSERT.SIMPLE_SQL_NAME(x)` | Validate table or column names before concatenation |
| `DBMS_ASSERT.SQL_OBJECT_NAME(x)` | Validate fully-qualified object names |
| Whitelist `IN` check | Restrict `l_table` to a known set via a lookup table |
| **Never** concatenate raw user input | — no exceptions |

---

## Choosing the Right Mechanism

```
Do you know the number of columns at compile time?
├─ YES → Use EXECUTE IMMEDIATE (single row) or OPEN FOR (multi-row)
└─ NO  → Use DBMS_SQL (DESCRIBE_COLUMNS to discover the result set)

Do you execute the same statement thousands of times in a loop?
└─ YES → DBMS_SQL.PARSE once, then EXECUTE + FETCH in the loop (avoids re-parse overhead)
```

---

## Key Tips

- Prefer `EXECUTE IMMEDIATE` for 95 % of dynamic SQL — it is simpler and the CBO handles it well.
- Always close REF CURSORs and `DBMS_SQL` cursors in `EXCEPTION` handlers to prevent cursor leaks.
- Dynamic DDL (`CREATE`, `DROP`, `TRUNCATE`) performs an implicit commit inside any open transaction — design accordingly.
- Use `DBMS_SQL.TO_REFCURSOR` to convert a `DBMS_SQL` cursor to a REF CURSOR after the `EXECUTE` phase, enabling callers to use standard `FETCH` syntax.

---

## References

- [Oracle Docs — EXECUTE IMMEDIATE](https://docs.oracle.com/en/database/oracle/oracle-database/23/lnpls/EXECUTE-IMMEDIATE-statement.html)
- [Oracle Docs — DBMS_SQL](https://docs.oracle.com/en/database/oracle/oracle-database/23/arpls/DBMS_SQL.html)
- [Oracle Docs — DBMS_ASSERT](https://docs.oracle.com/en/database/oracle/oracle-database/23/arpls/DBMS_ASSERT.html)
