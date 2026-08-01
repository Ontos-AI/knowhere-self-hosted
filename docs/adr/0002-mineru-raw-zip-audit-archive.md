# ADR 0002: Save raw MinerU ZIP for permanent audit and re-processing

Date: 2026-07-31

## Status

Accepted. Implemented (todos 1/6–6/6 complete) across three upstream PRs:

- [Ontos-AI/knowhere#233](https://github.com/Ontos-AI/knowhere/pull/233) — step 3/6: local MinerU mode archives the raw ZIP (`response_format_zip=true` + `return_original_file=true`), uploads to `results/{job_id}/mineru_raw.zip`, writes the `_mineru_raw_s3_key.txt` sidecar.
- [Ontos-AI/knowhere#238](https://github.com/Ontos-AI/knowhere/pull/238) — step 4/6: cloud mode archives via `on_zip_downloaded` callback on `download_and_extract_zip`.
- [Ontos-AI/knowhere#239](https://github.com/Ontos-AI/knowhere/pull/239) — steps 1/6, 2/6, 5/6, 6/6: migration + ORM field, caller wiring stores the sidecar value on `job_results.mineru_raw_s3_key`, and `GET /api/v2/documents/{document_id}/files/mineru-raw` returns presigned URL(s).

Refinements made during implementation (deltas from the plan above):

- **Sharded jobs** archive one raw ZIP per shard with suffixed keys (`results/{job_id}/mineru_raw_shard0.zip`, ...); the worker merges per-shard sidecars into the main output dir sidecar (newline-joined) before the shard workspace is cleaned up.
- The download endpoint returns a single `url` when one key is stored and a `urls` list for sharded (multi-key) jobs.
- The cloud-mode sidecar is written after polling completes (not inside the callback), because `download_and_extract_zip`'s extraction cleanup would prune a sidecar written during the callback.

## Context

During live testing of local MinerU mode (ADR 0001), we discovered that MinerU 3.4.0's `/file_parse` can return a ZIP (`response_format_zip=true`) containing the parsed markdown, extracted images, and — with `return_original_file=true` — the original input PDF. This ZIP is the complete raw output of MinerU for a given document.

Currently, Knowhere discards the raw MinerU output after extracting markdown and images. There is no way to:
- Audit what MinerU actually returned (for debugging parsing quality)
- Re-process a document without re-calling MinerU (which costs API credits in cloud mode)
- Inspect the original PDF alongside MinerU's output

The requirement is to **permanently archive** the raw MinerU ZIP for every job, in both local and cloud mode.

## Decision

Store the raw MinerU ZIP as an S3 artifact, with the S3 key recorded in the `job_results` table. Expose a download endpoint for retrieval.

### Storage: S3 + DB column (not DB blob)

The raw ZIP is uploaded to the `knowhere-results` bucket at `results/{job_id}/mineru_raw.zip`. The S3 key is stored in a new nullable `mineru_raw_s3_key TEXT` column on `job_results`.

This follows the existing pattern — every binary artifact in Knowhere (uploads, result ZIPs, page citation assets) is stored in S3 with paths in the database. Storing blobs directly in PostgreSQL would break the pattern, bloat backups, pressure the connection pool, and complicate replication.

### Local mode (`parse_via_local`)

Switch to `response_format_zip=true` + `return_original_file=true`. The response body is a raw ZIP. Upload it to S3 before extracting + flattening. Write the S3 key to a sidecar file (`{output_dir}/_mineru_raw_s3_key.txt`) for the caller to pick up — the parse call chain is 4 layers deep and doesn't return values upward, so a sidecar file is less invasive than threading a return value through.

### Cloud mode (`poll_mineru_task` → `download_and_extract_zip`)

`download_and_extract_zip` already saves the ZIP to a temp file (`parsed.zip`), extracts it, then deletes the temp file. Add an optional `on_zip_downloaded: Callable[[Path], None] | None` callback parameter that fires after download but before extract+delete. In `poll_mineru_task`, pass a callback that uploads the ZIP to S3 and writes the S3 key to the same sidecar file.

### Caller wiring

After parsing completes, the job result creation code reads `_mineru_raw_s3_key.txt` from `output_dir` and stores the value on `job_results.mineru_raw_s3_key`.

### Download API

`GET /api/v2/documents/{document_id}/files/mineru-raw` — follows the existing `page-citation-source` endpoint pattern. Looks up document → current job result → `mineru_raw_s3_key`. Returns 404 if null. Otherwise returns a presigned download URL.

## Consequences

### Positive

- Every MinerU parse is permanently archived with the original input file included.
- Operators can download raw ZIPs for audit without database access.
- Re-processing is possible without re-calling MinerU (useful when iterating on chunking/retrieval config).
- Consistent with existing S3 + DB path pattern.
- `response_format_zip=true` simplifies `parse_via_local` (revert from base64 JSON to ZIP extract+flatten).

### Negative

- Additional S3 storage per job (raw ZIP with images + original PDF adds ~1–10 MB per document).
- Sidecar file (`_mineru_raw_s3_key.txt`) is a pragmatic but unconventional IPC mechanism — undocumented knowledge for future maintainers.
- Cloud mode requires modifying the shared `download_and_extract_zip` utility (adding a callback parameter) — minimal but touches shared code.

## Alternatives considered

- **DB blob (`bytea` column)**: rejected — breaks the S3+path pattern, bloats backups, pressures connection pool, complicates replication. See discussion in session.
- **Env-gated debug save only**: rejected — requirement is permanent audit, not just development debugging.
- **Thread return value through parse call chain**: rejected — 4 layers deep (`parse_pdfs` → `_parse_pdf_via_shards` → `parse_via_full` → `parse_via_local`/`poll_mineru_task`), too invasive for the value returned.

## Implementation plan

| Step | Description | Depends on |
| --- | --- | --- |
| 1/6 | DB migration: add `mineru_raw_s3_key TEXT` to `job_results` | — |
| 2/6 | ORM model: add field to `JobResult` | 1/6 |
| 3/6 | Local mode: switch to ZIP mode, upload to S3, sidecar file | 1/6, 2/6 |
| 4/6 | Cloud mode: add callback to `download_and_extract_zip`, upload to S3 | 1/6, 2/6 |
| 5/6 | Caller wiring: read sidecar, store S3 key on job result | 3/6, 4/6 |
| 6/6 | Download API endpoint + contract test | 1/6, 2/6, 5/6 |

PRs: 3/6 updates PR #233. 4/6 opens a new PR. 1/6+2/6+5/6+6/6 in a third PR (shared infrastructure).
