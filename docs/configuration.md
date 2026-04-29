# Knowhere Self-Hosted Configuration Reference

English | [中文](configuration.zh-CN.md)

This document covers optional configuration beyond the minimal startup path. A normal local deployment only needs `MINERU_API_KEYS` and either `DS_KEY` or `ALI_API_KEYS`, as shown in the README.

Docker Compose reads `.env.defaults` first, then reads `.env`. `.env.defaults` is the built-in default reference. For real deployments, create a small `.env` file that only contains values you need to override, and never commit real secrets to Git.

## Base URLs and Images

| Variable | Usage | Example values |
| --- | --- | --- |
| `DASHBOARD_PUBLIC_URL` | Public Dashboard URL opened by users in their browser. Also used for login, signup, and callback validation. | `http://localhost:3000`, `https://knowhere.example.com` |
| `DASHBOARD_HOST_PORT` | Host port mapped to the Dashboard. | `3000`, `8080` |
| `API_HOST_PORT` | Host port mapped to the API. | `5005` |
| `POSTGRES_HOST_PORT` | Host port mapped to PostgreSQL. | `5432` |
| `REDIS_HOST_PORT` | Host port mapped to Redis. | `6379` |
| `LOCALSTACK_HOST_PORT` | Host port mapped to the LocalStack S3-compatible service. | `4566` |
| `KNOWHERE_IMAGE` | Knowhere self-hosted Docker image. | `ghcr.io/ontos-ai/knowhere:latest` |

For networks where GHCR is slow or unavailable, use the Aliyun registry image:

```bash
KNOWHERE_IMAGE=knowhere-registry.cn-shenzhen.cr.aliyuncs.com/knowhere/knowhere:latest
```

## Required External Services

| Variable | Usage | Example values |
| --- | --- | --- |
| `MINERU_API_KEYS` | MinerU API key pool for PDF parsing. Supports JSON arrays, comma-separated values, newline-separated values, and `token_id=api_key` entries. | `mineru-key-1,mineru-key-2` |
| `DS_KEY` | DeepSeek API key. Set this when using DeepSeek as the text model provider. | `sk-...` |
| `ALI_API_KEYS` | Alibaba Cloud Model Studio DashScope API key pool. Set this when using Qwen models. The format is the same as `MINERU_API_KEYS`. | `sk-...` |

`MINERU_API_KEYS` and `ALI_API_KEYS` support multiple keys so they can form a key pool. When one key reaches provider quota or rate limits, Knowhere can rotate to another key. A single key also works.

Get keys from the providers' official websites:

- [MinerU](https://mineru.net/)
- [DeepSeek](https://platform.deepseek.com/)
- [Alibaba Cloud Model Studio DashScope](https://bailian.console.aliyun.com/)

## AI Models and Providers

| Variable | Usage | Example values |
| --- | --- | --- |
| `DS_URL` | DeepSeek OpenAI-compatible base URL. | `https://api.deepseek.com/v1` |
| `ALI_URL` | DashScope OpenAI-compatible base URL. | `https://dashscope.aliyuncs.com/compatible-mode/v1` |
| `GPT_API_KEY` | OpenAI or other compatible service key. The default URL routing still depends on model names; confirm provider support in the image before using it. | `sk-...` |
| `GLM_API_KEY` | Zhipu GLM API key. | `...` |
| `GLM_URL` | Zhipu GLM base URL. | `https://open.bigmodel.cn/api/paas/v4` |
| `ARK_API_KEY` | Volcengine Ark API key. | `...` |
| `ARK_URL` | Volcengine Ark chat completions URL. | `https://ark.cn-beijing.volces.com/api/v3/chat/completions` |
| `NORMOL_MODEL` | Main model for text, table understanding, and summarization. | `deepseek-chat`, `qwen-plus` |
| `HIERARCHY_LLM_MODEL` | Model for document heading hierarchy and table-of-contents recognition. Falls back to `NORMOL_MODEL` when empty. | `deepseek-chat`, `qwen-plus` |
| `IMAGE_MODEL` | Default vision model for image summaries, image collections, and OCR-related work. | `qwen-vl-plus` |
| `IMAGE_MODEL_MAX` | Higher-capability model for image Q&A and OCR. | `qwen-vl-plus` |
| `EMBEDDING_MODEL` | Embedding model used for retrieval. | `text-embedding-v4` |
| `OPENAI_CLIENT_TIMEOUT` | OpenAI-compatible client timeout, in seconds. | `300` |
| `LLM_MOCK_ENABLED` | Whether to short-circuit LLM calls with mock responses, mainly for tests. | `false` |
| `HEADING_LLM_MAX_CONCURRENT` | Maximum concurrent LLM calls for heading recognition. | `8` |
| `SUMMARY_LLM_MAX_CONCURRENT` | Maximum concurrent LLM calls for summaries, images, and tables. | `8` |
| `ALI_TOKEN_RPM_LIMIT` | Per-minute request limit for each DashScope key. | `300` |
| `ALI_TOKEN_DAILY_LIMIT` | Daily request limit for each DashScope key. | `10000` |
| `ALI_TOKEN_COOLDOWN_SECONDS` | Cooldown seconds after a DashScope key receives a 429 response. | `60` |
| `ALI_INLINE_MAX_RETRIES` | Token rotation retry count for DashScope calls. | `3` |
| `ALI_SDK_MAX_RETRIES` | Internal SDK retry count for a single DashScope token. | `3` |

DeepSeek example:

```bash
DS_KEY=your-deepseek-api-key
NORMOL_MODEL=deepseek-chat
HIERARCHY_LLM_MODEL=deepseek-chat
```

Alibaba Cloud Model Studio DashScope example:

```bash
ALI_API_KEYS=your-dashscope-api-key
NORMOL_MODEL=qwen-plus
HIERARCHY_LLM_MODEL=qwen-plus
IMAGE_MODEL=qwen-vl-plus
IMAGE_MODEL_MAX=qwen-vl-plus
EMBEDDING_MODEL=text-embedding-v4
```

## MinerU and Optional Parsing Services

| Variable | Usage | Example values |
| --- | --- | --- |
| `MINERU_URL` | MinerU API base URL. | `https://mineru.net/api/v4` |
| `FORCE_MINERU_UPLOAD_ENABLED` | Force MinerU direct upload mode instead of reusable S3 URLs. | `true` |
| `MINERU_TOKEN_RPM_LIMIT` | Per-minute request limit for each MinerU key. | `300` |
| `MINERU_TOKEN_DAILY_LIMIT` | Daily request limit for each MinerU key. | `10000` |
| `MINERU_TOKEN_COOLDOWN_SECONDS` | Cooldown seconds after a MinerU key is rate-limited. | `60` |
| `MINERU_API_TIMEOUT` | MinerU API request timeout, in seconds. | `60` |
| `MINERU_UPLOAD_CONNECT_TIMEOUT` | MinerU file upload connection timeout, in seconds. | `10` |
| `MINERU_UPLOAD_READ_TIMEOUT` | MinerU file upload read timeout, in seconds. | `600` |
| `MINERU_RATE_LIMIT_MAX_RETRY_AFTER` | Maximum wait seconds for MinerU 429 retry-after handling. | `60` |
| `MINERU_POOL_MAXSIZE` | MinerU HTTP connection pool size. | `50` |
| `MINERU_UPLOAD_RETRY_TOTAL` | Retry count for transient MinerU upload failures. | `3` |
| `MINERU_UPLOAD_RETRY_BACKOFF_FACTOR` | MinerU upload retry backoff factor. | `2` |
| `MINERU_URL_MODE_PRESIGN_EXPIRY` | Presigned URL expiry for MinerU URL mode, in seconds. | `3600` |
| `ILOVEAPI_PUBLIC_KEY` | iLoveAPI public key for PPTX to PDF conversion. | `project_public_key` |
| `ILOVEAPI_SECRET_KEY` | iLoveAPI secret key. | `project_secret_key` |
| `ILOVEAPI_KEYS` | iLoveAPI project pool as a JSON array. Each item contains `public_key` and `secret_key`. | `[{"public_key":"...","secret_key":"..."}]` |
| `ILOVEAPI_BASE_URL` | iLoveAPI base URL. | `https://api.ilovepdf.com/v1` |
| `ILOVEAPI_TIMEOUT` | iLoveAPI request timeout, in seconds. | `120` |
| `ILOVEAPI_TOKEN_RPM_LIMIT` | Per-minute request limit for each iLoveAPI project. | `25` |
| `ILOVEAPI_TOKEN_DAILY_LIMIT` | Daily file limit for each iLoveAPI project. | `250` |
| `ILOVEAPI_MAX_CONCURRENT` | Maximum concurrent iLoveAPI conversions. | `5` |

## Dashboard, Auth, and Branding

| Variable | Usage | Example values |
| --- | --- | --- |
| `NEXT_PUBLIC_APP_URL` | Public Dashboard URL. Derived from `DASHBOARD_PUBLIC_URL` when unset. | `https://knowhere.example.com` |
| `BETTER_AUTH_URL` | Better Auth callback and trusted-origin URL. Derived from `NEXT_PUBLIC_APP_URL` when unset. | `https://knowhere.example.com` |
| `NEXT_PUBLIC_API_URL` | Dashboard base URL for proxying API requests. The single-container default uses the local API. | `http://127.0.0.1:5005/api` |
| `NEXT_PUBLIC_AUTH_BASE_URL` | Better Auth route prefix. | `/api/auth` |
| `PASSWORD_LOGIN_ENABLED` | Whether to show password login on the login page. Enabled by default for self-hosted deployments. | `true` |
| `BETTER_AUTH_SECRET` | Better Auth secret. When unset, startup generates one and stores it in the volume. | `a-random-secret-at-least-32-chars` |
| `SECRET_KEY` | API JWT secret. When unset, startup generates one and stores it in the volume. | `a-random-secret` |
| `USERS_VERIFY_TOKEN_SECRET` | Email verification token secret. Generated automatically when unset. | `a-random-secret` |
| `USERS_RESET_PASSWORD_TOKEN_SECRET` | Password reset token secret. Generated automatically when unset. | `a-random-secret` |
| `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` | GitHub OAuth login. | `...` |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | Google OAuth login. | `...` |
| `APPLE_CLIENT_ID` / `APPLE_CLIENT_SECRET` | Reserved Apple OAuth configuration. | `...` |
| `RESEND_API_KEY` | Resend API key for magic link and password reset emails. | `re_...` |
| `RESEND_FROM` | Sender used by Dashboard auth emails. | `Knowhere <noreply@example.com>` |
| `RESEND_FROM_EMAIL` | Sender email used by API emails. | `noreply@example.com` |
| `RESEND_FROM_NAME` | Sender name used by API emails. | `Knowhere` |
| `RESEND_MAX_RETRIES` | Maximum retry count for sending Resend emails from the API. | `3` |
| `RESEND_RETRY_DELAY` | Retry delay for sending Resend emails from the API, in seconds. | `1.0` |
| `COMPANY_NAME` | Runtime brand name shown by the Dashboard. | `Knowhere AI` |
| `SIMPLE_COMPANY_NAME` | Runtime short brand name shown by the Dashboard. | `Knowhere` |
| `ICP_NUMBER` | ICP record number shown in the footer when set. | `ICP ...` |
| `ICP_URL` | ICP record link. | `https://beian.miit.gov.cn/` |
| `DEV_EXTERNAL_API_AUTHORIZATION` | Fixed `Authorization` header used by Dashboard development proxy requests. Do not set in production. | `Bearer dev-token` |

## Database

| Variable | Usage | Example values |
| --- | --- | --- |
| `POSTGRES_PASSWORD` | Root password for the bundled PostgreSQL service. | `root123` |
| `API_DATABASE_URL` | PostgreSQL async URL used by the API. Derived from bundled PostgreSQL settings by default. | `postgresql+asyncpg://root:root123@postgres:5432/Knowhere` |
| `DASHBOARD_DATABASE_URL` | PostgreSQL URL used by the Dashboard. Derived from bundled PostgreSQL settings by default. | `postgresql://root:root123@postgres:5432/Knowhere` |
| `DATABASE_URL` | Used by upstream API/Dashboard development paths. Self-hosted deployments usually do not set it directly. | `postgresql+asyncpg://...` |
| `DB_SSL_MODE` | PostgreSQL SSL mode. | `disable`, `require`, `verify-full` |
| `DB_SSL_CERT` | PostgreSQL client certificate path. | `/path/to/client-cert.pem` |
| `DB_SSL_KEY` | PostgreSQL client private key path. | `/path/to/client-key.pem` |
| `DB_SSL_ROOT_CERT` | PostgreSQL CA certificate path. | `/path/to/ca.pem` |
| `UNSAFE_DB_SSL_ENABLED` | Dashboard database SSL switch for deployment compatibility. | `true` |
| `DB_POOL_SIZE` | API database connection pool size. | `20` |
| `DB_MAX_OVERFLOW` | Maximum overflow connections for the API database pool. | `30` |
| `DB_POOL_RECYCLE` | Database connection recycle interval, in seconds. | `1800` |
| `DB_POOL_TIMEOUT` | Database connection acquisition timeout, in seconds. | `30` |
| `DB_SYNC_POOL_SIZE` | Worker synchronous database connection pool size. | `5` |
| `DB_SYNC_MAX_OVERFLOW` | Maximum overflow connections for the Worker synchronous database pool. | `5` |
| `DB_USE_NULL_POOL` | Whether to disable the API async SQLAlchemy connection pool. | `false` |

## Redis, Celery, and Worker

| Variable | Usage | Example values |
| --- | --- | --- |
| `REDIS_HOST` | Redis host. | `redis` |
| `REDIS_PORT` | Redis port. | `6379` |
| `REDIS_PASSWORD` | Redis password. | `` |
| `REDIS_DATABASE` | Redis database index. | `0` |
| `REDIS_SSL` | Whether to use rediss/TLS. | `false` |
| `REDIS_MAX_CONNECTIONS` | Maximum API Redis connections. | `20` |
| `REDIS_RETRY_ON_TIMEOUT` | Whether to retry Redis timeout errors. | `true` |
| `REDIS_SOCKET_TIMEOUT` | Redis socket timeout, in seconds. | `5.0` |
| `REDIS_SOCKET_CONNECT_TIMEOUT` | Redis connection timeout, in seconds. | `5.0` |
| `REDIS_MAX_RETRIES` | Maximum Redis retry count. | `3` |
| `REDIS_RETRY_DELAY` | Redis retry delay, in seconds. | `1.0` |
| `REDIS_KEY_PREFIX` | Redis key prefix. | `knowhere-api` |
| `REDIS_DEFAULT_TTL` | Default Redis TTL, in seconds. | `86400` |
| `REDIS_SYNC_MAX_CONNECTIONS` | Maximum Worker synchronous Redis connections. | `50` |
| `REDIS_SYNC_POOL_TIMEOUT` | Worker synchronous Redis pool wait timeout, in seconds. | `5` |
| `CELERY_REDIS_URL` | Redis URL used by the Celery broker, result backend, and RedBeat. Derived from `REDIS_*` by default. | `redis://redis:6379/0` |
| `BROKER_POOL_LIMIT` | Celery broker connection pool limit. | `10` |
| `WORKER_CONCURRENCY` | Worker gevent concurrency. | `50` |
| `KB_TASK_MAX_RETRIES` | Maximum retry count for knowledge base tasks. | `2` |
| `KB_TASK_RETRY_COUNTDOWN` | Retry interval for knowledge base tasks, in seconds. | `120` |
| `PYMUPDF_MAX_CONCURRENT` | Maximum concurrent PyMuPDF subprocesses in one pod. | `2` |
| `WORKER_HEARTBEAT_FILE` | Worker heartbeat file path. | `/tmp/knowhere-worker-heartbeat.json` |
| `WORKER_HEARTBEAT_INTERVAL_SECONDS` | Worker heartbeat write interval, in seconds. | `5` |
| `WORKER_HEARTBEAT_STALE_AFTER_SECONDS` | Age after which the Worker heartbeat is considered stale. | `45` |

## Local S3-Compatible Storage

| Variable | Usage | Example values |
| --- | --- | --- |
| `S3_TYPE` | Storage backend type. | `s3`, `oss`, `minio` |
| `S3_BUCKET_NAME` | Default upload bucket. | `knowhere-uploads` |
| `S3_UPLOADS_BUCKET` | Uploaded files bucket. Derived from `S3_BUCKET_NAME` when unset. | `knowhere-uploads` |
| `S3_RESULTS_BUCKET` | Processing results bucket. | `knowhere-results` |
| `S3_ACCESS_KEY_ID` | S3/OSS/MinIO access key. LocalStack default is `test`. | `test` |
| `S3_SECRET_ACCESS_KEY` | S3/OSS/MinIO secret key. LocalStack default is `test`. | `test` |
| `S3_ENDPOINT_URL` | S3-compatible service endpoint. | `http://localhost.localstack.cloud:4566` |
| `S3_PRIVATE_DOMAIN` | Domain used for internal object access. | `http://localhost.localstack.cloud:4566` |
| `S3_REGION` | S3 region. | `us-west-1` |
| `S3_USE_SSL` | Whether to connect to storage with SSL. | `false` |
| `S3_ADDRESSING_STYLE` | S3 addressing style. | `path`, `virtual`, `auto` |
| `S3_TEMP_PATH` | S3 temporary file path. | `/tmp/knowhere` |
| `S3_WEBHOOK_AUTH_TOKEN` | Auth token for S3 event webhooks. | `change-me-storage-webhook-token` |
| `SNS_SIGNATURE_VERIFICATION` | Whether to verify SNS signatures. Disabled by default for LocalStack. | `false` |
| `OSS_ENDPOINT` | Alibaba Cloud OSS endpoint. Required when `S3_TYPE=oss`. | `oss-cn-hangzhou.aliyuncs.com` |
| `OSS_EVENT_CALLBACK_KEY` | OSS event callback signing key. | `...` |
| `OSS_EVENT_VERIFY_SIGNATURE` | Whether to verify OSS event signatures. | `true` |
| `SELF_HOSTED_CREATE_STORAGE_BUCKETS` | Whether startup creates buckets automatically. | `true` |
| `SELF_HOSTED_CONFIGURE_STORAGE_EVENTS` | Whether startup configures upload events automatically. | `true` |
| `SELF_HOSTED_S3_EVENT_TOPIC_NAME` | LocalStack SNS topic name. | `knowhere-s3-upload-events` |
| `SELF_HOSTED_S3_EVENT_WEBHOOK_URL` | S3 upload event callback URL to the API. | `http://app:5005/v1/internal/s3-events` |
| `SELF_HOSTED_STORAGE_CORS_ALLOWED_ORIGINS` | Allowed bucket CORS origins, comma-separated. Empty values automatically include local Dashboard/API URLs. | `https://knowhere.example.com` |
| `SELF_HOSTED_AWS_ENDPOINT_URL` | AWS endpoint used by the self-hosted storage initialization script. Uses `S3_ENDPOINT_URL` when empty. | `http://localstack:4566` |

## File Processing and Retrieval

| Variable | Usage | Example values |
| --- | --- | --- |
| `SUPPORTED_EXTENSIONS` | Allowed upload file extensions, comma-separated. | `.doc,.docx,.pdf,.txt,.xls,.xlsx,.csv,.pptx,.jpg,.jpeg,.png,.md` |
| `MAX_FILE_SIZE` | Maximum file size, in bytes. | `104857600` |
| `MAX_IMAGE_SIZE` | Maximum image size, in bytes. | `10485760` |
| `USERS_DATA_PATH` | Shared user data directory for API and Worker. Must be an absolute path. | `/data/users` |
| `TMP_PATH` | Application temporary directory. | `/tmp/knowhere` |
| `FONT_PATH` | Font file path. | `/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf` |
| `CHROMEDRIVER_PATH` | ChromeDriver path. | `/usr/bin/chromedriver` |
| `MIN_CONFIDENCE_THRESHOLD` | Parsing confidence threshold. | `0.05` |
| `HIGH_IOU_THRESHOLD` | High IoU threshold. | `0.9` |
| `DEFAULT_EMBEDDING_DIM` | Default embedding dimension. | `1024` |
| `DEFAULT_TOP_K` | Default retrieval top-k. | `5` |
| `DEFAULT_BATCH_SIZE` | Default batch size. | `32` |
| `DEFAULT_EPOCHS` | Default training epoch count. | `3` |
| `DEFAULT_THRESHOLD` | Default threshold. | `0.5` |
| `JOB_WAITING_EXPIRE_SECONDS` | Maximum time for jobs in pending/waiting-file states. Also controls presigned S3 URL expiry. | `7200` |
| `JOB_PROCESSING_EXPIRE_SECONDS` | Maximum time for jobs in running/converting states. | `14400` |
| `KB_LAYOUT_LLM_COMPACT_INPUT` | Whether to compact body lines during heading hierarchy recognition to reduce prompt size. | `true` |
| `RETRIEVAL_AGENTIC_ENABLED` | Whether to enable agentic retrieval routing. | `false` |
| `RETRIEVAL_AGENTIC_MAX_STEPS` | Maximum steps for agentic retrieval. | `10` |
| `RETRIEVAL_AGENTIC_MAX_DOCS` | Maximum documents for agentic retrieval. `0` means unlimited. | `0` |
| `RETRIEVAL_AGENTIC_MAX_PATH_EXPANSIONS` | Maximum path expansions for agentic retrieval. | `2` |
| `RETRIEVAL_AGENTIC_MAX_DOC_RETRIES` | Maximum retries per document for agentic retrieval. | `2` |
| `RETRIEVAL_AGENTIC_LATENCY_BUDGET_MS` | Agentic retrieval latency budget, in milliseconds. | `12000` |
| `RETRIEVAL_AGENTIC_MIN_EVIDENCE_PATHS` | Minimum evidence paths for agentic retrieval. | `1` |
| `RETRIEVAL_AGENTIC_TRACE_ENABLED` | Whether to record agentic retrieval traces. | `true` |
| `LOCAL_DEBUG` | Local debug switch. Some parsing flows save intermediate files or skip Redis status writes. | `0`, `1` |
| `KNOWHERE_HOME` | Local root directory used by legacy knowledge graph and MCP auto-registration flows. | `~/.knowhere` |
| `KNOWHERE_API_KEY` | Knowhere API key written to client config during MCP server auto-registration. | `kh_...` |

## Webhooks, QStash, and Async Callbacks

| Variable | Usage | Example values |
| --- | --- | --- |
| `WEBHOOK_SIGNING_SECRET` | Outbound webhook signing secret. | `your-webhook-secret` |
| `WEBHOOK_MASTER_KEY` | Master key used to encrypt webhook secrets. | `your-master-key` |
| `QSTASH_TOKEN` | Upstash QStash API token for async webhook delivery. | `qstash_...` |
| `QSTASH_CALLBACK_BASE_URL` | Public API base URL used by QStash callbacks. | `https://api.example.com/api/v1` |
| `QSTASH_MAX_RETRIES` | Maximum QStash delivery retry count. | `5` |
| `QSTASH_CURRENT_SIGNING_KEY` | Current QStash signing key. | `sig_...` |
| `QSTASH_NEXT_SIGNING_KEY` | Next QStash signing key used for rotation. | `sig_...` |

## Billing, Quotas, and Email Templates

Billing is disabled by default for self-hosted deployments: `BILLING_ENABLED=false`. Enable it only when Stripe and the related API endpoints are ready.

| Variable | Usage | Example values |
| --- | --- | --- |
| `BILLING_ENABLED` | Whether to enable Stripe/credits billing. | `false` |
| `STRIPE_SECRET_KEY` | Stripe secret key. | `sk_live_...` |
| `STRIPE_PUBLISHABLE_KEY` | Stripe publishable key. | `pk_live_...` |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook secret. | `whsec_...` |
| `FREE_PLAN_INITIAL_CREDITS` | Initial credits for new users. | `5` |
| `FREE_PLAN_CREDITS` | Monthly credits for the Free plan. | `100` |
| `PLUS_PLAN_CREDITS` | Monthly credits for the Plus plan. | `1000` |
| `PRO_PLAN_CREDITS` | Monthly credits for the Pro plan. | `10000` |
| `MICRO_DOLLARS_PER_PAGE` | Per-page cost in micro dollars. `1 USD = 1,000,000 micro dollars`. | `1500` |
| `LOW_BALANCE_THRESHOLD` | Low balance threshold. | `10000000` |
| `CREDITS_VALID_DAYS` | Credit validity period, in days. | `365` |
| `PLUS_PLAN_PRICE` | Plus plan price, in cents. | `999` |
| `PRO_PLAN_PRICE` | Pro plan price, in cents. | `2999` |
| `FRONTEND_URL` | Frontend URL used by Stripe Checkout success/cancel callbacks. | `https://knowhere.example.com` |
| `RESEND_TEMPLATE_WELCOME` | Resend welcome email template ID. | `tmpl_...` |
| `RESEND_TEMPLATE_PURCHASE_CONFIRMATION` | Resend purchase confirmation template ID. | `tmpl_...` |
| `RESEND_TEMPLATE_JOB_COMPLETION` | Resend job completion template ID. | `tmpl_...` |
| `RESEND_TEMPLATE_JOB_FAILURE` | Resend job failure template ID. | `tmpl_...` |
| `RESEND_TEMPLATE_WELCOME_ENABLED` | Whether to enable the welcome email template. | `false` |
| `RESEND_TEMPLATE_PURCHASE_CONFIRMATION_ENABLED` | Whether to enable the purchase confirmation email template. | `false` |
| `RESEND_TEMPLATE_JOB_COMPLETION_ENABLED` | Whether to enable the job completion email template. | `false` |
| `RESEND_TEMPLATE_JOB_FAILURE_ENABLED` | Whether to enable the job failure email template. | `false` |

## Rate Limiting and Observability

| Variable | Usage | Example values |
| --- | --- | --- |
| `RATE_LIMIT_ENABLED` | Whether to enable API rate limiting. Disabled by default for self-hosted deployments. | `false` |
| `RATE_LIMIT_WINDOW` | Redis simple rate-limit window, in seconds. | `60` |
| `RATE_LIMIT_MAX_REQUESTS` | Maximum requests within the Redis simple rate-limit window. | `1000` |
| `LOG_LEVEL` | Log level. | `INFO`, `DEBUG` |
| `DEBUG` | API debug mode. | `false` |
| `LOGFIRE_TOKEN` | Logfire tracing token. | `...` |
| `MOESIF_APPLICATION_ID` | Moesif application ID. | `...` |
| `NEXT_PUBLIC_POSTHOG_KEY` | PostHog project key. | `phc_...` |
| `NEXT_PUBLIC_POSTHOG_HOST` | PostHog host. | `https://app.posthog.com` |
| `GA_MEASUREMENT_ID` | Google Analytics measurement ID. Example format: `G-XXXXXXXXXX`. | `G-ABC1234567` |

## Runtime and Self-Hosted Startup Control

| Variable | Usage | Example values |
| --- | --- | --- |
| `ENVIRONMENT` | API runtime environment. Allows `development`, `staging`, and `production`. | `production` |
| `APP_ENV` | Deployment environment marker. Can be empty, `development`, `staging`, or `production`. | `production` |
| `APP_TITLE` | API title. | `Knowhere API` |
| `APP_VERSION` | Application version. The image also injects the build version. | `1.0.0` |
| `APP_DESCRIPTION` | API description. | `Document ingestion, retrieval, and MCP backend` |
| `ALGORITHM` | JWT signing algorithm. | `HS256` |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | API access token validity period, in minutes. | `10080` |
| `API_STANDALONE_MODE_ENABLED` | API-only mode. Combined self-hosted deployments should keep this `false` so the Dashboard initializes user tables. | `false` |
| `NODE_ENV` | Dashboard Node environment. | `production` |
| `DASHBOARD_PORT` | Dashboard internal container port. Usually do not change it. | `3000` |
| `API_PORT` | API internal container port. Usually do not change it. | `5005` |
| `INTERNAL_DASHBOARD_ENDPOINT` | Internal Dashboard URL used by the API. | `http://127.0.0.1:3000` |
| `SELF_HOSTED_SECRETS_PATH` | Directory where generated secrets are stored. | `/data/secrets` |
| `SELF_HOSTED_WAIT_ATTEMPTS` | Maximum attempts while waiting for startup dependencies. | `60` |
| `SELF_HOSTED_WAIT_DELAY_SECONDS` | Retry delay while waiting for startup dependencies, in seconds. | `2` |
| `SELF_HOSTED_INIT_POSTGRES_EXTENSIONS` | Whether startup creates PostgreSQL extensions automatically. | `true` |
| `HTTPS_PROXY` / `HTTP_PROXY` | Outbound proxy for Dashboard auth/email requests and similar calls. | `http://127.0.0.1:7890` |
| `SKIP_ENV_VALIDATION` | Skip Dashboard env schema validation during builds or special debugging. Do not set in production. | `1` |

## Compatibility Fields

These fields are retained for legacy code paths or internal path conventions. Most deployments should not change them.

| Variable | Usage | Example values |
| --- | --- | --- |
| `ALL_DF_COLS` | Legacy dataframe column definition. | `content,path,type,length,keywords,summary,know_id,tokens,connectto,addtime,page_nums` |
| `DEFAULT_FOLDERS` | Legacy default folder list. | `Supplementary_Files,Temporary_Files,templates,images,fragments` |
| `KB_TERM` | Legacy knowledge base data directory name. | `KB_DATA` |
| `KB_VEC_TERM` | Legacy knowledge base vector directory name. | `KB_VECS` |
| `META_PATH` | Legacy metadata path. | `app/core/config/Meta_setting.csv` |
| `CONFIG_PATH` | Legacy config path. | `app/core/config/config.txt` |
| `PATH_IMAGE_PATTERN` | Legacy image path regex. | `.*\.(png|jpe?g|gif)$` |
| `IMG_TBL_PATTERN` | Legacy image/table markdown regex. | `\[(?:images|tables)/[^\]]+\]` |
| `SPLIT_CHAR` | Path separator. | `/` |

## Example: Public Domain Deployment

```bash
DASHBOARD_PUBLIC_URL=https://knowhere.example.com
MINERU_API_KEYS=your-mineru-api-key
DS_KEY=your-deepseek-api-key
```

Restart after changing `.env`:

```bash
docker compose up -d
```
