# Setup Guide for Claude Code

This file is a step-by-step guide for Claude Code (or any LLM agent) to install and configure the TradingView MCP server. If a user asks you to install or set up this project, follow these steps exactly.

## Fastest path: one-command install

If the user just wants it working with one command, run the appropriate installer:

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/peleg-jpg/tradingview-mcp-pelegdror/main/install.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/peleg-jpg/tradingview-mcp-pelegdror/main/install.ps1 | iex
```

That script handles steps 1-3 below automatically and registers the MCP server via `claude mcp add`. Then continue with steps 4-7 manually (TradingView login + debug-port launch, rules.json edits, restart, verify).

For a guided manual install, follow each step below.

## Step 1: Clone and Install

```bash
git clone https://github.com/peleg-jpg/tradingview-mcp-pelegdror.git ~/tradingview-mcp-pelegdror
cd ~/tradingview-mcp-pelegdror
npm install
```

If the user specifies a different install path, use that instead of `~/tradingview-mcp-pelegdror`.

## Step 2: Set Up Rules

Copy the example rules file and open it for the user to fill in:

```bash
cp ~/tradingview-mcp-pelegdror/rules.example.json ~/tradingview-mcp-pelegdror/rules.json
```

Tell the user: "Open `rules.json` and fill in your watchlist (the symbols you trade), your bias criteria (what makes something bullish/bearish for you), and your risk rules. This is what the morning brief uses every day."

## Step 3: Register with Claude Code

Use the official CLI; it validates the entry and writes to the correct config file (`~/.claude.json` under `mcpServers`, not `~/.claude/.mcp.json`).

```bash
claude mcp add --scope user tradingview node ~/tradingview-mcp-pelegdror/src/server.js
```

- `--scope user`: server is available in every project on this machine (recommended).
- `--scope project`: writes `.mcp.json` in current directory, commits with the repo (for shared team setups).
- `--scope local` (default): current project only, machine-local.

Verify with:

```bash
claude mcp list
claude mcp get tradingview
```

## Step 4: Launch TradingView Desktop

TradingView Desktop must be running with Chrome DevTools Protocol enabled.

**Auto-detect and launch (recommended):**
After the MCP server is connected, use the `tv_launch` tool — it auto-detects TradingView on Mac, Windows, and Linux.

**Manual launch by platform:**

Mac (TradingView Desktop v2.14+ requires the `open -a ... --args` form; the bare binary path will fail with `bad option`):

```bash
open -a TradingView --args --remote-debugging-port=9222
```

Windows:

```bash
%LOCALAPPDATA%\TradingView\TradingView.exe --remote-debugging-port=9222
```

Linux:

```bash
/opt/TradingView/tradingview --remote-debugging-port=9222
# or: tradingview --remote-debugging-port=9222
```

## Step 5: Restart Claude Code

The MCP server only loads when Claude Code starts. After adding the config:

1. Exit Claude Code by typing `/exit` (Ctrl+C only interrupts the current operation, it doesn't quit)
2. Relaunch with `claude`
3. The tradingview MCP server connects automatically

## Step 6: Verify Connection

Use the `tv_health_check` tool. Expected response:

```json
{
  "success": true,
  "cdp_connected": true,
  "chart_symbol": "...",
  "api_available": true
}
```

If `cdp_connected: false`, TradingView is not running with `--remote-debugging-port=9222`.

## Step 7: Run Your First Morning Brief

Ask Claude: _"Run morning_brief and give me my session bias"_

Claude will scan your watchlist, read your indicators, apply your `rules.json` criteria, and print your bias for each symbol.

To save it: _"Save this brief using session_save"_

To retrieve tomorrow: _"Get yesterday's session using session_get"_

## Step 8: Install CLI (Optional)

To use the `tv` CLI command globally:

```bash
cd ~/tradingview-mcp-pelegdror
npm link
```

Then `tv status`, `tv quote`, `tv pine compile`, etc. work from anywhere.

## Troubleshooting

| Problem                               | Solution                                                                                       |
| ------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `cdp_connected: false`                | Launch TradingView with `--remote-debugging-port=9222` (Mac: `open -a TradingView --args ...`) |
| `ECONNREFUSED`                        | TradingView isn't running or port 9222 is blocked                                              |
| MCP server not showing in Claude Code | Run `claude mcp list` to verify. If missing, re-run step 3. Config lives in `~/.claude.json`.  |
| `tv` command not found                | Run `npm link` from the project directory                                                      |
| Tools return stale data               | TradingView may still be loading, wait a few seconds                                           |
| Pine Editor tools fail                | Open the Pine Editor panel first (`ui_open_panel pine-editor open`)                            |

## What to Read Next

- `rules.json` — Your personal trading rules (fill this in before using morning_brief)
- `CLAUDE.md` — Decision tree for which tool to use when (auto-loaded by Claude Code)
- `README.md` — Full tool reference including morning brief workflow
- `RESEARCH.md` — Research context and open questions
