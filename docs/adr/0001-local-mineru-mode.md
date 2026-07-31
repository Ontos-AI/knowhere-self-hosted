# ADR 0001: Local MinerU mode via forked image patch

Date: 2026-07-22

## Status

Accepted. Upstream PR [Ontos-AI/knowhere#233](https://github.com/Ontos-AI/knowhere/pull/233) opened to replace this stopgap with first-class support. Updated with findings from live testing against MinerU 3.4.0 (see pitfalls 9–11).

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

### 9. Form field is `files`, not `file` (MinerU 3.4.0)

Local MinerU's `/file_parse` endpoint expects the PDF under the multipart form field name `files` (an array), not `file`. Sending `file` returns `422 Unprocessable Entity: {"detail":[{"type":"missing","loc":["body","files"],"msg":"Field required","input":null}]}`. The upstream PR uses `files = {"files": (filename, file_obj, "application/pdf")}`.

### 10. Default response is JSON with inline content, not a ZIP (MinerU 3.4.0)

MinerU 3.4.0's `/file_parse` returns `application/json` by default — not a ZIP as ADR 0001 originally assumed. The JSON response contains:

```json
{
  "task_id": "...",
  "status": "completed",
  "result_url": "http://.../tasks/{id}/result",
  "results": {
    "{stem}": {
      "md_content": "# heading ...",
      "images": { "hash.jpg": "<base64>", ... }
    }
  }
}
```

The `result_url` endpoint also returns JSON (same `results` structure), not a ZIP. The upstream PR (as of commit `4eae0385`) writes `md_content` to `full.md` and base64-decodes images to `images/`. A future revision will switch to `response_format_zip=true` to get a real ZIP (see ADR 0002).

### 11. `response_format_zip=true` returns a ZIP with nested layout

When `response_format_zip=true` is set, MinerU 3.4.0 returns `application/zip` with the nested `{stem}/auto/{stem}.md` + `{stem}/auto/images/*` layout that `_flatten_extracted_zip` was originally designed for. Adding `return_original_file=true` also includes `{stem}/auto/{stem}_origin.pdf`. This is the preferred path going forward (see ADR 0002).

## Future work

- **Upstream contribution.** Upstream PR [Ontos-AI/knowhere#233](https://github.com/Ontos-AI/knowhere/pull/233) implements first-class `MINERU_LOCAL_MODE` support: typed `pydantic_settings` fields in `shared.core.config.mineru`, `parse_via_full` dispatch, unit tests for `_flatten_extracted_zip`. When a `knowhere` release ships this natively, bump `KNOWHERE_BASE_TAG` to that release and supersede this ADR.
- **Switch to `response_format_zip=true`.** PR #233 currently handles MinerU 3.4.0's default JSON response (inline `md_content` + base64 images). Switching to `response_format_zip=true` simplifies the code (revert to `_flatten_extracted_zip`, drop base64 decoding) and enables saving the raw ZIP for audit (see ADR 0002).
- **Async `/tasks` API.** If a deployment regularly parses very large PDFs where the sync `/file_parse` timeout becomes the bottleneck, the patch can be extended to use the local MinerU async API (`/tasks` POST → poll `/tasks/{id}` → fetch `/tasks/{id}/result`). Not pursued — sync endpoint is sufficient for typical use.
- **`MINERU_LOCAL_BACKEND=vlm-engine` smoke test.** The current smoke fixture only exercises `pipeline`. A GPU-enabled test environment could verify the VLM backends.
