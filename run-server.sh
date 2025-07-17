#!/bin/bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

VENV_DIR=".venv"
VENV_ACTIVATE="$VENV_DIR/bin/activate"

if [ ! -f "$VENV_ACTIVATE" ]; then
    echo -e "${RED}[ERROR]${NC} Python virtual environment not found. Please run ./setup.sh first." >&2
    exit 1
fi

echo -e "${GREEN}🚀 Activating virtual environment and starting Claude Code proxy server...${NC}"

source "$VENV_ACTIVATE"

echo -e "Proxy server will be running at: ${GREEN}http://127.0.0.1:8082${NC}"
echo -e "Python interpreter in use: ${GREEN}$(which python)${NC}"
echo -e "Press ${GREEN}CTRL+C${NC} to stop the server."

uvicorn server:app --host 127.0.0.1 --port 8082 --reload