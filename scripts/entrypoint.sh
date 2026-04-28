#!/usr/bin/env bash
set -Eeuo pipefail

apiRoot="/opt/knowhere/source/api"
dashboardRoot="/opt/knowhere/dashboard"
apiVenv="/opt/knowhere/venvs/api"
workerVenv="/opt/knowhere/venvs/worker"

apiPid=""
workerPid=""
dashboardPid=""

setDefault() {
  local name="$1"
  local value="$2"

  if [ -z "${!name:-}" ]; then
    export "${name}=${value}"
  fi
}

generateRandomSecret() {
  python -c 'import secrets; print(secrets.token_urlsafe(48))'
}

loadOrCreateSecret() {
  local name="$1"
  local filePath="$2"

  if [ -n "${!name:-}" ]; then
    return
  fi

  mkdir -p "$(dirname "$filePath")"

  if [ ! -s "$filePath" ]; then
    umask 077
    generateRandomSecret > "$filePath"
    chmod 600 "$filePath"
    echo "Generated ${name} and saved it to ${filePath}"
  fi

  export "${name}=$(cat "$filePath")"
}

isEnabled() {
  local value="${1:-}"
  case "${value,,}" in
    1 | true | yes | on) return 0 ;;
    *) return 1 ;;
  esac
}

waitForPostgres() {
  local attempts="${SELF_HOSTED_WAIT_ATTEMPTS:-60}"
  local delaySeconds="${SELF_HOSTED_WAIT_DELAY_SECONDS:-2}"

  for ((attempt = 1; attempt <= attempts; attempt++)); do
    if PGPASSWORD="${POSTGRES_PASSWORD}" pg_isready \
      --host="${POSTGRES_HOST}" \
      --port="${POSTGRES_PORT}" \
      --username="${POSTGRES_USER}" \
      --dbname="${POSTGRES_DB}" >/dev/null 2>&1; then
      echo "PostgreSQL is ready"
      return
    fi

    echo "Waiting for PostgreSQL (${attempt}/${attempts})..."
    sleep "$delaySeconds"
  done

  echo "PostgreSQL did not become ready" >&2
  exit 1
}

waitForRedis() {
  local attempts="${SELF_HOSTED_WAIT_ATTEMPTS:-60}"
  local delaySeconds="${SELF_HOSTED_WAIT_DELAY_SECONDS:-2}"

  for ((attempt = 1; attempt <= attempts; attempt++)); do
    if redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" ping >/dev/null 2>&1; then
      echo "Redis is ready"
      return
    fi

    echo "Waiting for Redis (${attempt}/${attempts})..."
    sleep "$delaySeconds"
  done

  echo "Redis did not become ready" >&2
  exit 1
}

waitForApi() {
  local attempts="${SELF_HOSTED_WAIT_ATTEMPTS:-60}"
  local delaySeconds="${SELF_HOSTED_WAIT_DELAY_SECONDS:-2}"
  local apiHealthUrl="http://127.0.0.1:${API_PORT}/health"

  for ((attempt = 1; attempt <= attempts; attempt++)); do
    if curl -fsS "$apiHealthUrl" >/dev/null 2>&1; then
      echo "Knowhere API is ready"
      return
    fi

    echo "Waiting for Knowhere API (${attempt}/${attempts})..."
    sleep "$delaySeconds"
  done

  echo "Knowhere API did not become ready" >&2
  exit 1
}

ensurePostgresExtensions() {
  if ! isEnabled "${SELF_HOSTED_INIT_POSTGRES_EXTENSIONS:-true}"; then
    echo "Skipping PostgreSQL extension bootstrap"
    return
  fi

  echo "Ensuring PostgreSQL extensions exist"
  PGPASSWORD="${POSTGRES_PASSWORD}" psql \
    --host="${POSTGRES_HOST}" \
    --port="${POSTGRES_PORT}" \
    --username="${POSTGRES_USER}" \
    --dbname="${POSTGRES_DB}" \
    --set=ON_ERROR_STOP=1 <<'SQL'
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
SQL
}

createStorageBuckets() {
  if ! isEnabled "${SELF_HOSTED_CREATE_STORAGE_BUCKETS:-true}"; then
    echo "Skipping storage bucket bootstrap"
    return
  fi

  echo "Ensuring S3-compatible storage buckets exist"
  DATABASE_URL="${API_DATABASE_URL}" \
    PYTHONPATH="${apiRoot}/apps/api:${apiRoot}/packages/shared-python" \
    PATH="${apiVenv}/bin:${PATH}" \
    "${apiVenv}/bin/python" /usr/local/bin/knowhere-create-storage-buckets
}

configureStorageEvents() {
  if ! isEnabled "${SELF_HOSTED_CONFIGURE_STORAGE_EVENTS:-true}"; then
    echo "Skipping storage event bootstrap"
    return
  fi

  echo "Ensuring S3-compatible storage events are configured"
  DATABASE_URL="${API_DATABASE_URL}" \
    PYTHONPATH="${apiRoot}/apps/api:${apiRoot}/packages/shared-python" \
    PATH="${apiVenv}/bin:${PATH}" \
    "${apiVenv}/bin/python" /usr/local/bin/knowhere-configure-storage-events
}

runDashboardMigrations() {
  echo "Running dashboard auth/account migrations"
  (
    cd "$dashboardRoot"
    DATABASE_URL="${DASHBOARD_DATABASE_URL}" \
      NODE_ENV=production \
      BETTER_AUTH_URL="${BETTER_AUTH_URL}" \
      BETTER_AUTH_SECRET="${BETTER_AUTH_SECRET}" \
      UNSAFE_DB_SSL_ENABLED="${UNSAFE_DB_SSL_ENABLED}" \
      NEXT_PUBLIC_APP_URL="${NEXT_PUBLIC_APP_URL}" \
      NEXT_PUBLIC_API_URL="${NEXT_PUBLIC_API_URL}" \
      NEXT_PUBLIC_AUTH_BASE_URL="${NEXT_PUBLIC_AUTH_BASE_URL}" \
      BILLING_ENABLED="${BILLING_ENABLED}" \
      ./node_modules/.bin/drizzle-kit migrate
  )
}

startApi() {
  echo "Starting Knowhere API on port ${API_PORT}"
  (
    cd "${apiRoot}/apps/api"
    DATABASE_URL="${API_DATABASE_URL}" \
      PATH="${apiVenv}/bin:${PATH}" \
      PYTHONPATH="${apiRoot}/apps/api:${apiRoot}/packages/shared-python" \
      python main.py
  ) &
  apiPid="$!"
}

startWorker() {
  echo "Starting Knowhere worker"
  (
    cd "${apiRoot}/apps/worker"
    DATABASE_URL="${API_DATABASE_URL}" \
      PATH="${workerVenv}/bin:${PATH}" \
      PYTHONPATH="${apiRoot}/apps/worker:${apiRoot}/packages/shared-python" \
      python worker.py
  ) &
  workerPid="$!"
}

startDashboard() {
  echo "Starting Knowhere dashboard on port ${DASHBOARD_PORT}"
  (
    cd "$dashboardRoot"
    DATABASE_URL="${DASHBOARD_DATABASE_URL}" \
      NODE_ENV=production \
      PORT="${DASHBOARD_PORT}" \
      HOSTNAME=0.0.0.0 \
      BETTER_AUTH_URL="${BETTER_AUTH_URL}" \
      BETTER_AUTH_SECRET="${BETTER_AUTH_SECRET}" \
      UNSAFE_DB_SSL_ENABLED="${UNSAFE_DB_SSL_ENABLED}" \
      NEXT_PUBLIC_APP_URL="${NEXT_PUBLIC_APP_URL}" \
      NEXT_PUBLIC_API_URL="${NEXT_PUBLIC_API_URL}" \
      NEXT_PUBLIC_AUTH_BASE_URL="${NEXT_PUBLIC_AUTH_BASE_URL}" \
      BILLING_ENABLED="${BILLING_ENABLED}" \
      PASSWORD_LOGIN_ENABLED="${PASSWORD_LOGIN_ENABLED}" \
      ./node_modules/.bin/next start --port "${DASHBOARD_PORT}" --hostname 0.0.0.0
  ) &
  dashboardPid="$!"
}

stopChildren() {
  local signal="${1:-TERM}"
  local pids=()

  [ -n "$dashboardPid" ] && pids+=("$dashboardPid")
  [ -n "$workerPid" ] && pids+=("$workerPid")
  [ -n "$apiPid" ] && pids+=("$apiPid")

  if [ "${#pids[@]}" -gt 0 ]; then
    kill "-${signal}" "${pids[@]}" 2>/dev/null || true
    wait "${pids[@]}" 2>/dev/null || true
  fi
}

handleSignal() {
  stopChildren TERM
  exit 0
}

setDefault POSTGRES_HOST postgres
setDefault POSTGRES_PORT 5432
setDefault POSTGRES_DB Knowhere
setDefault POSTGRES_USER root
setDefault POSTGRES_PASSWORD root123
setDefault API_DATABASE_URL "postgresql+asyncpg://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"
setDefault DASHBOARD_DATABASE_URL "postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"
setDefault DB_SSL_MODE disable
setDefault UNSAFE_DB_SSL_ENABLED true

setDefault REDIS_HOST redis
setDefault REDIS_PORT 6379
setDefault REDIS_DATABASE 0
setDefault REDIS_PASSWORD ""
setDefault CELERY_REDIS_URL "redis://${REDIS_HOST}:${REDIS_PORT}/${REDIS_DATABASE}"

setDefault DASHBOARD_PORT 3000
setDefault API_PORT 5005
setDefault NEXT_PUBLIC_API_URL "http://127.0.0.1:${API_PORT}/api"
setDefault NEXT_PUBLIC_AUTH_BASE_URL "/api/auth"
setDefault DASHBOARD_PUBLIC_URL "http://localhost:${DASHBOARD_PORT}"
setDefault NEXT_PUBLIC_APP_URL "${DASHBOARD_PUBLIC_URL}"
setDefault BETTER_AUTH_URL "${NEXT_PUBLIC_APP_URL}"

setDefault SELF_HOSTED_SECRETS_PATH /data/secrets
setDefault SELF_HOSTED_INIT_POSTGRES_EXTENSIONS true
loadOrCreateSecret SECRET_KEY "${SELF_HOSTED_SECRETS_PATH}/secret-key"
loadOrCreateSecret BETTER_AUTH_SECRET "${SELF_HOSTED_SECRETS_PATH}/better-auth-secret"
loadOrCreateSecret USERS_VERIFY_TOKEN_SECRET "${SELF_HOSTED_SECRETS_PATH}/users-verify-token-secret"
loadOrCreateSecret USERS_RESET_PASSWORD_TOKEN_SECRET "${SELF_HOSTED_SECRETS_PATH}/users-reset-password-token-secret"

setDefault API_STANDALONE_MODE_ENABLED false
setDefault BILLING_ENABLED false
setDefault RATE_LIMIT_ENABLED false
setDefault PASSWORD_LOGIN_ENABLED true

setDefault ENVIRONMENT production
setDefault APP_ENV production
setDefault LOG_LEVEL INFO
setDefault TMP_PATH /tmp/knowhere
setDefault USERS_DATA_PATH /data/users
setDefault FONT_PATH /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf
setDefault CHROMEDRIVER_PATH /usr/bin/chromedriver

setDefault S3_TYPE s3
setDefault S3_BUCKET_NAME knowhere-uploads
setDefault S3_UPLOADS_BUCKET "${S3_BUCKET_NAME}"
setDefault S3_RESULTS_BUCKET knowhere-results
setDefault S3_ACCESS_KEY_ID test
setDefault S3_SECRET_ACCESS_KEY test
setDefault S3_ENDPOINT_URL http://localstack:4566
setDefault S3_PRIVATE_DOMAIN http://localhost:4566
setDefault S3_REGION us-west-1
setDefault S3_USE_SSL false
setDefault S3_ADDRESSING_STYLE path
setDefault S3_TEMP_PATH /tmp/knowhere
setDefault S3_WEBHOOK_AUTH_TOKEN "change-me-storage-webhook-token"
setDefault SNS_SIGNATURE_VERIFICATION false
setDefault SELF_HOSTED_CREATE_STORAGE_BUCKETS true
setDefault SELF_HOSTED_CONFIGURE_STORAGE_EVENTS true
setDefault SELF_HOSTED_S3_EVENT_TOPIC_NAME knowhere-s3-upload-events
setDefault SELF_HOSTED_S3_EVENT_WEBHOOK_URL "http://app:${API_PORT}/v1/internal/s3-events"
setDefault SELF_HOSTED_STORAGE_CORS_ALLOWED_ORIGINS ""

setDefault DS_URL https://api.deepseek.com/v1
setDefault DS_KEY ""
setDefault NORMOL_MODEL deepseek-chat
setDefault HIERARCHY_LLM_MODEL "${NORMOL_MODEL}"
setDefault IMAGE_MODEL qwen3.5-flash
setDefault IMAGE_MODEL_MAX "${IMAGE_MODEL}"
setDefault EMBEDDING_MODEL text-embedding-v4
setDefault GLM_URL https://open.bigmodel.cn/api/paas/v4
setDefault ALI_URL https://dashscope.aliyuncs.com/compatible-mode/v1
setDefault ARK_URL https://ark.cn-beijing.volces.com/api/v3/chat/completions

setDefault FRONTEND_URL "${NEXT_PUBLIC_APP_URL}"
setDefault INTERNAL_DASHBOARD_ENDPOINT "http://127.0.0.1:${DASHBOARD_PORT}"
setDefault QSTASH_CALLBACK_BASE_URL "http://127.0.0.1:${API_PORT}/api/v1"
setDefault MOESIF_APPLICATION_ID ""
setDefault LOGFIRE_TOKEN ""

mkdir -p "$TMP_PATH" "$USERS_DATA_PATH" "$SELF_HOSTED_SECRETS_PATH" /data/models/huggingface

if [ -z "${GA_MEASUREMENT_ID:-}" ]; then
  unset GA_MEASUREMENT_ID
fi

trap handleSignal INT TERM

waitForPostgres
ensurePostgresExtensions
waitForRedis
createStorageBuckets
runDashboardMigrations
startApi
waitForApi
configureStorageEvents
startWorker
startDashboard

wait -n "$apiPid" "$workerPid" "$dashboardPid"
exitCode="$?"
echo "A Knowhere self-hosted process exited with code ${exitCode}; stopping remaining processes"
stopChildren TERM
exit "$exitCode"
