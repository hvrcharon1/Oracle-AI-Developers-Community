# Linux Terminal (bash/zsh) Integration with Oracle AI

Linux is the most common host for production Oracle AI Database workloads and for CI/CD pipelines that call SQLcl unattended, so a solid bash/zsh workflow matters as much as the desktop IDE integrations.

## Installing and Running SQLcl

Oracle SQLcl is a free, cross-platform command-line interface for Oracle Database that also ships inside tools like the Oracle SQL Developer extension for VS Code, and it runs the same way from a native Linux shell [1].

```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
/opt/sqlcl-latest/sqlcl/bin/sql /nolog
SQL> connect -cloudconfig /home/<you>/wallets/Wallet.zip <user>/<password>@<tns_alias>
```

Java 17 or later must be on `PATH` (or referenced via `JAVA_HOME`) for both interactive use and MCP server mode [1][2].

## Running SQLcl as an MCP Server

Once a connection is saved, the same SQLcl binary can be started in MCP server mode so that AI clients — Claude Desktop, IDE extensions, or custom agents — connect over stdio and exercise tools such as listing saved connections, running SQL, executing PL/SQL, and running SQLcl scripts [2][3]. Because SQLcl runs locally, it manages credentials on the machine it is installed on and does not send data to Oracle itself [4].

### Session Auditing
Long-running Linux hosts running SQLcl-MCP can be monitored through `V$SESSION` by filtering on `PROGRAM='SQLcl-MCP'`, which is useful for tracking AI-driven database activity separately from normal application sessions [4].

## Shell Script Tips
* Save connections once (`-save <name> -savepwd`) under the service account that will run the MCP server, then reference `-name <name>` from systemd units or cron jobs.
* Wrap SQLcl startup in a small `.sh` launcher so IDE/AI-client MCP configs only need one stable executable path.

## References

[1] Oracle. (n.d.). *Oracle SQLcl*. https://www.oracle.com/database/sqldeveloper/technologies/sqlcl/
[2] Oracle Blogs. (2025, July 16). *Introducing MCP Server for Oracle Database*. https://blogs.oracle.com/database/introducing-mcp-server-for-oracle-database
[3] Oracle Docs. *Using the Oracle SQLcl MCP Server*. https://docs.oracle.com/en/database/oracle/sql-developer-command-line/26.2/sqcug/using-oracle-sqlcl-mcp-server.html
[4] DreamFactory. (2026). *How to Set Up an MCP Server for Oracle Databases*. https://www.dreamfactory.com/hub/set-up-mcp-server-for-oracle-databases/
