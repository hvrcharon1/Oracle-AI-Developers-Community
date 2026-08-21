# CLI Integration with Oracle AI

Not every Oracle AI Database workflow happens inside an IDE. This folder covers driving Oracle AI Database — and the Oracle SQLcl MCP Server — directly from the command line, across the shells developers actually use day to day.

## Why a Separate CLI Section

The `ides/` folder covers editor-integrated experiences (VS Code, Cursor, SQL Developer, and so on). This folder is for the terminal itself: scripting SQLcl connections, running the MCP server headlessly for AI clients, and automating database tasks in CI/CD pipelines, cron jobs, and systemd services where no IDE is involved.

## Subfolders

*   **[powershell/](powershell/powershell_integration.md)** — Connecting to Oracle AI Database and running the SQLcl MCP Server from Windows PowerShell, including wallet-based Autonomous Database connections.
*   **[cmd/](cmd/cmd_integration.md)** — The same workflows adapted for the classic Windows `cmd.exe` shell and `.bat` automation.
*   **[linux_terminal/](linux_terminal/linux_terminal_integration.md)** — Installing and running SQLcl and its MCP Server on Linux (bash/zsh), plus tips for unattended shell scripts and session auditing.

## Common Ground Across Shells

Regardless of shell, the underlying tool is the same: **Oracle SQLcl**, a free command-line interface for Oracle Database that can also run as an MCP Server, exposing tools like listing saved connections, running SQL and PL/SQL, and executing scripts to any MCP-compatible AI client. SQLcl requires Java 17+ and runs locally, keeping credentials and query data on the machine it's installed on rather than sending them to Oracle.

## Contributing

If you use a shell not yet covered here (e.g. `fish`, `nushell`, or a container-based CLI workflow), feel free to add a subfolder following the same pattern: a short integration guide with setup steps, an MCP server section, and a References list for any sources cited.
