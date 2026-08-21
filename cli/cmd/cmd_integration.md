# Windows Command Prompt (cmd.exe) Integration with Oracle AI

Many Oracle installers, batch files, and legacy automation on Windows still run through the classic `cmd.exe` shell rather than PowerShell. SQLcl and its MCP server work the same way here, with a few `cmd`-specific conventions.

## Launching SQLcl

From `cmd.exe`, SQLcl is started the same way as any other console tool, using batch-file quoting instead of PowerShell's backtick line continuation:

```bat
"C:\sqlcl-latest\sqlcl\bin\sql.exe" -cloudconfig "C:\Users\%USERNAME%\Downloads\Wallet.zip" user/password@tns_alias
```

As with PowerShell, keep the Autonomous Database wallet as a ZIP file — pointing SQLcl at an already-extracted folder is a common connection failure [1].

## Running SQLcl as an MCP Server

SQLcl 25.2+ (Java 17+ required) can be launched from a `cmd.exe` window in MCP server mode so that AI assistants such as Claude Desktop, GitHub Copilot, or VS Code extensions can issue natural-language requests that are translated into SQL and PL/SQL executed against the connected database [2][3]. The server keeps credentials on the local machine and streams results back to the AI client rather than sending data to Oracle directly [2].

## Batch Script Tips
* Use `%~dp0` to build paths relative to the batch file's own location when wiring SQLcl into a larger `.bat` automation pipeline.
* Store connection names with `-save <name> -savepwd` once interactively, then reference `-name <name>` in unattended batch jobs instead of embedding credentials.

## References

[1] Oracle Analytics Blog. (2025). *Unlock AI-Powered Insights from OAC Logs via SQLcl MCP Server*. https://blogs.oracle.com/analytics/unlock-ai-powered-insights-from-oac-logs-via-sqlcl-mcp-server
[2] DreamFactory. (2026). *How to Set Up an MCP Server for Oracle Databases*. https://www.dreamfactory.com/hub/set-up-mcp-server-for-oracle-databases/
[3] Oracle Blogs. (2025, July 16). *Introducing MCP Server for Oracle Database*. https://blogs.oracle.com/database/introducing-mcp-server-for-oracle-database
