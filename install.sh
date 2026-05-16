#!/usr/bin/env bash
#
# tradingview-mcp-pelegdror - one-command installer (macOS + Linux)
#
# Installs from scratch on a blank machine:
#   git, Node.js 18+, Claude Code, TradingView Desktop (Mac only via brew),
#   this repo, npm deps, rules.json, MCP server registration with Claude Code.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/pelegdror/tradingview-mcp-pelegdror/main/install.sh | bash
#
# Override install location:
#   INSTALL_DIR=/custom/path curl -fsSL ... | bash
#
# Re-running the script is safe. It skips anything already installed.

set -euo pipefail

REPO_URL="https://github.com/pelegdror/tradingview-mcp-pelegdror.git"
INSTALL_DIR="${INSTALL_DIR:-$HOME/tradingview-mcp-pelegdror}"
CDP_PORT=9222

# -------- helpers --------
say()  { printf "\033[1;36m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!!\033[0m  %s\n" "$*"; }
ok()   { printf "\033[1;32mok\033[0m  %s\n" "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# -------- detect OS --------
case "$(uname -s)" in
  Darwin) OS=mac ;;
  Linux)  OS=linux ;;
  *)      echo "Unsupported OS. Use install.ps1 for Windows."; exit 1 ;;
esac
say "Detected: $OS"

# -------- Homebrew (mac only) --------
if [ "$OS" = mac ] && ! have brew; then
  say "Installing Homebrew (you may be prompted for your password)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # add to PATH for this shell
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
  if [ -x /usr/local/bin/brew  ]; then eval "$(/usr/local/bin/brew shellenv)";  fi
fi

# -------- 1. git --------
if have git; then
  ok "git already installed ($(git --version))"
else
  say "Installing git..."
  if [ "$OS" = mac ]; then brew install git
  else sudo apt-get update && sudo apt-get install -y git
  fi
fi

# -------- 2. Node.js 18+ --------
need_node=1
if have node; then
  node_major="$(node -v | sed 's/v\([0-9]*\).*/\1/')"
  if [ "$node_major" -ge 18 ]; then
    ok "node already installed ($(node -v))"
    need_node=0
  else
    warn "node $node_major detected, need 18+. Upgrading..."
  fi
fi
if [ "$need_node" = 1 ]; then
  say "Installing Node.js LTS..."
  if [ "$OS" = mac ]; then
    brew install node
  else
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
  fi
fi

# -------- 3. Claude Code --------
if have claude; then
  ok "Claude Code already installed ($(claude --version 2>/dev/null || echo unknown))"
else
  say "Installing Claude Code..."
  npm install -g @anthropic-ai/claude-code
fi

# -------- 4. TradingView Desktop --------
if [ "$OS" = mac ]; then
  if [ -d /Applications/TradingView.app ]; then
    ok "TradingView Desktop already installed"
  else
    say "Installing TradingView Desktop via Homebrew Cask..."
    brew install --cask tradingview || warn "brew cask install failed. Download manually: https://www.tradingview.com/desktop/"
  fi
else
  warn "Linux: install TradingView Desktop manually from https://www.tradingview.com/desktop/"
  warn "      (AppImage or distro packages, no apt repo)"
fi

# -------- 5. clone repo --------
if [ -d "$INSTALL_DIR/.git" ]; then
  say "Repo exists at $INSTALL_DIR, pulling latest..."
  git -C "$INSTALL_DIR" pull --ff-only || warn "git pull failed, continuing with existing checkout"
else
  say "Cloning into $INSTALL_DIR..."
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

# -------- 6. npm install --------
say "Installing npm dependencies..."
cd "$INSTALL_DIR"
npm install --silent

# -------- 7. rules.json --------
if [ -f "$INSTALL_DIR/rules.json" ]; then
  ok "rules.json already exists (not overwriting)"
else
  cp "$INSTALL_DIR/rules.example.json" "$INSTALL_DIR/rules.json"
  ok "Created rules.json from example"
fi

# -------- 8. register MCP server --------
if have claude; then
  say "Registering MCP server with Claude Code..."
  if claude mcp list 2>/dev/null | grep -q '^tradingview'; then
    ok "tradingview MCP server already registered"
  else
    claude mcp add --scope user tradingview node "$INSTALL_DIR/src/server.js" \
      && ok "MCP server registered" \
      || warn "Could not register MCP server. Run this manually after authenticating Claude Code:
       claude mcp add --scope user tradingview node \"$INSTALL_DIR/src/server.js\""
  fi
fi

# -------- final message --------
cat <<EOF

$(printf "\033[1;32m================ INSTALL COMPLETE ================\033[0m")

Manual steps remaining (each takes ~30 seconds):

  1. First time using Claude Code? Authenticate:
       claude
     ...and follow the browser login prompt. Then /exit.

  2. Open TradingView Desktop, log in, then quit it completely.

  3. Relaunch TradingView with the debug port:
EOF

if [ "$OS" = mac ]; then
  echo "       open -a TradingView --args --remote-debugging-port=$CDP_PORT"
else
  echo "       tradingview --remote-debugging-port=$CDP_PORT"
fi

cat <<EOF

  4. Edit your trading rules:
       $INSTALL_DIR/rules.json

  5. Restart Claude Code, then ask:
       Run tv_health_check

     Expected: { "success": true, "cdp_connected": true, ... }

Full guide: $INSTALL_DIR/SETUP_GUIDE.md
Web guide:  open $INSTALL_DIR/previews/setup-guide.html

EOF
