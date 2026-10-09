#!/usr/bin/env bash
# One-line (well, short) launcher for the Farm Town headless game server.
# Works on an Iranian VPS (recommended) or a free host (Render/Railway/Fly/Oracle Free).
# Placeholders: set FARM_SERVER_* or edit config/server.cfg before going public.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$HOME/godot/godot}"
if [[ ! -x "$GODOT" ]]; then
  GODOT="$(command -v godot || true)"
fi
if [[ -z "${GODOT}" || ! -x "$GODOT" ]]; then
  echo "Godot binary not found. Set GODOT=/path/to/godot (4.7.2)." >&2
  exit 1
fi
HOST="${FARM_SERVER_HOST:-YOUR_SERVER_HOST}"
# Render/Railway/Fly inject $PORT (their single public port) — used when FARM_SERVER_PORT is unset.
PORT="${FARM_SERVER_PORT:-${PORT:-9080}}"
HEALTH="${FARM_SERVER_HEALTH_PORT:-9081}"
BIND="${FARM_SERVER_BIND:-0.0.0.0}"
CONTENT="${FARM_CONTENT:-$ROOT/server/content}"
DATA="${FARM_DATA:-$ROOT/server/data}"
mkdir -p "$CONTENT" "$DATA"
echo "Starting Farm Town server on ${BIND}:${PORT} (health ${HEALTH}) host=${HOST}"
exec "$GODOT" --headless --path "$ROOT" res://scenes/server/Server.tscn -- \
  --server --port="$PORT" --bind="$BIND" --health-port="$HEALTH" \
  --content="$CONTENT" --data="$DATA"
