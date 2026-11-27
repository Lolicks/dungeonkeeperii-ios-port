#!/usr/bin/env bash
set -euo pipefail
PORT="${1:-8080}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND="$ROOT/dashboard/backend"
VENV="$ROOT/.venv"

if [ ! -x "$VENV/bin/python" ]; then
  python3 -m venv "$VENV"
fi
"$VENV/bin/python" -m pip install -q -r "$BACKEND/requirements.txt"
echo "Starting Control Center on http://localhost:$PORT"
CONTROL_CENTER_PORT="$PORT" "$VENV/bin/python" "$BACKEND/app.py"
