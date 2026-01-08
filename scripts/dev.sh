#!/usr/bin/env bash
set -euo pipefail

cleanup() {
  if [[ -n "${API_PID:-}" ]]; then
    kill "$API_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "${ADMIN_PID:-}" ]]; then
    kill "$ADMIN_PID" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

docker compose up -d postgres

(
  cd apps/api
  poetry install
  poetry run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
) &
API_PID=$!

pnpm --filter @kamusi/admin dev &
ADMIN_PID=$!

wait
