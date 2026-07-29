# ADR 0001: Local MinerU mode via forked image patch

Date: 2026-07-22

## Status

Accepted. Stopgap pending upstream support in the `knowhere` monorepo.

## Context

Knowhere's upstream `pdf_service.py` only implements the MinerU **cloud** flow: request an upload URL → upload the PDF → poll batch status → download a ZIP. Self-hosted deployments that want to run fully offline (or against a private MinerU instance on their own network) cannot use the cloud-only batch APIs (`/file-urls/batch`, `/extract/task/batch`, `/extract-results/batch`). Local MinerU exposes a single synchronous `/file_parse` endpoint with a different request schema and a different ZIP layout.

MinerU is also single-concurrency by default (`max_concurrent_requests=1`), which interacts non-trivially with Knowhere's shard fan-out.

## Decision

Ship a **forked Docker image** (`Dockerfile.forked`) that layers a unified diff (`patches/pdf_service.patch`) on top of the pinned upstream image (`ghcr.io/ontos-ai/knowhere:${KNOWHERE_BASE_TAG}`).

The patch adds:

1. A `MINERU_LOCAL_MODE` gate at the top of `parse_via_full`, dispatching to a new `parse_via_local`.
2. `parse_via_local` — POSTs the PDF as multipart form data to `{MINERU_URL}/file_parse`. Parameters (`lang_list`, `backend`) are env-overridable via `MINERU_LOCAL_LANG_LIST` and `MINERU_LOCAL_BACKEND`, with `ch`/`pipeline` defaults that match the broadest local MinerU compatibility (Chinese, English, Japanese, Traditional Chinese, Latin; CPU-only).
3. `_flatten_extracted_zip` — flattens the local MinerU ZIP structure (`{stem}/auto/{stem}.md` + `{stem}/auto/images/*`) into `{output_dir}/full.md` + `{output_dir}/images/*`. Hard-fails on zero or multiple `.md` files.
4. A separate local-mode `requests.Session` with `Retry(read=0, ...)` so that a `ReadTimeout` (from queue wait at `max_concurrent_requests=1`) does not cascade into retry storms. 429 responses raise `UnavailableException` using `get_retry_after_seconds` — no quota manager call (local mode has no API key).
5. `MINERU_LOCAL_TIMEOUT` (env-overridable, default 3600s) — per-shard timeout that includes queue wait when `MINERU_SHARD_CONCURRENCY > 1`.

Distribution is a forked image, not a volume mount, so upgrades are explicit (bump `KNOWHERE_BASE_TAG`) and drift is detectable via `scripts/check-patch-drift.sh` (`patch --dry-run` against the upstream file extracted from the base image). Editing the patch is mediated by `scripts/edit-patch.sh` to avoid hand-maintaining a stale working copy.

`compose.yaml` adds `extra_hosts: ["host.docker.internal:host-gateway"]` to the app service so that `MINERU_URL=http://host.docker.internal:8000` resolves on Linux Docker Engine (auto-injected on Docker Desktop and OrbStack).

## Consequences

### Positive

- Self-hosted deployments can run without `mineru.net` or any MinerU cloud API key.
- Upgrades are deliberate: `docker compose pull` against `:latest` no longer silently breaks the patched file (it can't — the patch is applied at build time against a pinned base tag). Drift is caught at CI build time by `check-patch-drift.sh`.
- The patch surface is minimal and self-documenting (unified diff).
- Existing cloud-mode deployments are unaffected (`MINERU_LOCAL_MODE=false` by default).

### Negative

- Drift maintenance: every upstream `pdf_service.py` change requires re-running `edit-patch.sh` and re-testing. Mitigated by `check-patch-drift.sh` as a CI gate.
- `MINERU_LOCAL_*` env vars are read via `os.environ.get` rather than typed `pydantic_settings` fields, because the image's `shared.core.config.settings` is baked and the forked-image patch cannot edit it. A future upstream PR should add proper typed fields — see "Future work".
- The forked image is published under a personal namespace (`ghcr.io/gdccyuen/knowhere-self-hosted`), not the upstream org. Operators must trust this registry or rebuild locally with `docker compose build`.
- Multi-shard PDFs against a single-concurrency MinerU can pile up in the queue; users must tune `MINERU_SHARD_CONCURRENCY` and `MINERU_LOCAL_TIMEOUT` for very large documents.

## Pitfalls

These were encountered during development and are documented here for future maintainers. Most are deployment-time gotchas rather than patch issues.

### 1. DeepSeek text model used for vision tasks

`IMAGE_MODEL` and `IMAGE_MODEL_MAX` must be vision-capable. Knowhere sends `image_url` content blocks to these models during PDF image analysis; text-only models like `deepseek-v4-flash` raise `LLMServiceException: unknown variant 'image_url', expected 'text'`. Default the image models to `qwen3.6-flash` (or another vision-capable model) when running local mode.

### 2. MinerU cloud-only batch APIs called against local MinerU

Local MinerU's OpenAPI only exposes `/file_parse` (sync), `/tasks` (async submit), `/tasks/{id}` (status), `/tasks/{id}/result` (result). The cloud endpoints (`/file-urls/batch`, `/extract/task/batch`, `/extract-results/batch`) return 404. `MINERU_UPLOAD_MODE_ENABLED=false` does not help — it switches between two cloud modes (URL-based vs upload-based), neither of which works locally. This is the core motivation for the `MINERU_LOCAL_MODE` flag.

### 3. ZIP from local MinerU has a nested structure

Local MinerU ZIP extracts to `{stem}/auto/{stem}.md` + `{stem}/auto/images/*.jpg`. Knowhere's downstream code expects `output_dir/full.md` and `images/` at the output dir root. `_flatten_extracted_zip` walks the extracted tree, moves keep-ext files to the root, removes the rest, and renames the first (and only) `.md` to `full.md`. Multiple `.md` files would silently pick the wrong one, so the patch hard-fails in that case.

### 4. `MINERU_LOCAL_LANG_LIST` does not accept `auto`

Cloud MinerU accepts `language: "auto"`; local MinerU's `lang_list` enum is `ch, ch_server, korean, ta, te, ka, th, el, arabic, east_slavic, cyrillic, devanagari`. The patch defaults to `ch`, which covers Chinese, English, Japanese, Traditional Chinese, and Latin — broad enough for most use. Setting `auto` against local MinerU returns `400 Language auto not supported`.

### 5. `return_images=True` is load-bearing

The default for the `return_images` field is `false`. Without it, the ZIP contains only `og.md` and no `images/` directory — but the markdown references image paths under `images/`. The patch explicitly sends `return_images=True`.

### 6. `max_concurrent_requests=1` and shard pile-up

Local MinerU's `/health` reports `max_concurrent_requests=1`. With the default `MINERU_SHARD_CONCURRENCY=3`, three shard HTTP POSTs are issued simultaneously; the second and third queue at MinerU. The session-level `ReadTimeout` clock for the Nth shard starts when **its** POST begins, not when MinerU starts processing it — so a sharded PDF's last shard's effective wall-time budget is `(N-1) * per_shard_parse_time + own_parse_time`. The Q8 decision (separate session with `Retry(read=0)`) prevents a `ReadTimeout` from triggering a urllib3 retry that would push the request to the back of the same queue.

### 7. `host.docker.internal` resolution on Linux

Auto-injected on Docker Desktop and OrbStack, but missing on Linux Docker Engine. `compose.yaml` adds `extra_hosts: ["host.docker.internal:host-gateway"]` to the app service (parity with the existing localstack service entry) so that `MINERU_URL=http://host.docker.internal:8000` works on every platform.

### 8. `MINERU_UPLOAD_MODE_ENABLED` interaction with PPTX cache

`get_existing_mineru_source_s3_key` is called from `rendered_transform.py` before `parse_pdfs` to reuse a previously-rendered PPTX→PDF artifact. With the default `MINERU_UPLOAD_MODE_ENABLED=true`, S3 URL mode is not active, so cache reuse is skipped and PPTX re-renders on each parse. This is **pre-existing** behavior unrelated to the patch. In local mode, setting `MINERU_UPLOAD_MODE_ENABLED=false` enables PPTX cache reuse via LocalStack S3 presigned URLs. The patch does not force this — operators opt in if they care about PPTX rerun cost.

## Future work

- **Upstream contribution.** This patch is a stopgap. A first-class upstream PR to the `knowhere` monorepo would: add `MINERU_LOCAL_MODE`, `MINERU_LOCAL_LANG_LIST`, `MINERU_LOCAL_BACKEND`, `MINERU_LOCAL_TIMEOUT` as typed `pydantic_settings` fields in `shared.core.config.mineru`; refactor `parse_via_full` to dispatch via `settings.MINERU_LOCAL_MODE`; drop the `os.environ.get` reads; and add unit tests for `_flatten_extracted_zip` against representative ZIP fixtures. When a `knowhere` release ≥ X ships this natively, the forked-image approach in this repo should be retired: bump `KNOWHERE_BASE_TAG` to that release, delete `patches/pdf_service.patch`, `Dockerfile.forked`, `scripts/check-patch-drift.sh`, `scripts/edit-patch.sh`, and supersede this ADR.
- **Async `/tasks` API.** If a deployment regularly parses very large PDFs where the sync `/file_parse` timeout becomes the bottleneck, the patch can be extended to use the local MinerU async API (`/tasks` POST → poll `/tasks/{id}` → fetch `/tasks/{id}/result`). This mirrors the cloud batch pattern and avoids holding open HTTP connections during queue wait. Not pursued in this iteration — the sync endpoint is sufficient for typical use.
- **`MINERU_LOCAL_BACKEND=vlm-engine` smoke test.** The current smoke fixture only exercises `pipeline`. A GPU-enabled test environment could verify the VLM backends.
