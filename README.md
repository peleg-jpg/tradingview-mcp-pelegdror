# TradingView MCP Pelegdror

If you found this from the YouTube video — welcome. This is the improved fork. Everything you need is below.

Built on top of the original [tradingview-mcp](https://github.com/tradesdontlie/tradingview-mcp) by [@tradesdontlie](https://github.com/tradesdontlie). Full credit to them for the foundation. This fork adds a morning brief workflow, a rules config, and fixes the launch bug on TradingView Desktop v2.14+.

> [!WARNING]
> **Not affiliated with TradingView Inc. or Anthropic.** This tool connects to your locally running TradingView Desktop app via Chrome DevTools Protocol. Review the [Disclaimer](#disclaimer) before use.

> [!IMPORTANT]
> **Requires a valid TradingView subscription.** This tool does not bypass any TradingView paywall. It reads from and controls the TradingView Desktop app already running on your machine.

> [!NOTE]
> **All data processing happens locally.** Nothing is sent anywhere. No TradingView data leaves your machine.

---

## What's New in This Fork

| Feature                        | What it does                                                                                                                           |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------- |
| `morning_brief`                | One command that scans your watchlist, reads all your indicators, and returns structured data for Claude to generate your session bias |
| `session_save` / `session_get` | Saves your daily brief to `~/.tradingview-mcp/sessions/` so you can compare today vs yesterday                                         |
| `rules.json`                   | Write your trading rules once — bias criteria, risk rules, watchlist. The morning brief applies them automatically every day           |
| Launch bug fix                 | Fixed `tv_launch` compatibility with TradingView Desktop v2.14+                                                                        |
| `tv brief` CLI                 | Run your morning brief from the terminal in one word                                                                                   |

---

## One-Command Install (recommended)

Bootstraps everything on a blank machine: git, Node.js, Claude Code, TradingView Desktop (Mac via Homebrew), the repo, npm deps, and registers the MCP server. Safe to re-run.

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/peleg-jpg/tradingview-mcp-pelegdror/main/install.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/peleg-jpg/tradingview-mcp-pelegdror/main/install.ps1 | iex
```

When the script finishes, follow the 5 short manual steps it prints (authenticate Claude Code, launch TradingView with the debug port, fill in `rules.json`, run `tv_health_check`).

Full walkthrough: [previews/setup-guide.html](previews/setup-guide.html) or [SETUP_GUIDE.md](SETUP_GUIDE.md).

---

## Or, Have Claude Code Set It Up

If you already have Claude Code installed, paste this prompt and it will handle the rest:

```
Set up TradingView MCP Pelegdror for me.
Clone https://github.com/peleg-jpg/tradingview-mcp-pelegdror.git to ~/tradingview-mcp-pelegdror, run npm install, then register it with: claude mcp add --scope user tradingview node ~/tradingview-mcp-pelegdror/src/server.js
Then copy rules.example.json to rules.json and open it so I can fill in my trading rules.
Finally restart and verify with tv_health_check.
```

---

## Prerequisites

- **TradingView Desktop app** (paid subscription required for real-time data)
- **Node.js 18+**
- **Claude Code** (for MCP tools) or any terminal (for CLI)
- **macOS, Windows, or Linux**

---

## Quick Start

### 1. Clone and install

```bash
git clone https://github.com/peleg-jpg/tradingview-mcp-pelegdror.git ~/tradingview-mcp-pelegdror
cd ~/tradingview-mcp-pelegdror
npm install
```

### 2. Set up your rules

```bash
cp rules.example.json rules.json
```

Open `rules.json` and fill in:

- Your **watchlist** (symbols to scan each morning)
- Your **bias criteria** (what makes something bullish/bearish/neutral for you)
- Your **risk rules** (the rules you want Claude to check before every session)

### 3. Launch TradingView with CDP

TradingView must be running with the debug port enabled.

**Mac:**

```bash
./scripts/launch_tv_debug_mac.sh
```

**Windows:**

```bash
scripts\launch_tv_debug.bat
```

**Linux:**

```bash
./scripts/launch_tv_debug_linux.sh
```

Or use the MCP tool after setup: `"Use tv_launch to start TradingView in debug mode"`

### 4. Add to Claude Code

Use the official CLI; it validates the entry and writes to the correct config file (`~/.claude.json` under `mcpServers`):

```bash
claude mcp add --scope user tradingview node ~/tradingview-mcp-pelegdror/src/server.js
```

Verify with `claude mcp list`. You should see `tradingview` in the output.

### 5. Verify

Restart Claude Code, then ask: _"Use tv_health_check to verify TradingView is connected"_

### 6. Run your first morning brief

Ask Claude: _"Run morning_brief and give me my session bias"_

Or from the terminal:

```bash
npm link  # install tv CLI globally (one time)
tv brief
```

---

## Morning Brief Workflow

This is the feature that turns this from a toolkit into a daily habit.

**Before every session:**

1. TradingView is open (launched with debug port)
2. Run: `tv brief` in your terminal (or ask Claude: _"run morning_brief"_)
3. Claude scans every symbol in your watchlist, reads your indicator values, applies your `rules.json` criteria, and prints:

```
BTCUSD  | BIAS: Bearish  | KEY LEVEL: 94,200  | WATCH: RSI crossing 50 on 4H
ETHUSD  | BIAS: Neutral  | KEY LEVEL: 3,180   | WATCH: Ribbon direction on daily
SOLUSD  | BIAS: Bullish  | KEY LEVEL: 178.50  | WATCH: Hold above 20 EMA

Overall: Cautious session. BTC leading bearish, SOL the exception — watch for divergence.
```

4. Save it: _"save this brief"_ (uses `session_save`)
5. Next morning, compare: _"get yesterday's session"_ (uses `session_get`)

---

## What This Tool Does

- **Morning brief** — scan watchlist, read indicators, apply your rules, print session bias
- **Pine Script development** — write, inject, compile, debug scripts with AI
- **Chart navigation** — change symbols, timeframes, zoom to dates, add/remove indicators
- **Visual analysis** — read indicator values, price levels, drawn levels from custom indicators
- **Draw on charts** — trend lines, horizontal levels, rectangles, text
- **Manage alerts** — create, list, delete price alerts
- **Replay practice** — step through historical bars, practice entries and exits with P&L tracking
- **Screenshots** — capture chart state
- **Multi-pane layouts** — 2x2, 3x1 grids with different symbols per pane
- **Stream data** — JSONL output from your live chart for monitoring scripts
- **CLI access** — every tool is also a `tv` command, pipe-friendly JSON output

---

## How Claude Knows Which Tool to Use

Claude reads `CLAUDE.md` automatically when working in this project. It contains the full decision tree.

| You say...                    | Claude uses...                                                                                                |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------- |
| "Run my morning brief"        | `morning_brief` → apply rules → `session_save`                                                                |
| "What was my bias yesterday?" | `session_get`                                                                                                 |
| "What's on my chart?"         | `chart_get_state` → `data_get_study_values` → `quote_get`                                                     |
| "Give me a full analysis"     | `quote_get` → `data_get_study_values` → `data_get_pine_lines` → `data_get_pine_labels` → `capture_screenshot` |
| "Switch to BTCUSD daily"      | `chart_set_symbol` → `chart_set_timeframe`                                                                    |
| "Write a Pine Script for..."  | `pine_set_source` → `pine_smart_compile` → `pine_get_errors`                                                  |
| "Start replay at March 1st"   | `replay_start` → `replay_step` → `replay_trade`                                                               |
| "Set up a 4-chart grid"       | `pane_set_layout` → `pane_set_symbol`                                                                         |
| "Draw a level at 94200"       | `draw_shape` (horizontal_line)                                                                                |

---

## Bundled Skills (5 ready-to-use slash commands)

The repo ships 5 "skills" in [skills/](skills/) and 1 subagent in [agents/](agents/). These are not auto-installed by the one-liner; copy them into your Claude config and they become slash commands you can type in any project.

**Install them:**

```bash
mkdir -p ~/.claude/skills ~/.claude/agents
cp -r ~/tradingview-mcp-pelegdror/skills/* ~/.claude/skills/
cp ~/tradingview-mcp-pelegdror/agents/performance-analyst.md ~/.claude/agents/
```

Then restart Claude Code. Type `/` and you'll see them in the menu.

### What each one does (plain English)

**`/chart-analysis`** - "Look at this chart and tell me what I'm seeing."
Pulls up the symbol, slaps RSI/EMA/MACD/whatever on it, screenshots the result, then tells you the current price, key support and resistance, what the indicators are saying, and a bullish/bearish/neutral read with reasoning. Like having an analyst look over your shoulder for 30 seconds.

**`/multi-symbol-scan`** - "Compare these 5 tickers, which one's set up best right now?"
Loops through a watchlist or any list you give it (e.g. `[ES1!, NQ1!, YM1!, RTY1!]`), checks each one against your criteria (indicator readings, strategy results, visual patterns), and ranks them. Screenshots the top 1-2. A conversational screener.

**`/pine-develop`** - "Build me an indicator/strategy that does X."
Writes the Pine Script v6 code, pushes it into your TradingView Pine Editor, hits compile, reads the errors, fixes them itself, and repeats until 0 errors. Then screenshots the working result so you can verify. Removes the whole "switching between Pine Editor and Stack Overflow" loop.

**`/replay-practice`** - "Let's paper trade March 2024 like it's live."
Rewinds the chart to a date you pick, steps through bars one at a time (or autoplays at your chosen speed). When you say "buy" or "sell", it places the trade. Tracks your P&L. Reviews the session at the end with stats and lessons. Pure practice mode without real money.

**`/strategy-report`** - "Tell me if this strategy is actually any good."
After you backtest a Pine strategy, generates a full performance breakdown: net profit, win rate, profit factor (target >1.5), max drawdown, average winner vs loser, equity curve shape, long vs short performance, time in market. Ends with concrete recommendations like "win rate <50% but profit factor >1, tighten your entries" or "max drawdown >20%, fix your position sizing."

**`performance-analyst`** (subagent, not a slash command) - Same intent as `/strategy-report` but heavier. A dedicated Sonnet-powered subagent runs the full report autonomously so your main chat stays clean. Invoke via the Agent tool with `subagent_type: "performance-analyst"`.

---

## Tool Reference (81 MCP tools)

### Morning Brief (new in this fork)

| Tool            | What it does                                                                                                |
| --------------- | ----------------------------------------------------------------------------------------------------------- |
| `morning_brief` | Scan watchlist, read indicators, return structured data for session bias. Reads `rules.json` automatically. |
| `session_save`  | Save the generated brief to `~/.tradingview-mcp/sessions/YYYY-MM-DD.json`                                   |
| `session_get`   | Retrieve today's brief (or yesterday's if today not saved yet)                                              |

### Chart Reading

| Tool                    | When to use                                                   | Output size                     |
| ----------------------- | ------------------------------------------------------------- | ------------------------------- |
| `chart_get_state`       | First call — get symbol, timeframe, all indicator names + IDs | ~500B                           |
| `data_get_study_values` | Read current RSI, MACD, BB, EMA values from all indicators    | ~500B                           |
| `quote_get`             | Get latest price, OHLC, volume                                | ~200B                           |
| `data_get_ohlcv`        | Get price bars. **Use `summary: true`** for compact stats     | 500B (summary) / 8KB (100 bars) |

### Custom Indicator Data (Pine Drawings)

Read `line.new()`, `label.new()`, `table.new()`, `box.new()` output from any visible Pine indicator.

| Tool                   | When to use                                                  |
| ---------------------- | ------------------------------------------------------------ |
| `data_get_pine_lines`  | Horizontal price levels (support/resistance, session levels) |
| `data_get_pine_labels` | Text annotations + prices ("PDH 24550", "Bias Long")         |
| `data_get_pine_tables` | Data tables (session stats, analytics dashboards)            |
| `data_get_pine_boxes`  | Price zones as {high, low} pairs                             |

**Always use `study_filter`** to target a specific indicator: `study_filter: "MyIndicator"`.

### Chart Control

| Tool                                                   | What it does                                                                   |
| ------------------------------------------------------ | ------------------------------------------------------------------------------ |
| `chart_set_symbol`                                     | Change ticker (BTCUSD, AAPL, ES1!, NYMEX:CL1!)                                 |
| `chart_set_timeframe`                                  | Change resolution (1, 5, 15, 60, D, W, M)                                      |
| `chart_set_type`                                       | Change style (Candles, HeikinAshi, Line, Area, Renko)                          |
| `chart_manage_indicator`                               | Add/remove indicators. **Use full names**: "Relative Strength Index" not "RSI" |
| `chart_scroll_to_date`                                 | Jump to a date (ISO: "2025-01-15")                                             |
| `indicator_set_inputs` / `indicator_toggle_visibility` | Change indicator settings, show/hide                                           |

### Pine Script Development

| Tool                 | Step                                         |
| -------------------- | -------------------------------------------- |
| `pine_set_source`    | 1. Inject code into editor                   |
| `pine_smart_compile` | 2. Compile with auto-detection + error check |
| `pine_get_errors`    | 3. Read compilation errors if any            |
| `pine_get_console`   | 4. Read log.info() output                    |
| `pine_save`          | 5. Save to TradingView cloud                 |
| `pine_analyze`       | Offline static analysis (no chart needed)    |
| `pine_check`         | Server-side compile check (no chart needed)  |

### Replay Mode

| Tool              | Step                           |
| ----------------- | ------------------------------ |
| `replay_start`    | Enter replay at a date         |
| `replay_step`     | Advance one bar                |
| `replay_autoplay` | Auto-advance (set speed in ms) |
| `replay_trade`    | Buy/sell/close positions       |
| `replay_status`   | Check position, P&L, date      |
| `replay_stop`     | Return to realtime             |

### Multi-Pane, Alerts, Drawings, UI

| Tool                                           | What it does                                       |
| ---------------------------------------------- | -------------------------------------------------- |
| `pane_set_layout`                              | Change grid: `s`, `2h`, `2v`, `2x2`, `4`, `6`, `8` |
| `pane_set_symbol`                              | Set symbol on any pane                             |
| `draw_shape`                                   | Draw horizontal_line, trend_line, rectangle, text  |
| `alert_create` / `alert_list` / `alert_delete` | Manage price alerts                                |
| `batch_run`                                    | Run action across multiple symbols/timeframes      |
| `watchlist_get` / `watchlist_add`              | Read/modify watchlist                              |
| `capture_screenshot`                           | Screenshot (regions: full, chart, strategy_tester) |
| `tv_launch` / `tv_health_check`                | Launch TradingView and verify connection           |

---

## CLI Commands

```bash
tv brief                           # run morning brief
tv session get                     # get today's saved brief
tv session save --brief "..."      # save a brief

tv status                          # check connection
tv quote                           # current price
tv symbol BTCUSD                   # change symbol
tv ohlcv --summary                 # price summary
tv screenshot -r chart             # capture chart
tv pine compile                    # compile Pine Script
tv pane layout 2x2                 # 4-chart grid
tv stream quote | jq '.close'      # monitor price ticks
```

Full command list: `tv --help`

---

## Troubleshooting

| Problem                                 | Solution                                                                                      |
| --------------------------------------- | --------------------------------------------------------------------------------------------- |
| `cdp_connected: false`                  | TradingView isn't running with `--remote-debugging-port=9222`. Use the launch script.         |
| `ECONNREFUSED`                          | TradingView isn't running or port 9222 is blocked                                             |
| MCP server not showing in Claude Code   | Run `claude mcp list` to verify. If missing, re-run step 4. Config lives in `~/.claude.json`. |
| `tv` command not found                  | Run `npm link` from the project directory                                                     |
| `morning_brief` — "No rules.json found" | Run `cp rules.example.json rules.json` and fill it in                                         |
| `morning_brief` — watchlist empty       | Add symbols to the `watchlist` array in `rules.json`                                          |
| Tools return stale data                 | TradingView still loading — wait a few seconds                                                |
| Pine Editor tools fail                  | Open Pine Editor panel first: `ui_open_panel pine-editor open`                                |

---

## Architecture

```
Claude Code  ←→  MCP Server (stdio)  ←→  CDP (port 9222)  ←→  TradingView Desktop (Electron)
```

- **78 original tools** + **3 morning brief tools** = 81 MCP tools total
- **Transport**: MCP over stdio + CLI (`tv` command)
- **Connection**: Chrome DevTools Protocol on localhost:9222
- **No external network calls** — everything runs locally
- **Zero extra dependencies** beyond the original

---

## Credits

This fork is built on [tradingview-mcp](https://github.com/tradesdontlie/tradingview-mcp) by [@tradesdontlie](https://github.com/tradesdontlie). The original tool is the foundation — go star their repo.

---

## Disclaimer

This project is provided **for personal, educational, and research purposes only**.

This tool uses the Chrome DevTools Protocol (CDP), a standard debugging interface built into all Chromium-based applications. It does not reverse engineer any proprietary TradingView protocol, connect to TradingView's servers, or bypass any access controls. The debug port must be explicitly enabled by the user via a standard Chromium command-line flag.

By using this software you agree that:

1. You are solely responsible for ensuring your use complies with [TradingView's Terms of Use](https://www.tradingview.com/policies/) and all applicable laws.
2. This tool accesses undocumented internal TradingView APIs that may change at any time.
3. This tool must not be used to redistribute, resell, or commercially exploit TradingView's market data.
4. The authors are not responsible for any account bans, suspensions, or other consequences.

**Use at your own risk.**

## License

MIT — see [LICENSE](LICENSE). Applies to source code only, not to TradingView's software, data, or trademarks.
