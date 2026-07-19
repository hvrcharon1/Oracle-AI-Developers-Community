# Skill 33 — Root-Cause Diagnosis: Design Problem or Database Problem?

> **Capability:** Before recommending an index, a hint, or a stats refresh, determine whether a performance problem is caused by an expensive database operation or by a design decision that invokes cheap logic far more often than the business process requires — because only one of those two problems responds to a database-side fix.

---

## The Trap

*"Can we fix it by adding another index?"*

It's often the first suggestion when a production process turns slow — a reasonable instinct, since indexes do fix a large share of real performance problems. But an index can only ever make one operation cheaper. It has no effect at all on how many times that operation runs. If the real issue is that a fast piece of logic is being executed far more often than the business rule requires, no index will move the needle, because the per-call cost was never the bottleneck.

The biggest performance improvements often come from questioning the design, not just optimizing the database.

## The Model

```
Total Cost  =  Cost Per Execution  ×  Number of Executions
```

Database tuning — indexing, hints, statistics, plan shaping — only ever acts on the first factor. A design decision made upstream (in a loop, a batch driver, a piece of application logic) controls the second factor entirely, and no database change can touch it.

| Symptom | Likely Cause | Where the Fix Lives |
|---|---|---|
| One execution is slow, in isolation | Bad plan / missing index / stale stats | Database — see [Skill 25](25_explain_plan_sql_monitoring.md), [Skill 20](20_index_mastery.md) |
| One execution is fast, but the process is slow overall | The logic is being invoked far more than the business rule requires | Application / PL/SQL design |
| Both | Fix the design first — it usually shrinks the workload enough that the remaining database tuning becomes cheap to test | Design, then database |

## Diagnostic Procedure

1. **Ask the actual question before proposing a fix:** *"Is this a database problem, or is it a design problem?"*
2. **Measure both numbers for the suspect logic** — per-call cost and call count — rather than guessing from the code.
3. **For SQL**, `v$sql` gives both numbers together:

```sql
SELECT sql_id,
       executions,
       ROUND(elapsed_time / 1e6, 3)                          AS total_elapsed_sec,
       ROUND(elapsed_time / NULLIF(executions, 0) / 1e6, 4)   AS avg_elapsed_sec
FROM   v$sql
WHERE  sql_text LIKE '%<distinctive fragment>%'
ORDER  BY executions DESC;
```

An `executions` count that scales with batch/row volume — rather than staying flat regardless of batch size — signals a design problem: the logic is running once per row instead of once per batch.

4. **For PL/SQL calls that don't issue their own SQL every time**, use the hierarchical profiler to get exact call counts:

```sql
BEGIN
  DBMS_HPROF.START_PROFILING(location => 'PROFILER_OUTPUT', filename => 'batch_run.trc');
END;
/
-- run the batch process under test
BEGIN
  DBMS_HPROF.STOP_PROFILING;
END;
/

SELECT owner, module, function, calls,
       ROUND(function_elapsed_time / 1e6, 3) AS elapsed_sec
FROM   dbmshp_function_info
ORDER  BY calls DESC
FETCH FIRST 15 ROWS ONLY;
```

A low per-call time with a `calls` count far exceeding the natural unit of business work (customers, orders, line items) is the signature to look for.

5. **Branch on the evidence** using the table above.
6. **Verify by re-measuring the call count**, not just wall-clock time — wall-clock time can improve for reasons unrelated to the actual diagnosis.

## Example: Collapsing a Loop-Invariant Call

```sql
-- BEFORE — row-by-row (RBAR): one call per order row, N executions for N orders
FOR rec IN (SELECT order_id, customer_id, amount
            FROM   orders WHERE batch_id = p_batch_id) LOOP
    v_rate := get_discount_rate(rec.customer_id);   -- N calls
    UPDATE orders
    SET    discounted_amount = rec.amount * (1 - v_rate)
    WHERE  order_id = rec.order_id;
END LOOP;
```

```sql
-- AFTER — one set-based statement, one execution instead of N
UPDATE orders o
SET    discounted_amount = o.amount * (1 - (
           SELECT c.discount_rate
           FROM   customer_discount_rates c
           WHERE  c.customer_id = o.customer_id))
WHERE  o.batch_id = p_batch_id;
```

Same business rule, zero index changes — the entire gain comes from cutting the execution count from N down to one. See [Skill 18: Bulk PL/SQL Processing](18_bulk_plsql_processing.md) for the `BULK COLLECT` / `FORALL` version of this pattern at scale.

## Anti-Patterns to Avoid When Generating Oracle Performance Guidance

| Anti-pattern | Why it's wrong | Do this instead |
|---|---|---|
| Reaching for an index as the first response to "this batch is slow" | An index reduces per-call cost only; it can't reduce an inflated call count | Measure execution count for the suspect logic before proposing a database-side fix |
| Assuming a fast individual query means the process is fine | A cheap call executed thousands of times can dominate total runtime | Multiply per-call cost × call count before ruling a component out |
| Profiling only `v$sql` when the suspect logic is PL/SQL | Calls that don't issue their own SQL each time won't show up there | Use `DBMS_HPROF` to get exact per-subprogram call counts |
| Calling a fix "done" because wall-clock time dropped | Wall-clock time can improve for unrelated reasons | Re-measure the execution count specifically to confirm the diagnosis was right |

## Key Tips

- Ask the root question — *design problem or database problem?* — every time, before touching any tuning tool.
- A design fix (hoisting a loop-invariant call, converting RBAR to set-based SQL) often delivers a bigger win than any index, because it removes work instead of making the same work cheaper.
- Both problems can coexist. Fix the design first; the remaining database tuning becomes far cheaper to test once the workload itself has shrunk.

## Related Skills

- [Skill 18: Bulk PL/SQL Processing](18_bulk_plsql_processing.md)
- [Skill 20: Index Mastery](20_index_mastery.md)
- [Skill 25: Reading EXPLAIN PLAN & SQL Monitoring](25_explain_plan_sql_monitoring.md)

## References

- Oracle Database PL/SQL Packages and Types Reference — `DBMS_HPROF`
- Oracle Database Performance Tuning Guide — `V$SQL`
