#!/usr/bin/env bash
set -Eeuo pipefail

# Run entire project with one command and print live links.
# - Starts FastAPI backend (uvicorn)
# - Serves frontend via a tiny static server
# - Prints localhost and LAN links

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

PY=${PYTHON:-python3}
if ! command -v "$PY" >/dev/null 2>&1; then
  PY=python
fi

VENV_DIR="$ROOT_DIR/.venv"
BACKEND_PORT=${BACKEND_PORT:-8000}
FRONTEND_PORT=${FRONTEND_PORT:-5173}
HOST=${HOST:-0.0.0.0}

# Create venv if needed
if [ ! -d "$VENV_DIR" ]; then
  "$PY" -m venv "$VENV_DIR"
fi
# shellcheck disable=SC1090
source "$VENV_DIR/bin/activate"

# Install backend deps
pip install --upgrade pip >/dev/null
pip install -r "$ROOT_DIR/backend/requirements.txt" >/dev/null

# Start backend
UVICORN_CMD="python -m uvicorn backend.app:app --host $HOST --port $BACKEND_PORT"
$UVICORN_CMD &
BACK_PID=$!

cleanup() {
  echo
  echo "Shutting down..."
  if kill -0 "$BACK_PID" 2>/dev/null; then kill "$BACK_PID" 2>/dev/null || true; fi
}
trap cleanup EXIT INT TERM

# Wait for backend to be ready (10s timeout)
ATTEMPTS=0
until curl -sS "http://127.0.0.1:${BACKEND_PORT}/" >/dev/null 2>&1; do
  ATTEMPTS=$((ATTEMPTS+1))
  if [ "$ATTEMPTS" -gt 100 ]; then
    echo "Backend failed to start on port ${BACKEND_PORT}" >&2
    exit 1
  fi
  sleep 0.1
done

# Determine local IP (best-effort)
LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
LAN_IP=${LAN_IP:-127.0.0.1}

# Start static server for frontend (foreground)
echo ""
echo "========================================"
echo "Voice PD Detector is live!"
echo "Frontend:  http://127.0.0.1:${FRONTEND_PORT}"
echo "           http://${LAN_IP}:${FRONTEND_PORT} (LAN)"
echo "API:       http://127.0.0.1:${BACKEND_PORT}"
echo "           http://${LAN_IP}:${BACKEND_PORT} (LAN)"
echo "Press Ctrl+C to stop."
echo "========================================"
echo ""

# Serve the frontend directory
cd "$ROOT_DIR/frontend"
python -m http.server "$FRONTEND_PORT"
