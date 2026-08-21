# Skill 38: Migrating Oracle Database 23ai Free to Oracle AI Database 26ai Free on Windows

**Category:** Database Administration | Installation & Upgrade | **Level:** Intermediate

---

## Overview

Oracle AI Database 26ai isn't a new major release — it's the same 23ai code line carried forward. Internally the product still reports itself as version `23.26.0.0.0`, and Oracle's own messaging is that a database already on 23ai becomes 26ai simply by applying the October 2025-and-later quarterly Release Update. **That shortcut does not exist for the Free edition.** Oracle Database Free does not accept Release Update patching, and neither Oracle Database Upgrade Assistant (DBUA) nor Oracle Database Configuration Assistant (DBCA) can be used to upgrade or plug a previous release's PDB into it. The only Oracle-supported path from Oracle Database 23ai Free to Oracle AI Database 26ai Free — on Windows or any other platform — is a side-by-side install plus an Oracle Data Pump export/import.

This skill walks an agent or developer through that full path on Windows: exporting the 23ai Free `freepdb1` pluggable database, installing 26ai Free, importing the data back in, and cleaning up the handful of things Data Pump doesn't carry over for you.

---

## Key Concept: Why This Isn't a Normal Upgrade

| | Paid editions (EE/SE2) already on 23ai | Oracle Database Free already on 23ai |
|---|---|---|
| Apply an RU to reach 26ai | ✅ Supported — no full upgrade needed | ❌ Not supported — Free does not receive or accept RU patches |
| Use DBUA | ✅ Available on Windows | ❌ Explicitly unsupported for Free |
| Use DBCA to plug in an older PDB | ✅ Available | ❌ Explicitly unsupported for Free |
| Export/import with Data Pump | Optional (rarely needed) | ✅ **The only supported path** |

Because Free edition upgrades are unsupported by design, treat this as a **migration**, not an in-place upgrade: a fresh 26ai Free install, with your existing data carried over logically rather than the binaries being patched underneath it.

---

## Prerequisites

- An existing Oracle Database 23ai Free (or any 23.2+ Free release) instance on Windows, with the `SYSTEM` password known
- Administrator rights on the Windows machine
- Oracle AI Database 26ai Free for Windows x64 downloaded from the [Oracle Database Software Downloads](https://www.oracle.com/database/technologies/oracle-database-software-downloads.html) page
- Supported OS: Windows 10/11 x64 (Pro, Enterprise, Education) or Windows Server 2016/2019/2022/2025 x64
- At least 8.5 GB free disk space for the new Oracle Home, plus room for a second copy of your data during the migration window
- 2 GB RAM minimum (the Free edition caps itself at 2 CPUs / 2 GB RAM / 12 GB user data regardless of what the host has)
- Enough free disk space to hold a Data Pump dump file of your existing schemas

---

## Step-by-Step

### Phase 1 — Export from Oracle Database 23ai Free

**1. Take inventory before you touch anything**

List the non-default schemas, any Oracle APEX workspaces/applications, custom `DIRECTORY` objects, network ACLs (`DBMS_NETWORK_ACL_ADMIN` — relevant if you call `UTL_HTTP`, Select AI, or OCI Generative AI from PL/SQL), and any scheduled `DBMS_SCHEDULER` jobs. Data Pump `full=Y` captures schema objects and scheduler jobs, but ACL wallets, external directory paths, and TNS/listener customizations live outside the database and need to be re-applied by hand after the migration.

**2. Create a Data Pump directory on disk**

```cmd
mkdir C:\Temp\dump1
```

**3. Set the environment for your existing 23ai Free home**

```cmd
set ORACLE_SID=FREE
set ORACLE_HOME=C:\app\oracle\product\23ai\dbhomeFree
```

**4. Create the `DUMP_DIR` directory object inside the PDB and grant access**

```cmd
%ORACLE_HOME%\bin\sqlplus / as sysdba
```

```sql
ALTER SESSION SET CONTAINER=freepdb1;
CREATE DIRECTORY DUMP_DIR AS 'C:\Temp\dump1';
GRANT READ, WRITE ON DIRECTORY DUMP_DIR TO SYSTEM;
EXIT;
```

**5. Export the PDB**

```cmd
%ORACLE_HOME%\bin\expdp system/<system_password>@localhost:1521/freepdb1 full=Y directory=DUMP_DIR dumpfile=expdb23ai_freepdb1.dmp logfile=expdb23ai_freepdb1.log
```

Watch the end of the log for `Job "SYSTEM"."SYS_EXPORT_FULL_01" successfully completed`. If you're migrating to a different machine, point the connect string at that host instead of `localhost` and copy the resulting `.dmp` file over.

**6. If you use Oracle APEX, export applications separately too**

A full Data Pump export carries the `APEX_%`/`FLOWS_%` schemas, but application-level exports (via SQL Workshop's **Export** or `APEXExport`) are the safer way to move individual app definitions across an APEX version bump, since 26ai Free ships a newer APEX release than most 23ai Free installs. Keep the `.sql` export files alongside your dump file.

**7. Take a second safety net**

A Data Pump export is a logical backup, not a physical one. Before you deinstall anything, either copy the entire `C:\app\oracle\product\23ai` tree somewhere safe, or take an RMAN backup of the source database. Fifteen extra minutes here is cheap insurance.

### Phase 2 — Remove the Old Version (same-machine migration)

**8. Deinstall Oracle Database 23ai Free**

Oracle's own installation guide is explicit: deinstall the 23.x Free instance first if you're installing 26ai Free on the *same* machine — a second Free instance competing for the `FREE` SID and port 1521 is not the supported configuration. Two options:

- **GUI:** Control Panel → Programs → Programs and Features → select **Oracle AI Database 23ai Free** (or 23c Free) → Uninstall, and follow the prompts.
- **Silent:** run the equivalent `msiexec /x` command for the installed product, adding `/qn` for fully silent or `/qb` to keep a progress bar visible.

If you'd rather keep the 23ai instance running until you've validated the import, install 26ai Free on a second machine or VM instead and run the `expdp`/`impdp` pair across the network — the connect string in the commands above already supports a remote host.

### Phase 3 — Install Oracle AI Database 26ai Free

**9. Download and extract**

Grab **Oracle AI Database Free for Microsoft Windows (ZIP)** from the downloads page and extract it to a temporary folder (e.g. `C:\Temp\OracleFree26ai`).

**10. Run the installer**

Open a command prompt as Administrator, navigate to the extracted folder, and run:

```cmd
setup.exe
```

Follow the wizard: accept the license, confirm the install location (default is something like `C:\app\oracle\product\26ai\dbhomeFree`), and set the administrative passwords for `SYS`, `SYSTEM`, and `PDBADMIN` when prompted. For a scripted/unattended install instead, edit the bundled `FREEInstall.rsp` response file and run:

```cmd
setup.exe -silent -responseFile C:\Temp\OracleFree26ai\FREEInstall.rsp
```

**11. Confirm the install**

Two Windows services should now exist and be running: `OracleServiceFREE` (the database) and `OracleOraDB26Home<n>TNSListener` (the listener). Check via `services.msc` or:

```cmd
sc query OracleServiceFREE
```

A default PDB named `freepdb1` is created automatically — the same PDB name used in 23ai Free, so there's no PDB rename step this time (unlike migrating off old XE installs, where `xepdb1` becomes `freepdb1`).

### Phase 4 — Import into Oracle AI Database 26ai Free

**12. Copy the dump file (if migrating cross-machine)**

Move `expdb23ai_freepdb1.dmp` into a directory the new Oracle Home can reach, e.g. `C:\Temp\dump1` again if you're on the same box.

**13. Set the environment for the new 26ai Free home**

```cmd
set ORACLE_SID=FREE
set ORACLE_HOME=C:\app\oracle\product\26ai\dbhomeFree
```

**14. Recreate the `DUMP_DIR` directory object in the new PDB**

```cmd
%ORACLE_HOME%\bin\sqlplus / as sysdba
```

```sql
ALTER SESSION SET CONTAINER=freepdb1;
CREATE DIRECTORY DUMP_DIR AS 'C:\Temp\dump1';
GRANT READ, WRITE ON DIRECTORY DUMP_DIR TO SYSTEM;
EXIT;
```

**15. Import**

```cmd
%ORACLE_HOME%\bin\impdp system/<system_password>@localhost:1521/freepdb1 full=Y directory=DUMP_DIR dumpfile=expdb23ai_freepdb1.dmp logfile=impdb26ai_freepdb1.log
```

**16. Recompile and check for invalid objects**

```sql
@?/rdbms/admin/utlrp.sql

SELECT object_name, object_type, status
FROM   dba_objects
WHERE  status = 'INVALID'
AND    owner NOT IN ('SYS','SYSTEM');
```

A handful of invalid objects after this kind of cross-version import is a documented, known behavior (see Oracle Bug 35706665 for the equivalent XE-to-26ai case) — the standard workaround is simply to ignore them and let `utlrp.sql` recompile, then re-check.

### Phase 5 — Post-Migration Cleanup

**17. Re-enable anything version-specific**

If you had the [MCP Server feature enabled](03_mcp_server_setup_autonomous_ai_database.md) or ORDS/APEX configured against the 23ai instance, those are host- and instance-specific and won't survive the reinstall — walk back through the relevant setup skill against the new 26ai Free home.

**18. Watch for the ACL import gotcha**

Occasionally the import log shows `ORA-01007: Reference to a variable not in SELECT clause` immediately followed by `ORA-39342: Data Pump did not import dependent objects for NETWORK_ACL due to the previous error`. This is a known, narrow issue with `NETWORK_ACL` objects specifically — it doesn't block the rest of the import, but if you relied on `DBMS_NETWORK_ACL_ADMIN` ACLs (for `UTL_HTTP`, Select AI, or OCI Generative AI calls from PL/SQL), verify and manually recreate them after the import completes rather than assuming they came across.

**19. Point tools and applications at the new home**

The listener still defaults to port 1521 with service name `FREE` / PDB `freepdb1`, so most `tnsnames.ora` entries and JDBC/ODBC connection strings need no changes — but double-check any hardcoded `ORACLE_HOME` references in scripts, IDE configurations (SQL Developer, VS Code Oracle extension), or scheduled tasks that pointed at the old `...\product\23ai\dbhomeFree` path.

**20. Clean up**

Once you've validated the new database, remove the `.dmp`/`.log` files from `C:\Temp\dump1` (or archive them), and if you kept the old `23ai` Oracle Home directory as a safety copy, delete it once you're confident you no longer need it.

---

## Command Reference

| Task | Command |
|---|---|
| Point env at old (23ai) home | `set ORACLE_HOME=C:\app\oracle\product\23ai\dbhomeFree` |
| Point env at new (26ai) home | `set ORACLE_HOME=C:\app\oracle\product\26ai\dbhomeFree` |
| Export the PDB | `expdp system/<pwd>@localhost:1521/freepdb1 full=Y directory=DUMP_DIR dumpfile=expdb23ai_freepdb1.dmp logfile=expdb23ai_freepdb1.log` |
| Import the PDB | `impdp system/<pwd>@localhost:1521/freepdb1 full=Y directory=DUMP_DIR dumpfile=expdb23ai_freepdb1.dmp logfile=impdb26ai_freepdb1.log` |
| Check invalid objects | `SELECT object_name, status FROM dba_objects WHERE status='INVALID';` |
| Deinstall silently | `msiexec /x <product-code> /qn` |

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `datapatch`/RU apply fails on the Free instance | Free edition doesn't accept Release Updates | Not a bug — use the export/import path in this skill instead |
| DBUA doesn't offer 23ai Free as an upgrade source | Unsupported by design for Free edition | Same — export/import only |
| `ORA-00442`-style single-instance conflict when both versions try to run | Free edition expects one instance per machine/logical environment | Deinstall the old version first, or migrate via a second machine/VM |
| A handful of `INVALID` objects after import | Known, benign cross-version import behavior (Bug 35706665 pattern) | Run `utlrp.sql`, re-check `dba_objects` |
| `ORA-39342` tied to `NETWORK_ACL` in the import log | Known `NETWORK_ACL` import limitation | Recreate the ACL manually with `DBMS_NETWORK_ACL_ADMIN` after import |
| `ORA-39712: attempt to open a Standard/Enterprise Edition database with a Free server` | Trying to plug/import a non-Free (EE/SE2) PDB into Free | Only Free-to-Free and XE-to-Free migrations are supported |

---

## Related Skills

- [Skill 03: MCP Server Setup — Autonomous AI Database](03_mcp_server_setup_autonomous_ai_database.md)
- [Skill 06: Oracle APEX AI Assistant](06_oracle_apex_ai_assistant.md)

---

## References

- [Oracle AI Database Free Installation Guide, 26ai for Microsoft Windows](https://docs.oracle.com/en/database/oracle/oracle-database/26/xeinw/index.html) — Chapter 8, "Moving from Previous Versions of Oracle Database XE or Free to Oracle AI Database Free"
- [Oracle AI Database 26ai Free FAQ](https://www.oracle.com/database/free/faq/)
- [Oracle AI Database Software Downloads](https://www.oracle.com/database/technologies/oracle-database-software-downloads.html)
- [Oracle AI Database 26ai: Upgrade Overview — ORACLE-BASE](https://oracle-base.com/articles/26/oracle-26-upgrade-overview)
- Alex Zaballa, ["Moving Older Oracle XE Versions to Oracle AI Database Free 26ai — Is it possible?"](https://alexzaballa.com/moving-older-oracle-xe-versions-to-oracle-ai-database-free-26ai-is-it-possible/) — real-world confirmation that Release Update patching does not work on the Free edition when moving 23ai Free → 26ai Free

**#OracleAIDatabase #26ai #23ai #Windows #DataPump #Migration #DatabaseFree**
