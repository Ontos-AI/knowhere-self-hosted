# syntax=docker/dockerfile:1.7

ARG PYTHON_IMAGE=python:3.12-slim
ARG NODE_IMAGE=node:22-bookworm-slim

FROM ${PYTHON_IMAGE} AS api-deps

WORKDIR /opt/knowhere/source/api

RUN apt-get update \
  && apt-get install -y --no-install-recommends gcc g++ curl \
  && rm -rf /var/lib/apt/lists/* \
  && python -m pip install --no-cache-dir uv

COPY .build/sources/knowhere-api/pyproject.toml .build/sources/knowhere-api/uv.lock ./
COPY .build/sources/knowhere-api/packages/shared-python ./packages/shared-python
COPY .build/sources/knowhere-api/apps/api/pyproject.toml ./apps/api/pyproject.toml
COPY .build/sources/knowhere-api/apps/worker/pyproject.toml ./apps/worker/pyproject.toml

RUN cd apps/api \
  && UV_PROJECT_ENVIRONMENT=/opt/knowhere/venvs/api uv sync --locked --no-dev

FROM ${PYTHON_IMAGE} AS worker-deps

WORKDIR /opt/knowhere/source/api

RUN apt-get update \
  && apt-get install -y --no-install-recommends gcc g++ curl \
  && rm -rf /var/lib/apt/lists/* \
  && python -m pip install --no-cache-dir uv

COPY .build/sources/knowhere-api/pyproject.toml .build/sources/knowhere-api/uv.lock ./
COPY .build/sources/knowhere-api/packages/shared-python ./packages/shared-python
COPY .build/sources/knowhere-api/apps/api/pyproject.toml ./apps/api/pyproject.toml
COPY .build/sources/knowhere-api/apps/worker/pyproject.toml ./apps/worker/pyproject.toml

RUN cd apps/worker \
  && UV_PROJECT_ENVIRONMENT=/opt/knowhere/venvs/worker uv sync --locked --no-dev \
  && find /opt/knowhere/venvs/worker -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true \
  && find /opt/knowhere/venvs/worker -type f -name '*.pyc' -delete \
  && find /opt/knowhere/venvs/worker -type f -name '*.pyo' -delete

FROM ${NODE_IMAGE} AS dashboard-deps

ENV NEXT_TELEMETRY_DISABLED=1

WORKDIR /opt/knowhere/source/dashboard

RUN corepack enable

COPY .build/sources/knowhere-api-dashboard/package.json .build/sources/knowhere-api-dashboard/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

FROM dashboard-deps AS dashboard-builder

ARG NEXT_PUBLIC_API_URL=http://127.0.0.1:5005/api
ARG NEXT_PUBLIC_AUTH_BASE_URL=/api/auth
ARG NEXT_PUBLIC_APP_URL=http://localhost:3000

COPY .build/sources/knowhere-api-dashboard ./

RUN BETTER_AUTH_SECRET=build-validation-only-auth-secret-32-chars \
  BETTER_AUTH_URL=http://localhost:3000 \
  NEXT_PUBLIC_API_URL="${NEXT_PUBLIC_API_URL}" \
  NEXT_PUBLIC_AUTH_BASE_URL="${NEXT_PUBLIC_AUTH_BASE_URL}" \
  NEXT_PUBLIC_APP_URL="${NEXT_PUBLIC_APP_URL}" \
  BILLING_ENABLED=false \
  RESEND_API_KEY=re_build_validation_placeholder \
  SKIP_ENV_VALIDATION=1 \
  pnpm build

FROM ${NODE_IMAGE} AS node-runtime

FROM ${PYTHON_IMAGE} AS runner

ARG APP_VERSION=dev
ARG BUILD_TIME=""
ARG GIT_COMMIT=""

ENV APP_VERSION=${APP_VERSION}
ENV BUILD_TIME=${BUILD_TIME}
ENV GIT_COMMIT=${GIT_COMMIT}
ENV PYTHONUNBUFFERED=1
ENV NEXT_TELEMETRY_DISABLED=1
ENV HF_HOME=/data/models/huggingface
ENV TRANSFORMERS_CACHE=/data/models/huggingface

WORKDIR /opt/knowhere

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    fonts-dejavu-core \
    libgl1 \
    libglib2.0-0 \
    libgomp1 \
    libreoffice-calc \
    libreoffice-core \
    libreoffice-impress \
    libreoffice-writer \
    postgresql-client \
    redis-tools \
    tini \
  && rm -rf /var/lib/apt/lists/* \
  && update-ca-certificates \
  && mkdir -p /data/users /data/models/huggingface /tmp/knowhere

COPY --from=node-runtime /usr/local/bin/node /usr/local/bin/node
COPY --from=node-runtime /usr/local/bin/npm /usr/local/bin/npm
COPY --from=node-runtime /usr/local/bin/npx /usr/local/bin/npx
COPY --from=node-runtime /usr/local/bin/corepack /usr/local/bin/corepack
COPY --from=node-runtime /usr/local/lib/node_modules /usr/local/lib/node_modules

COPY --from=api-deps /opt/knowhere/venvs/api /opt/knowhere/venvs/api
COPY --from=worker-deps /opt/knowhere/venvs/worker /opt/knowhere/venvs/worker

COPY .build/sources/knowhere-api /opt/knowhere/source/api
COPY --from=dashboard-deps /opt/knowhere/source/dashboard/node_modules /opt/knowhere/dashboard/node_modules
COPY --from=dashboard-builder /opt/knowhere/source/dashboard/package.json /opt/knowhere/dashboard/package.json
COPY --from=dashboard-builder /opt/knowhere/source/dashboard/pnpm-lock.yaml /opt/knowhere/dashboard/pnpm-lock.yaml
COPY --from=dashboard-builder /opt/knowhere/source/dashboard/next.config.js /opt/knowhere/dashboard/next.config.js
COPY --from=dashboard-builder /opt/knowhere/source/dashboard/tsconfig.json /opt/knowhere/dashboard/tsconfig.json
COPY --from=dashboard-builder /opt/knowhere/source/dashboard/public /opt/knowhere/dashboard/public
COPY --from=dashboard-builder /opt/knowhere/source/dashboard/.next /opt/knowhere/dashboard/.next
COPY --from=dashboard-builder /opt/knowhere/source/dashboard/i18n /opt/knowhere/dashboard/i18n
COPY --from=dashboard-builder /opt/knowhere/source/dashboard/drizzle.config.ts /opt/knowhere/dashboard/drizzle.config.ts
COPY --from=dashboard-builder /opt/knowhere/source/dashboard/drizzle /opt/knowhere/dashboard/drizzle
COPY --from=dashboard-builder /opt/knowhere/source/dashboard/lib/db /opt/knowhere/dashboard/lib/db

COPY scripts/entrypoint.sh /usr/local/bin/knowhere-self-hosted-entrypoint
COPY scripts/create-storage-buckets.py /usr/local/bin/knowhere-create-storage-buckets
COPY scripts/configure-storage-events.py /usr/local/bin/knowhere-configure-storage-events

RUN chmod +x /usr/local/bin/knowhere-self-hosted-entrypoint /usr/local/bin/knowhere-create-storage-buckets /usr/local/bin/knowhere-configure-storage-events

EXPOSE 3000 5005

HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=5 \
  CMD curl -fsS http://127.0.0.1:3000/login >/dev/null && curl -fsS http://127.0.0.1:5005/health >/dev/null || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/knowhere-self-hosted-entrypoint"]
