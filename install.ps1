# tradingview-mcp-pelegdror - one-command installer (Windows PowerShell)
#
# Installs from scratch on a blank Windows machine:
#   git, Node.js 18+, Claude Code, this repo, npm deps, rules.json,
#   MCP server registration with Claude Code.
#
# Usage (open PowerShell, paste this line):
#   irm https://raw.githubusercontent.com/peleg-jpg/tradingview-mcp-pelegdror/main/install.ps1 | iex
#
# Override install location:
#   $env:INSTALL_DIR = "C:\my\path"; irm ... | iex
#
# Re-running the script is safe. It skips anything already installed.

$ErrorActionPreference = "Stop"

$RepoUrl     = "https://github.com/peleg-jpg/tradingview-mcp-pelegdror.git"
$InstallDir  = if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { Join-Path $HOME "tradingview-mcp-pelegdror" }
$CdpPort     = 9222

function Say   ($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Warn  ($msg) { Write-Host "!!  $msg" -ForegroundColor Yellow }
function Ok    ($msg) { Write-Host "ok  $msg" -ForegroundColor Green }
function Have  ($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

Say "Detected: Windows"

# winget is the package manager. Preinstalled on Windows 10 1809+ / 11 with App Installer.
if (-not (Have "winget")) {
    Warn "winget not found. Two ways to get it:"
    Warn "  1. Open Microsoft Store, search 'App Installer', click Install. Then re-run this script."
    Warn "  2. On Windows Server / LTSC, download from https://github.com/microsoft/winget-cli/releases"
    Warn "Or, install git + Node.js 18+ manually, then re-run this script (it will pick up from there)."
    exit 1
}

# Refresh PATH so binaries installed by winget in this session are visible.
# Reads Machine + User PATH from the registry. Note: cached PowerShell command lookups
# may still miss freshly installed binaries; if you hit that, open a new PowerShell and re-run.
function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

# -------- 1. git --------
if (Have "git") {
    Ok "git already installed ($(git --version))"
} else {
    Say "Installing git..."
    winget install --id Git.Git --silent --accept-source-agreements --accept-package-agreements
    Refresh-Path
}

# -------- 2. Node.js 18+ --------
$needNode = $true
if (Have "node") {
    $nodeMajor = ((node -v) -replace "v","" -split "\.")[0] -as [int]
    if ($nodeMajor -ge 18) {
        Ok "node already installed ($(node -v))"
        $needNode = $false
    } else {
        Warn "node $nodeMajor detected, need 18+. Upgrading..."
    }
}
if ($needNode) {
    Say "Installing Node.js LTS..."
    winget install --id OpenJS.NodeJS.LTS --silent --accept-source-agreements --accept-package-agreements
    Refresh-Path
}

# -------- 3. Claude Code --------
if (Have "claude") {
    Ok "Claude Code already installed"
} else {
    Say "Installing Claude Code..."
    npm install -g "@anthropic-ai/claude-code"
}

# -------- 4. TradingView Desktop --------
$tvPath = Join-Path $env:LOCALAPPDATA "TradingView\TradingView.exe"
$script:tvInstalled = $true
if (Test-Path $tvPath) {
    Ok "TradingView Desktop already installed"
} else {
    Say "Installing TradingView Desktop..."
    # Correct winget PackageIdentifier is TradingView.TradingViewDesktop
    winget install --id TradingView.TradingViewDesktop --silent --accept-source-agreements --accept-package-agreements 2>$null
    if ($LASTEXITCODE -ne 0) {
        Warn "winget install of TradingView Desktop failed (exit $LASTEXITCODE)."
        Warn "Download manually from https://www.tradingview.com/desktop/ and re-run this script."
        $script:tvInstalled = $false
    } else {
        Ok "TradingView Desktop installed"
    }
}

# -------- 5. clone repo --------
if (Test-Path (Join-Path $InstallDir ".git")) {
    Say "Repo exists at $InstallDir, pulling latest..."
    git -C $InstallDir pull --ff-only
} else {
    Say "Cloning into $InstallDir..."
    git clone $RepoUrl $InstallDir
}

# -------- 6. npm install --------
Say "Installing npm dependencies..."
Push-Location $InstallDir
npm install --silent
Pop-Location

# -------- 7. rules.json --------
$rulesPath   = Join-Path $InstallDir "rules.json"
$examplePath = Join-Path $InstallDir "rules.example.json"
if (Test-Path $rulesPath) {
    Ok "rules.json already exists (not overwriting)"
} else {
    Copy-Item $examplePath $rulesPath
    Ok "Created rules.json from example"
}

# -------- 8. register MCP server --------
$script:mcpRegistered = $false
if (Have "claude") {
    Say "Registering MCP server with Claude Code..."
    $serverPath = Join-Path $InstallDir "src\server.js"
    # Use 'claude mcp get' which exits non-zero if not registered (more reliable than parsing list output)
    claude mcp get tradingview 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Ok "tradingview MCP server already registered"
        $script:mcpRegistered = $true
    } else {
        claude mcp add --scope user tradingview node $serverPath 2>$null
        if ($LASTEXITCODE -eq 0) {
            Ok "MCP server registered"
            $script:mcpRegistered = $true
        } else {
            Warn "Could not register MCP server (claude may need authentication first)."
            Warn "After running 'claude' to log in, run:"
            Warn "  claude mcp add --scope user tradingview node `"$serverPath`""
        }
    }
}

# -------- open rules.json for the user to edit --------
try { Start-Process notepad $rulesPath } catch { }

# -------- final message --------
Write-Host ""
Write-Host "================ INSTALL COMPLETE ================" -ForegroundColor Green
Write-Host ""

if (-not $script:tvInstalled) {
    Write-Host "!! TradingView Desktop did not install automatically." -ForegroundColor Yellow
    Write-Host "   Download it from https://www.tradingview.com/desktop/ BEFORE step 3 below."
    Write-Host ""
}
if (-not $script:mcpRegistered) {
    Write-Host "!! MCP server was not registered (you need to authenticate Claude Code first)." -ForegroundColor Yellow
    Write-Host "   After step 1 below, also run:"
    Write-Host "     claude mcp add --scope user tradingview node `"$serverPath`""
    Write-Host ""
}

Write-Host "What's left for you to do (5 quick steps):"
Write-Host ""
Write-Host "  1. Authenticate Claude Code:"
Write-Host "       claude"
Write-Host "     A browser opens to log you in. When done, type /exit and press Enter."
Write-Host ""
Write-Host "  2. Open TradingView Desktop. Log in with your account."
Write-Host "     Then fully quit it: right-click the dock icon -> Quit (Cmd-Q does the same)."
Write-Host "     (Closing the window is NOT enough; the app keeps running in background.)"
Write-Host ""
Write-Host "  3. Relaunch TradingView with the debug port enabled:"
Write-Host "       & '$tvPath' --remote-debugging-port=$CdpPort"
Write-Host ""
Write-Host "  4. (Notepad just opened your rules.json. Fill in your watchlist + bias criteria + risk rules and save.)"
Write-Host ""
Write-Host "  5. Open a NEW terminal, run 'claude', and ask:"
Write-Host "       Run tv_health_check"
Write-Host ""
Write-Host "     Expected: { 'success': true, 'cdp_connected': true, ... }"
Write-Host ""
Write-Host "Full guide: $InstallDir\SETUP_GUIDE.md"
Write-Host "Web guide:  start $InstallDir\previews\setup-guide.html"
Write-Host ""
