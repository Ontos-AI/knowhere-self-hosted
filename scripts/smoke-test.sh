#!/usr/bin/env bash
set -euo pipefail

composeFile="${COMPOSE_FILE:-compose.yaml}"
projectName="${COMPOSE_PROJECT_NAME:-knowhere-self-hosted-smoke}"

export DASHBOARD_HOST_PORT="${DASHBOARD_HOST_PORT:-13000}"
export API_HOST_PORT="${API_HOST_PORT:-15005}"
export POSTGRES_HOST_PORT="${POSTGRES_HOST_PORT:-15432}"
export REDIS_HOST_PORT="${REDIS_HOST_PORT:-16379}"
export LOCALSTACK_HOST_PORT="${LOCALSTACK_HOST_PORT:-14566}"

dashboardUrl="${DASHBOARD_SMOKE_URL:-http://127.0.0.1:${DASHBOARD_HOST_PORT}/login}"
apiUrl="${API_SMOKE_URL:-http://127.0.0.1:${API_HOST_PORT}/health}"

docker compose -p "$projectName" -f "$composeFile" up -d postgres redis localstack app

for attempt in {1..90}; do
  if curl -fsS "$apiUrl" >/dev/null 2>&1 && curl -fsS "$dashboardUrl" >/dev/null 2>&1; then
    echo "Smoke test passed"
    exit 0
  fi

  echo "Waiting for app smoke endpoints (${attempt}/90)..."
  sleep 2
done

docker compose -p "$projectName" -f "$composeFile" logs --no-color app
echo "Smoke test failed" >&2
exit 1
