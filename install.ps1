# tradingview-mcp-pelegdror - one-command installer (Windows PowerShell)
#
# Installs from scratch on a blank Windows machine:
#   git, Node.js 18+, Claude Code, this repo, npm deps, rules.json,
#   MCP server registration with Claude Code.
#
# Usage (open PowerShell, paste this line):
#   irm https://raw.githubusercontent.com/pelegdror/tradingview-mcp-pelegdror/main/install.ps1 | iex
#
# Override install location:
#   $env:INSTALL_DIR = "C:\my\path"; irm ... | iex
#
# Re-running the script is safe. It skips anything already installed.

$ErrorActionPreference = "Stop"

$RepoUrl     = "https://github.com/pelegdror/tradingview-mcp-pelegdror.git"
$InstallDir  = if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { Join-Path $HOME "tradingview-mcp-pelegdror" }
$CdpPort     = 9222

function Say   ($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Warn  ($msg) { Write-Host "!!  $msg" -ForegroundColor Yellow }
function Ok    ($msg) { Write-Host "ok  $msg" -ForegroundColor Green }
function Have  ($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

Say "Detected: Windows"

# winget is the package manager. It's preinstalled on Windows 10 1809+ / 11.
if (-not (Have "winget")) {
    Warn "winget not found. Install it from the Microsoft Store ('App Installer') and re-run this script."
    exit 1
}

# -------- 1. git --------
if (Have "git") {
    Ok "git already installed ($(git --version))"
} else {
    Say "Installing git..."
    winget install --id Git.Git --silent --accept-source-agreements --accept-package-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
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
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
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
if (Test-Path $tvPath) {
    Ok "TradingView Desktop already installed"
} else {
    Say "Installing TradingView Desktop..."
    $tvWinget = winget search --id TradingView.TradingView 2>$null
    if ($tvWinget -match "TradingView.TradingView") {
        winget install --id TradingView.TradingView --silent --accept-source-agreements --accept-package-agreements
    } else {
        Warn "TradingView Desktop not in winget. Download manually from https://www.tradingview.com/desktop/"
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
if (Have "claude") {
    Say "Registering MCP server with Claude Code..."
    $serverPath = Join-Path $InstallDir "src\server.js"
    $existing = claude mcp list 2>$null | Select-String "^tradingview"
    if ($existing) {
        Ok "tradingview MCP server already registered"
    } else {
        try {
            claude mcp add --scope user tradingview node $serverPath
            Ok "MCP server registered"
        } catch {
            Warn "Could not register MCP server. Run this manually after authenticating Claude Code:"
            Warn "  claude mcp add --scope user tradingview node `"$serverPath`""
        }
    }
}

# -------- final message --------
Write-Host ""
Write-Host "================ INSTALL COMPLETE ================" -ForegroundColor Green
Write-Host ""
Write-Host "Manual steps remaining (each takes ~30 seconds):"
Write-Host ""
Write-Host "  1. First time using Claude Code? Authenticate:"
Write-Host "       claude"
Write-Host "     ...and follow the browser login prompt. Then /exit."
Write-Host ""
Write-Host "  2. Open TradingView Desktop, log in, then quit it completely."
Write-Host ""
Write-Host "  3. Relaunch TradingView with the debug port:"
Write-Host "       & '$tvPath' --remote-debugging-port=$CdpPort"
Write-Host ""
Write-Host "  4. Edit your trading rules:"
Write-Host "       notepad $rulesPath"
Write-Host ""
Write-Host "  5. Restart Claude Code, then ask:"
Write-Host "       Run tv_health_check"
Write-Host ""
Write-Host "     Expected: { 'success': true, 'cdp_connected': true, ... }"
Write-Host ""
Write-Host "Full guide: $InstallDir\SETUP_GUIDE.md"
Write-Host "Web guide:  start $InstallDir\previews\setup-guide.html"
Write-Host ""
