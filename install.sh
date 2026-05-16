#!/usr/bin/env bash
#
# tradingview-mcp-pelegdror - one-command installer (macOS + Linux)
#
# Installs from scratch on a blank machine:
#   git, Node.js 18+, Claude Code, TradingView Desktop (Mac only via brew),
#   this repo, npm deps, rules.json, MCP server registration with Claude Code.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/peleg-jpg/tradingview-mcp-pelegdror/main/install.sh | bash
#
# Override install location:
#   INSTALL_DIR=/custom/path curl -fsSL ... | bash
#
# Re-running the script is safe. It skips anything already installed.

set -euo pipefail

REPO_URL="https://github.com/peleg-jpg/tradingview-mcp-pelegdror.git"
INSTALL_DIR="${INSTALL_DIR:-$HOME/tradingview-mcp-pelegdror}"
CDP_PORT=9222

# Track soft-failures so we can surface them in the final message instead of letting them scroll past.
TV_INSTALLED=1
MCP_REGISTERED=0
NEEDS_SUDO_NPM=0

# -------- helpers --------
say()  { printf "\033[1;36m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!!\033[0m  %s\n" "$*"; }
ok()   { printf "\033[1;32mok\033[0m  %s\n" "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# Source Homebrew shellenv if brew is present. Safe to call multiple times.
source_brew_env() {
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
  if [ -x /usr/local/bin/brew  ]; then eval "$(/usr/local/bin/brew shellenv)";  fi
}

# -------- detect OS --------
case "$(uname -s)" in
  Darwin) OS=mac ;;
  Linux)  OS=linux ;;
  *)      echo "Unsupported OS. Use install.ps1 for Windows."; exit 1 ;;
esac

# On Linux, require apt-get. Fedora/Arch/openSUSE users have to install prereqs themselves.
if [ "$OS" = linux ] && ! have apt-get; then
  echo
  echo "This installer's Linux path assumes Debian/Ubuntu (apt-get)."
  echo "On Fedora, Arch, openSUSE, or others, install git + Node.js 18+ manually first:"
  echo "  Fedora:  sudo dnf install git nodejs"
  echo "  Arch:    sudo pacman -S git nodejs npm"
  echo "  openSUSE: sudo zypper install git nodejs"
  echo "Then re-run this installer; it will pick up from there."
  exit 1
fi

say "Detected: $OS"
source_brew_env

# -------- Homebrew (mac only) --------
if [ "$OS" = mac ] && ! have brew; then
  say "Installing Homebrew (you may be prompted for your password)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  source_brew_env
fi

# -------- 1. git --------
if have git; then
  ok "git already installed ($(git --version))"
else
  say "Installing git..."
  if [ "$OS" = mac ]; then brew install git
  else sudo apt-get update && sudo apt-get install -y git
  fi
  source_brew_env
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
    source_brew_env
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
  # Detect npm prefix - if it's a system path like /usr/local, global install will EACCES without sudo.
  npm_prefix="$(npm config get prefix 2>/dev/null || echo /usr/local)"
  if [ ! -w "$npm_prefix" ]; then
    warn "npm prefix '$npm_prefix' is not writable by current user. Falling back to ~/.npm-global."
    mkdir -p "$HOME/.npm-global"
    npm config set prefix "$HOME/.npm-global"
    # Ensure PATH picks it up for the rest of this script
    export PATH="$HOME/.npm-global/bin:$PATH"
    # Hint the user to persist this in their shell profile
    profile="$HOME/.zshrc"
    [ "$OS" = linux ] && profile="$HOME/.bashrc"
    if ! grep -q ".npm-global/bin" "$profile" 2>/dev/null; then
      echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$profile"
      warn "Added ~/.npm-global/bin to $profile. Reopen your terminal after install."
    fi
  fi
  npm install -g @anthropic-ai/claude-code
fi

# -------- 4. TradingView Desktop --------
if [ "$OS" = mac ]; then
  if [ -d /Applications/TradingView.app ]; then
    ok "TradingView Desktop already installed"
  else
    say "Installing TradingView Desktop via Homebrew Cask..."
    if brew install --cask tradingview; then
      ok "TradingView Desktop installed"
    else
      warn "brew cask install of tradingview failed"
      TV_INSTALLED=0
    fi
  fi
else
  warn "Linux: TradingView Desktop has no apt package; download from https://www.tradingview.com/desktop/"
  TV_INSTALLED=0
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
( cd "$INSTALL_DIR" && npm install --silent )

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
  # 'claude mcp get' exits non-zero if not registered - more reliable than parsing list output.
  if claude mcp get tradingview >/dev/null 2>&1; then
    ok "tradingview MCP server already registered"
    MCP_REGISTERED=1
  else
    if claude mcp add --scope user tradingview node "$INSTALL_DIR/src/server.js" 2>/dev/null; then
      ok "MCP server registered"
      MCP_REGISTERED=1
    else
      warn "Could not register MCP server (claude may need authentication first)."
    fi
  fi
fi

# -------- open rules.json for the user to edit --------
if [ "$OS" = mac ]; then
  open -t "$INSTALL_DIR/rules.json" 2>/dev/null || true
else
  # Linux: try xdg-open, fall back silently
  xdg-open "$INSTALL_DIR/rules.json" >/dev/null 2>&1 || true
fi

# -------- final message --------
printf "\n\033[1;32m================ INSTALL COMPLETE ================\033[0m\n\n"

if [ "$TV_INSTALLED" = 0 ]; then
  printf "\033[1;33m!! TradingView Desktop did not install automatically.\033[0m\n"
  printf "   Download it from https://www.tradingview.com/desktop/ BEFORE step 3 below.\n\n"
fi
if [ "$MCP_REGISTERED" = 0 ] && have claude; then
  printf "\033[1;33m!! MCP server was not registered (Claude Code likely needs authentication first).\033[0m\n"
  printf "   After step 1 below, also run:\n"
  printf "     claude mcp add --scope user tradingview node \"%s/src/server.js\"\n\n" "$INSTALL_DIR"
fi

cat <<EOF
What's left for you to do (5 quick steps):

  1. Authenticate Claude Code:
       claude
     A browser opens to log you in. When done, type /exit and press Enter.

  2. Open TradingView Desktop. Log in with your account.
     Then FULLY quit it (closing the window is not enough):
EOF
if [ "$OS" = mac ]; then
  echo "       Cmd-Q, or right-click the dock icon -> Quit."
else
  echo "       Close the app and check no tradingview process remains: pgrep -fl tradingview"
fi

cat <<EOF

  3. Relaunch TradingView with the debug port enabled:
EOF
if [ "$OS" = mac ]; then
  echo "       open -a TradingView --args --remote-debugging-port=$CDP_PORT"
else
  echo "       tradingview --remote-debugging-port=$CDP_PORT"
fi

cat <<EOF

  4. Your trading rules just opened in an editor. Fill in your watchlist,
     bias criteria, and risk rules, then save.
     File: $INSTALL_DIR/rules.json

  5. Open a NEW terminal, run 'claude', and ask:
       Run tv_health_check

     Expected: { "success": true, "cdp_connected": true, ... }

Full guide: $INSTALL_DIR/SETUP_GUIDE.md
Web guide:  open $INSTALL_DIR/previews/setup-guide.html

EOF
