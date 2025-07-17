#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

info "Step 1/6: Checking core dependencies (Node.js and Python)..."
SERVBAY_PYTHON="/Applications/ServBay/bin/python3"

if ! command -v node &> /dev/null; then
    error "Node.js not found. Please install it from the ServBay 'Packages' page first."
fi
if [ ! -x "$SERVBAY_PYTHON" ]; then
    error "ServBay Python not found at $SERVBAY_PYTHON. Please ensure Python is installed and enabled in ServBay."
fi
info "Node.js and ServBay Python are installed."

info "Step 2/6: Checking for the Python package manager uv..."
if ! command -v uv &> /dev/null; then
    warn "uv not found. Starting automatic installation..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.cargo/bin:$PATH"
    info "uv installed successfully!"
else
    info "uv is already installed."
fi

info "Step 3/6: Setting up Python virtual environment and installing all dependencies..."
info "Forcing use of ServBay Python: $SERVBAY_PYTHON"
uv venv -p "$SERVBAY_PYTHON" --seed

info "Installing core application dependencies..."
uv pip install "fastapi[all]" "litellm" "python-dotenv"
info "All Python dependencies installed successfully."

info "Step 4/6: Checking for the Claude Code CLI tool..."
if ! npm list -g @anthropic-ai/claude-code &> /dev/null; then
    warn "Claude Code not found. Starting global installation..."
    npm install -g @anthropic-ai/claude-code
    info "Claude Code installed successfully!"
else
    info "Claude Code is already installed."
fi

info "Step 5/6: Configuring shell environment variables..."
BASE_URL_EXPORT="export ANTHROPIC_BASE_URL=http://localhost:8082"
API_KEY_EXPORT="export ANTHROPIC_API_KEY=ServBay"

configure_shell() {
    local rc_file=$1
    if [ -f "$rc_file" ]; then
        if ! grep -q "ANTHROPIC_BASE_URL" "$rc_file"; then
            echo -e "\n# Claude Code Proxy for ServBay" >> "$rc_file"
            echo "$BASE_URL_EXPORT" >> "$rc_file"
            echo "$API_KEY_EXPORT" >> "$rc_file"
            info "Environment variables have been written to $rc_file"
        else
            info "Configuration already exists in $rc_file, skipping."
        fi
    fi
}

configure_shell "$HOME/.zshrc"
if [ -f "$HOME/.bash_profile" ]; then
    configure_shell "$HOME/.bash_profile"
else
    configure_shell "$HOME/.bashrc"
fi

info "Step 6/6: Safely updating Claude Code configuration file..."
CLAUDE_CONFIG_FILE="$HOME/.claude.json"
"$SERVBAY_PYTHON" -c "
import json
import os

config_path = os.path.expanduser('$CLAUDE_CONFIG_FILE')
data = {}

if os.path.exists(config_path):
    try:
        with open(config_path, 'r') as f:
            content = f.read()
            if content.strip():
                data = json.loads(content)
            if not isinstance(data, dict):
                 print(f'${YELLOW}[WARN]${NC} Existing {config_path} is not a valid JSON object. Backing up and creating a new one.')
                 os.rename(config_path, config_path + '.bak')
                 data = {}
    except (json.JSONDecodeError, UnicodeDecodeError):
        print(f'${YELLOW}[WARN]${NC} Could not parse existing {config_path}. Backing up and creating a new one.')
        os.rename(config_path, config_path + '.bak')
        data = {}

data['hasCompletedOnboarding'] = True

with open(config_path, 'w') as f:
    json.dump(data, f, indent=2)

print(f'${GREEN}[INFO]${NC} Successfully updated {config_path}.')
"

echo -e "\n🎉 ${GREEN}All setups completed successfully!${NC}"
echo -e "Please run ${GREEN}./run-server.sh${NC} to start the proxy server."