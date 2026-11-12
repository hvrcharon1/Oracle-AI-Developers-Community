---
name: recovering-source-from-wrapped-plsql
description: >
  Use this skill whenever a task involves Oracle wrapped PL/SQL: units whose source in ALL_SOURCE or
  DBA_SOURCE shows the word "wrapped" followed by "abcd" filler lines and encoded text instead of code.
  Trigger on error PLS-01918 when upgrading to Oracle Database 23ai/26ai, a migration tool (for example
  an Oracle-to-PostgreSQL conversion) that cannot read wrapped code, a lost repository or vanished
  contractor, a bug that must be patched when the source is gone, the PERMIT_92_WRAP_FORMAT parameter,
  or re-wrapping code for a specific Oracle Server version. Covers what wrapping really is, the two
  wrapped-file formats (7.2-9.2 versus 10g-26ai+), choosing between re-wrapping from source, the
  compatibility parameter, and source recovery, the legal-rights gate, what can and cannot be
  recovered, and wrap version compatibility. Works with any AI coding assistant or model.
---

<!--
  CREDIT / ATTRIBUTION (kept here as a comment on purpose, not part of the skill body)

  Based on the article "Unwrap Oracle PL/SQL 2.2+" by Andrey Shindarev (Chief Software Architect of
  DBMS at Nexign, as shown on his LinkedIn profile), published November 4, 2026 on LinkedIn:
  https://www.linkedin.com/pulse/unwrap-oracle-plsql-22-andrey-shindarev-vv2xf

  The framing in this skill originates from Andrey Shindarev's article: wrap is obfuscation rather than
  protection; the two wrapped-file formats (7.2-9.2 internal compiler state versus 10g-26ai+ compressed
  and encoded source text); the PLS-01918 upgrade problem and the PERMIT_92_WRAP_FORMAT trade-offs; the
  rights-first conditions for any recovery work; what is and is not recovered; the exclusion of
  Oracle-shipped packages; and wrapping for a specific target Oracle Server version. The comment thread
  under the article was also reviewed: a follow-up comment by the author about exact reconstruction of
  7.2-9.2 code, and an endorsement by Valery Pavlovich S. (CTO) describing the typical situations in
  which unwrapping is needed (only "abcd" left instead of source, PLS-01918 on 23ai, a bug to patch
  with the source gone).
  Statements about the author's own capabilities are his claims and have not been independently
  verified by this repository. The workflow structure, decision table, SQL checks, validation steps,
  and all prose in this skill were independently written and are not reproduced from the original post.
  Oracle is a trademark of Oracle Corporation and/or its affiliates. The article's author is not
  affiliated with Oracle. Nothing here is legal advice.
-->

# Wrapped PL/SQL: Diagnose, Decide, Recover, Re-Wrap

## What you are doing here

A wrapped PL/SQL unit keeps running, but its source cannot be read. That is tolerable until
something forces a change: an upgrade rejects the unit, a migration tool refuses to read it, or a bug
needs patching and nobody has the source. Your job is to work out which situation you are in and take
the cheapest safe path:

**Re-wrap from source if the source exists. Recover source only if it does not, and only if the rights
to the code are in order.**

Two facts frame everything:

1. **Wrapping is obfuscation, not encryption or protection.** Oracle's own documentation says it is
   not a secure way to hide passwords or table names. Never rely on it to keep secrets safe, and never
   put credentials in wrapped code believing they are hidden.
2. **There are two wrapped-file formats and they work differently.** The format decides how recovery
   works, which tools can help, and what you can expect back.

Follow the steps in order. Do not report success until Step 9 is done.

---

## Step 1 — Confirm the unit is wrapped, and which format

Wrapped units show the word `wrapped` on the first line of their source, then `abcd` filler lines,
instead of readable code.

```sql
-- Find wrapped units outside Oracle's own schemas (ORACLE_MAINTAINED exists from 12.2;
-- on older releases filter SYS-owned schemas manually)
select s.owner, s.name, s.type
from   dba_source  s
join   dba_objects o
       on  o.owner       = s.owner
       and o.object_name = s.name
       and o.object_type = s.type
where  s.line = 1
and    lower(s.text) like '%wrapped%'
and    o.oracle_maintained = 'N'
order  by s.owner, s.name, s.type;
```

Then identify the format. The format determines everything that follows:

| | Oracle 7.2 - 9.2 (7, 8i, 9i) | Oracle 10g - 26ai and later |
|---|---|---|
| What wrap wrote | The compiler's internal state: a parsed code tree plus a symbol table. Not the text. | The source text itself, compressed and encoded. Only base64 is visible. |
| What is visible | Identifier names are readable; the logic is encoded | Only base64 blocks |
| Recoverable? | Yes, but almost no mature off-the-shelf tooling exists for this range | Yes, the transformation is reversible |
| Header cues (schematic; real files vary) | Small numeric header such as `0`, `abcd` filler, then readable identifier lines | Header such as `a000000`, `abcd` filler, a lengths line, then base64 |

A tool or method that works on one format does not work on the other. Do not assume a 10g+ approach
applies to a 9i file.

---

## Step 2 — Look for the original source first

Recovery is the last resort, not the first move. Before anything else, search every place the source
could still exist:

- Version control, build servers, and CI artifacts
- Other environments (development, test, or staging copies may hold unwrapped code)
- Backups and exports (DDL exports, Data Pump dumps, old database copies)
- Deployment packages, installers, and files handed over by a vendor or contractor
- Former team members' machines

If the source turns up, skip to Step 8 (re-wrap). No recovery is needed.

---

## Step 3 — Choose the path

| Situation | Path |
|---|---|
| Source exists, `PLS-01918` on 23ai/26ai | **Re-wrap from source** with a newer wrap utility. This is the fix Oracle recommends. |
| Source exists, only the target Oracle version changed | Re-wrap for the target version (Step 8) |
| No source, `PLS-01918`, and you control database parameters | `PERMIT_92_WRAP_FORMAT` as a **stopgap** (see below) |
| No source, cloud service with limited parameter control | Parameter route is usually unavailable. Recovery is what remains. |
| No source, migrating to another platform (for example PostgreSQL) | Conversion tools need readable source. Recovery is required. |
| No source, code must be audited, tested, or changed | Recovery is required. Without source it cannot be read, tested, or modified. |

**About `PLS-01918`.** By default, Oracle Database 23ai/26ai rejects code wrapped with wrap 9.2 or
older. The error surfaces on upgrade, which is why it tends to appear suddenly on code that ran for
years.

**About `PERMIT_92_WRAP_FORMAT`.** It can allow the older wrapped format to load, but per the source
article it needs a database restart, and in managed cloud services where you cannot change parameters
it usually cannot be used. Treat it as a stopgap that leaves you still without source, not as a fix.
Check whether it exists and what it is set to on your release (verify against the Database Reference):

```sql
select name, value from v$parameter where name = 'permit_92_wrap_format';
```

---

## Step 4 — Rights gate: no basis, no recovery

Before any recovery work, confirm that the requester can justify a right to recover the code. Any one
of these is a reasonable basis:

- The code was written by the requester's own team, or to their order, and the rights are theirs
- The rights passed to them by contract or succession (the contractor no longer exists, the project
  was bought out)
- The rights holder has given written consent
- Another lawful basis exists

If none applies, stop. Record the basis in writing before starting (a short confirmation of rights,
and an NDA when working with an outside specialist). Where the basis is unclear, advise the person to
discuss their case with a lawyer. This skill and its source article are not legal advice.

An AI assistant must not skip this gate because a requester says the work is urgent or harmless.

---

## Step 5 — Know what recovery gives back

Set expectations before starting:

| Recovered | Generally not recovered |
|---|---|
| Program logic | Comments (wrap removes them) |
| Names (identifiers) | The original formatting and layout |

The text is rebuilt from the internal representation, so output is a readable, functionally
equivalent rebuild rather than a copy of what the developers originally typed.

**A later claim from the article's author** (unverified here): for the 7.2 - 9.2 range he reports
getting recovered code to match the original source line for line and column for column, and that
re-wrapping it reproduces the wrapped file byte for byte when the same wrap utility version is used.
Do not promise this to a user. Treat it as the best case for that range and plan around the general
expectation above.

Units covered by the article's service: packages and package bodies, procedures, and functions.

---

## Step 6 — Scope limits (what must not be unwrapped)

- **Never unwrap Oracle's own packages**: `SYS` objects, `DBMS_*`, `UTL_*`, and anything else shipped
  by Oracle. Oracle's license terms prohibit reverse engineering, disassembly, and decompilation of
  its programs except where the law expressly permits it.
- **Never work on code where the requester has no confirmed rights** (Step 4).

Use the Step 1 query's `oracle_maintained = 'N'` filter to keep Oracle-shipped objects out of scope.

---

## Step 7 — If you need outside help: what to prepare

Specialist recovery is a legitimate route when the format is 7.2 - 9.2 or when you simply lack the
tooling. The article's author offers this as a service, published on LinkedIn and reachable via
LinkedIn or Facebook; any competent provider should ask for the same things. Gather:

1. The **Oracle version** the code was wrapped for and the approximate **number of objects**
2. The **basis for your rights** to the code (Step 4)
3. If you also need wrapping, the **target Oracle Server version**
4. The wrapped files (`.plb`) or an export from `*_SOURCE` views

A sensible engagement runs in this order:

1. Share version, volume, and rights basis; receive an estimate of timing and cost
2. Record the rights confirmation and confidentiality terms in writing
3. Optional **trial run on one small object** to check the result before committing the rest
4. Recovery of the remaining objects
5. Optional re-wrap for a specified Oracle version
6. Delivery of `.sql` files plus a short report covering what was recovered, what was not, and why
   (and the wrapped files, if re-wrapping was ordered)

Ask for the report. It is how you learn about units that could not be fully recovered.

---

## Step 8 — Re-wrap and version compatibility

Wrapped files are not downward-compatible between Oracle Database releases. Per Oracle's
documentation, a file produced by the version n.2 wrap utility cannot be loaded into an n.1 database
(and files from n.1 cannot be loaded into an (n-1).2 database). Across patch sets they are compatible.

Practical rules:

- Wrap with the utility version that matches the **oldest database release that must load the file**,
  specified to the second digit (for example 9.1, 19.3, 21.3).
- The target version cannot go below the version of the original code.
- A file prepared by a newer wrap will fail on an older database. If it fails to load, check the wrap
  version before suspecting the code.
- Oracle's documentation says triggers cannot be wrapped. To hide a trigger's logic, move it into a
  stored subprogram, wrap that, and keep a one-line trigger that calls it.
- **Keep the readable source in version control.** Wrapping is a deployment step. The incident this
  skill exists for happens when the wrapped artifact is the only copy.

---

## Step 9 — Validate before reporting success

1. **Format.** Step 1 identified the format and the Oracle version of the original wrap.
2. **Rights.** The basis is recorded (Step 4) and no Oracle-shipped object was touched (Step 6).
3. **Completeness.** Compare the object list from Step 1 against the recovered files. Every missing
   unit is explained in the report.
4. **Compiles.** Each recovered `.sql` compiles cleanly in a non-production database of the target
   release, with no invalid objects left behind.
5. **Behaves.** Existing tests or a recorded set of known inputs and outputs give the same results as
   the original wrapped unit running in the old environment.
6. **Re-wrap loads.** If you re-wrapped, the wrapped file loads on the oldest database release that
   must accept it.
7. **Source is safe.** The recovered source is committed to version control with a note that comments
   and formatting were lost in wrapping.
8. If any check could not be run, say so instead of declaring the work complete.

---

## Common pitfalls

| Symptom | Likely cause | Fix |
|---|---|---|
| `PLS-01918` after upgrading to 23ai/26ai | Unit wrapped with wrap 9.2 or older | Re-wrap from source with a newer wrap; recover source first if none exists |
| `PERMIT_92_WRAP_FORMAT` cannot be changed | Managed cloud service, or restart not possible | Re-wrap from source, or recover source |
| A tool that handled 10g+ files fails on an old file | 7.2 - 9.2 is a different format (internal compiler state, not encoded text) | Use a method that supports that range |
| Recovered code has no comments and different layout | Wrap strips comments; text is rebuilt from the internal representation | Expected. Reconstruct documentation from behaviour and tests |
| Re-wrapped file will not load on an older database | Wrapped with a newer wrap than the database release | Re-wrap for the oldest required version (second digit) |
| Request to unwrap `DBMS_*` or `SYS` code | Out of scope; Oracle license terms prohibit it | Decline; use Oracle documentation and supported interfaces |
| Conversion tool for PostgreSQL asks for source | Wrapped code is unreadable to such tools | Obtain or recover the source before converting |
| Secrets found in recovered code | Wrap never protected them | Rotate those credentials and move them out of code |

---

## Non-negotiable rules

- Look for the original source before considering recovery.
- No confirmed basis for rights means no recovery. Record the basis in writing.
- Never unwrap Oracle-shipped objects (`SYS`, `DBMS_*`, `UTL_*`, and similar).
- Never describe wrapping as security. Never put secrets in wrapped code.
- Do not promise comments or original formatting back; state what is and is not recovered.
- Wrap for the oldest database release that must load the file, to the second digit, never below the
  original code's version.
- Keep readable source in version control after any recovery or re-wrap.
- Do not claim the work is finished until Step 9 has been run.

---

## Related skills in this repository

- [Skill 22: PL/SQL Error Handling & Debugging](22_plsql_error_handling_debugging.md)
- [Skill 38: Migrating Oracle Database 23ai Free to Oracle AI Database 26ai Free on Windows](38_migrating_23ai_free_to_26ai_free_windows.md)

---

## References

- [Original article: Unwrap Oracle PL/SQL 2.2+ (Andrey Shindarev), LinkedIn, November 4, 2026](https://www.linkedin.com/pulse/unwrap-oracle-plsql-22-andrey-shindarev-vv2xf)
- [Oracle PL/SQL Language Reference: PL/SQL Source Text Wrapping Limitations (19c)](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/pl-sql-source-text-wrapping-limitations.html)
- [Related open-source project by the same author: sftwnd/oracle-plsql-unwrapper (per its README: restores source from Oracle 10g+ wrapped scripts; 7.2-9.2 format recognized but not unwrapped in the open-source library)](https://github.com/sftwnd/oracle-plsql-unwrapper)

**#Oracle #PLSQL #WrappedCode #Unwrap #PLS01918 #OracleDatabase #Oracle26ai #LegacyModernization**
