# Skill 30 — SQL Assertions: Guaranteeing At-Least-One Relationships

> **Capability:** Enforce "every parent row must have at least one child row" business rules declaratively using Oracle AI Database 23ai (23.26.1+) assertions, with a version-portable foreign-key fallback for earlier releases.

---

## The Problem: One-to-At-Least-One Relationships

A standard one-to-many relationship allows a parent to have zero children. Many real business rules need more than that — every parent **must** have at least one child:

- Every account needs a payment method.
- Every airport needs a runway.
- Every team needs a player.
- Every order needs a line item.

A plain foreign key only constrains the child → parent direction; it can never guarantee the parent side has any children at all. Oracle AI Database 23ai (23.26.1+) closes this gap with **assertions** — schema-level, cross-table boolean constraints. On earlier releases, use the nominated-child foreign key pattern instead.

---

## Assertions (23.26.1+)

An assertion pairs an `ALL (...)` subquery (the rows to check) with a `SATISFY (...)` boolean expression (the condition every one of those rows must meet):

```sql
-- Guarantee every team has at least one player
CREATE ASSERTION team_requires_player
CHECK (
    ALL ( SELECT team_id FROM teams ) t
    SATISFY (
        EXISTS (
            SELECT 1 FROM players p WHERE p.team_id = t.team_id
        )
    )
)
DEFERRABLE INITIALLY DEFERRED;
```

`ALL ... SATISFY` is new syntax introduced specifically for assertions. It reads naturally ("for every team, satisfy: a player exists") and avoids the classic double-negative `NOT EXISTS ( ... WHERE NOT EXISTS ( ... ) )` pattern that plain SQL requires to express universal quantification.

---

## The Deferred-Constraint Requirement

Always declare this kind of assertion `DEFERRABLE INITIALLY DEFERRED`. Without it, Oracle checks the assertion the instant the parent row is inserted — before its first child can possibly exist — so the insert fails every time. Deferring the check to `COMMIT` lets you insert the parent and its first child together in one transaction:

```sql
-- Fails without a deferred check, or at COMMIT if no player was added:
INSERT INTO teams (team_id, team_name) VALUES (1, 'No players');
COMMIT;
-- ORA-02091: transaction rolled back
-- ORA-08601: SQL assertion (SCHEMA.TEAM_REQUIRES_PLAYER) violated

-- Correct: parent and its required child in the same transaction
INSERT INTO teams   (team_id, team_name) VALUES (1, 'One player');
INSERT INTO players (player_id, player_name, team_id) VALUES (1, 'First player', 1);
COMMIT;  -- succeeds
```

The same reasoning applies to `DELETE` — removing a team's last player fails at commit unless the team row is removed (or another player added) in the same transaction.

---

## Conditional Enforcement

Because assertions are just filtered subqueries, the rule can apply to a subset of parents — something a `NOT NULL` foreign-key column can't express on its own:

```sql
-- Only active teams need a player; inactive teams can have none
CREATE ASSERTION active_team_requires_player
CHECK (
    ALL ( SELECT team_id FROM teams WHERE is_active ) t
    SATISFY (
        EXISTS ( SELECT 1 FROM players p WHERE p.team_id = t.team_id )
    )
)
DEFERRABLE INITIALLY DEFERRED;
```

---

## Fallback for Pre-23.26.1: Nominated-Child Foreign Key

Without assertions, add a "primary child" column on the parent (e.g. `captain_player_id`) with a `NOT NULL` foreign key back to the child. This is also worth doing on 23.26.1+ when a genuinely meaningful "primary child" concept exists in the business domain.

**Critical gotcha:** a single-column FK only proves the value references *some* child row — not one that belongs to *this specific* parent. Scope it correctly with a composite key:

```sql
-- Unique constraint on the child, scoped to its parent
ALTER TABLE players
  ADD CONSTRAINT players_team_player_uk UNIQUE (team_id, player_id);

-- Composite FK: the captain must be a player on THIS team
ALTER TABLE teams
  ADD CONSTRAINT team_captain_fk
    FOREIGN KEY (team_id, captain_player_id)
    REFERENCES players (team_id, player_id)
    DEFERRABLE INITIALLY DEFERRED
    NOVALIDATE;

-- A wrong-team captain now correctly fails at commit:
-- ORA-02291: integrity constraint (SCHEMA.TEAM_CAPTAIN_FK) violated - parent key not found
```

`NOVALIDATE` enforces the constraint for new and changed rows without immediately re-validating pre-existing data — useful when retrofitting onto a populated table. Run a separate validation pass once the backlog is clean, then switch to `VALIDATE`.

**Maintenance cost:** because the parent's column points at one specific child row, that row can't be deleted directly. Reassign the parent to a different or new child first, then delete the old one:

```sql
INSERT INTO players (player_id, player_name, team_id) VALUES (5, 'New captain', 4);
UPDATE teams SET captain_player_id = 5 WHERE team_id = 4;
DELETE players WHERE player_id = 4;   -- now safe
```

---

## Decision Guide

| Situation | Use |
|---|---|
| 23.26.1+, no natural primary child | Assertion |
| 23.26.1+, natural primary child exists (captain, default payment method) | Either — FK documents the concept explicitly; assertion is lower-maintenance |
| 23.26.1+, rule applies only to a subset of parents | Assertion with a filtered `ALL` clause |
| Pre-23.26.1 | Composite foreign key (see gotcha above) |

## Error Quick Reference

| Error | Cause | Fix |
|---|---|---|
| `ORA-08601` | An assertion's `SATISFY` clause evaluated false | Insert parent + required child in the same transaction; confirm `DEFERRABLE INITIALLY DEFERRED` |
| `ORA-02091` | A deferred constraint failed at commit | Add the missing child row before committing |
| `ORA-02291` | A primary-child FK value doesn't belong to this specific parent | Make the FK composite against a unique constraint that includes the parent's key |

---

## References

- [Oracle SQL Language Reference — CREATE ASSERTION](https://docs.oracle.com/en/database/oracle/oracle-database/26/sqlrf/create-assertion.html)
- [How to Define Cross-Table Constraints with Assertions in Oracle AI Database](https://blogs.oracle.com/sql/how-to-define-cross-table-constraints-with-assertions-in-oracle-ai-database) — Chris Saxon, Oracle "All Things SQL" blog
- [Guarantee At Least One in One-to-Many Relationships in Oracle AI Database](https://blogs.oracle.com/sql/guarantee-at-least-one-in-one-to-many-relationships-in-oracle-ai-database) — Chris Saxon, Oracle "All Things SQL" blog (primary source for this skill — see [Attribution](README.md#-attribution))
