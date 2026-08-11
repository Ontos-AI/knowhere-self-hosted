# AGENTS.md

## What this repo is (and is not)

This repo **only packages** Knowhere for self-hosted Docker Compose deployment. It contains **no application code**. The API, worker, and dashboard source live in two separate upstream repos and are pulled in at build time:

- `Ontos-AI/knowhere` — Python API + Celery worker (`apps/api`, `apps/worker`, `packages/shared-python`)
- `Ontos-AI/knowhere-dashboard` — Next.js dashboard

Do not look for or edit app logic here. Changes to API/worker/dashboard behavior must be made upstream. This repo's surface is: `Dockerfile`, `compose.yaml`, `.env.defaults`, `scripts/`, `docs/`, `.github/workflows/`.

## Verification

There is **no test, lint, typecheck, or format toolchain** in this repo — do not assume `npm test`, `pytest`, `ruff`, etc. exist. The only verification is the smoke test:

```bash
./scripts/smoke-test.sh
```

It brings up the full stack under `COMPOSE_PROJECT_NAME=knowhere-self-hosted-smoke` on shifted ports (dashboard `13000`, API `15005`, postgres `15432`, redis `16379`, localstack `14566`) and polls `/login` + `/health` for up to 90×2s.

For shell/Python script edits, sanity-check with `bash -n scripts/*.sh` and `python3 -m py_compile scripts/*.py`.

## Local image build

The Dockerfile copies from `.build/sources/{knowhere,knowhere-dashboard}/`, which is gitignored and staged by:

```bash
./scripts/prepare-sources.sh
```

By default it expects sibling checkouts at `../knowhere` and `../knowhere-dashboard` (archive of `HEAD`). Override with `KNOWHERE_API_SOURCE` / `KNOWHERE_API_REF` / `KNOWHERE_DASHBOARD_SOURCE` / `KNOWHERE_DASHBOARD_REF`. Then `docker build .`.

## Image publishing

Automated via `.github/workflows/publish-image.yml` only — **manually triggered** (`workflow_dispatch`) with `image_tag`, `api_ref`, `dashboard_ref`, `publish_latest`, `create_github_release`. Builds multi-arch (`linux/amd64,linux/arm64`) and pushes to both GHCR (`ghcr.io/ontos-ai/knowhere`) and Aliyun ACR. Tags matching `-(alpha|beta|rc)` are marked prerelease. Do not push tags by hand to release.

## Environment configuration

`compose.yaml` loads `.env.defaults` (committed, **do not put secrets here**) then `.env` (operator overrides, gitignored) via `env_file`. The README tells operators to create a small `.env` with only overrides.

Runtime defaults are layered further by `scripts/entrypoint.sh` via `setDefault` and several values are **derived** (e.g. `API_DATABASE_URL` from `POSTGRES_*`, `NEXT_PUBLIC_APP_URL` from `DASHBOARD_PUBLIC_URL`, `CELERY_REDIS_URL` from `REDIS_*`). When changing a default, check both `.env.defaults` and `entrypoint.sh` — the entrypoint can override what's in the file. Full variable reference: `docs/configuration.md`.

Auto-generated secrets (`SECRET_KEY`, `BETTER_AUTH_SECRET`, `USERS_VERIFY_*`, `USERS_RESET_PASSWORD_*`) are persisted in the `knowhere_secrets` volume at `/data/secrets/`; deleting that volume regenerates them.

## Single-container runtime

The image runs **three processes** in one container via `scripts/entrypoint.sh` (supervised by `tini`), in this order:

1. wait for postgres → ensure extensions (`uuid-ossp`, `pg_trgm`)
2. wait for redis
3. create S3 buckets (`scripts/create-storage-buckets.py`)
4. run dashboard drizzle migrations
5. start API (`apps/api/main.py`, port 5005) → wait for `/health`
6. configure S3 event notifications + SNS subscription (`scripts/configure-storage-events.py`) — runs after API so the webhook target is up
7. start worker (`apps/worker/worker.py`)
8. start dashboard (`next start`, port 3000)

Container exits if any of the three processes exits. Healthcheck hits both `:3000/login` and `:5005/health`.

Two separate venvs are built in the image: `/opt/knowhere/venvs/api` and `/opt/knowhere/venvs/worker`. Both install from the upstream `uv.lock` with `uv sync --locked --no-dev`.

## Compose services

`app` (the combined image), `postgres:15-alpine`, `redis:7-alpine`, `localstack:3.8` (S3/SNS/SQS/IAM/STS with persistence). All host ports bind `127.0.0.1` by default; set `*_HOST_BIND=0.0.0.0` to expose. Named volumes persist data across `docker compose down`.

LocalStack is reachable at `localhost.localstack.cloud:4566` (network alias) for S3 operations; `S3_ENDPOINT_URL` defaults to that host so presigned URLs work from inside the container.

## Telemetry

Anonymous telemetry is **on by default** (`TELEMETRY_ENABLED=true`). Opt out by setting `TELEMETRY_ENABLED=false`. Event schema and privacy bounds are documented in `docs/configuration.md` → "Anonymous product telemetry".

## Conventions

- Keep `.env.defaults` and `docs/configuration.md` in sync when adding/removing/renaming env vars — the docs are the operator-facing reference and the file is the executable default.
- `README.md` and `README.zh-CN.md` (plus `docs/configuration.md` / `docs/configuration.zh-CN.md`) are maintained in parallel; update both languages for user-facing changes.
- Branch naming seen in history: `feat/`, `fix/`, `chore/`, `docs/`, `ci/` with `<author>/<topic>`. PRs merge into `main`.
- The default image (`KNOWHERE_IMAGE=ghcr.io/ontos-ai/knowhere:latest`) and an Aliyun mirror are both supported; mention both when touching image references.

## Agent skills

### Issue tracker

Local markdown under `.scratch/<feature-slug>/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical defaults (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`) recorded as `Status:` lines in each issue file. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout (`CONTEXT.md` at repo root, `docs/adr/` for architectural decisions). See `docs/agents/domain.md`.
