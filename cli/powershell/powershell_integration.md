# PowerShell Integration with Oracle AI

PowerShell is a common automation shell on Windows for Oracle developers who script database connections, deployments, and AI-assisted workflows without leaving the command line.

## SQLcl from PowerShell

Oracle SQLcl is the modern command-line interface for Oracle Database and can be driven directly from PowerShell scripts, including wallet-based connections to Autonomous Database [1].

Typical pattern for connecting to an Autonomous Database with a downloaded wallet:

```powershell
$wallet = "C:\Users\<You>\Downloads\Wallet.zip"
& "C:\sqlcl-latest\sqlcl\bin\sql.exe" `
  -cloudconfig $wallet `
  <user>/<password>@<tns_alias>
```

Keep the wallet as a ZIP archive rather than extracting it, and save a named connection (`-save <name> -savepwd`) so later automation and MCP tooling can reconnect without a password prompt [1].

## MCP Server Mode

Starting SQLcl in MCP server mode from a PowerShell terminal exposes the same tool set used by AI IDEs and assistants (listing connections, running SQL/PL-SQL, executing scripts), letting an AI client on Windows drive the database through natural-language requests translated into SQL [2][3].

### Prerequisites
* SQLcl 25.2 or later
* Java 17+ available on `PATH`
* A saved SQLcl connection (created once, reused by the MCP server)

## Notes for Contributors
* Prefer wallet ZIPs over extracted folders in examples — this is the most common PowerShell setup mistake.
* Scripts should avoid embedding plaintext passwords; use `-savepwd` with a saved connection instead.

## References

[1] Oracle Analytics Blog. (2025). *Unlock AI-Powered Insights from OAC Logs via SQLcl MCP Server*. https://blogs.oracle.com/analytics/unlock-ai-powered-insights-from-oac-logs-via-sqlcl-mcp-server
[2] Oracle Blogs. (2025, July 16). *Introducing MCP Server for Oracle Database*. https://blogs.oracle.com/database/introducing-mcp-server-for-oracle-database
[3] Oracle Docs. *Using the Oracle SQLcl MCP Server*. https://docs.oracle.com/en/database/oracle/sql-developer-command-line/26.2/sqcug/using-oracle-sqlcl-mcp-server.html
