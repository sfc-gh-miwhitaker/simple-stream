#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="${SCRIPT_DIR}/config.json"

if [ ! -f "$CONFIG_PATH" ]; then
  echo "Config file not found at $CONFIG_PATH"
  echo "Copy config.example.json to config.json and update placeholders."
  exit 1
fi

if [ -d "${SCRIPT_DIR}/.venv" ]; then
  source "${SCRIPT_DIR}/.venv/bin/activate"
fi

python3 "${SCRIPT_DIR}/send_events_stream.py" --config "$CONFIG_PATH" "$@"
