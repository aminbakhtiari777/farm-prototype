#!/usr/bin/env bash
# Ping the server /health endpoint so free-tier hosts (Render/Railway sleep) stay awake.
# Usage: FARM_HEALTH_URL=https://YOUR_SERVER_HOST/health ./tools/keepalive.sh
# Cron example (every 10 min): */10 * * * * FARM_HEALTH_URL=... /path/to/tools/keepalive.sh
set -euo pipefail
URL="${FARM_HEALTH_URL:-}"
if [[ -z "$URL" ]]; then
  HOST="${FARM_SERVER_HOST:-YOUR_SERVER_HOST}"
  PORT="${FARM_SERVER_HEALTH_PORT:-9081}"
  SCHEME="http"
  if [[ "${FARM_SERVER_TLS:-false}" == "true" ]]; then SCHEME="https"; fi
  URL="${SCHEME}://${HOST}:${PORT}/health"
fi
if [[ "$URL" == *"YOUR_SERVER_HOST"* ]]; then
  echo "keepalive: placeholder host — set FARM_HEALTH_URL or FARM_SERVER_HOST" >&2
  exit 0
fi
code=$(curl -sS -o /tmp/farm-health.json -w "%{http_code}" --max-time 15 "$URL" || echo 000)
echo "keepalive $(date -Is) $URL -> $code $(head -c 120 /tmp/farm-health.json 2>/dev/null || true)"
# Single-port free hosts (Render/Railway/Fly) only expose the WebSocket port, so the
# /health port is not public. Point FARM_HEALTH_URL at the public app URL and set
# FARM_KEEPALIVE_ANY=1: any HTTP answer (even 400/426 from the WebSocket server) wakes it.
if [[ "${FARM_KEEPALIVE_ANY:-0}" == "1" ]]; then [[ "$code" != "000" ]]; else [[ "$code" == "200" ]]; fi
