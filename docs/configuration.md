# Knowhere Self-Hosted 配置参考

本文档记录启动服务以外的可选配置。普通本地部署只需要 README 中的 `MINERU_API_KEYS` 和 `DS_KEY` 或 `ALI_API_KEYS`。

Docker Compose 会先读取 `.env.defaults`，再读取 `.env`。`.env.defaults` 是内置默认值参考；实际部署时请新建一个小的 `.env`，只写需要覆盖的值，不要把真实密钥提交到 Git。

## 基础访问地址和镜像

| 变量 | 用途 | 示例值 |
| --- | --- | --- |
| `DASHBOARD_PUBLIC_URL` | 用户浏览器访问 Dashboard 的公开地址，也用于登录、注册和回调校验。 | `http://localhost:3000`、`https://knowhere.example.com` |
| `DASHBOARD_HOST_PORT` | Dashboard 映射到宿主机的端口。 | `3000`、`8080` |
| `API_HOST_PORT` | API 映射到宿主机的端口。 | `5005` |
| `POSTGRES_HOST_PORT` | PostgreSQL 映射到宿主机的端口。 | `5432` |
| `REDIS_HOST_PORT` | Redis 映射到宿主机的端口。 | `6379` |
| `LOCALSTACK_HOST_PORT` | LocalStack S3 兼容存储映射到宿主机的端口。 | `4566` |
| `KNOWHERE_IMAGE` | Knowhere 自托管镜像。 | `ghcr.io/ontos-ai/knowhere:latest` |

国内网络可使用阿里云镜像：

```bash
KNOWHERE_IMAGE=knowhere-registry.cn-shenzhen.cr.aliyuncs.com/knowhere/knowhere:latest
```

## 必填外部服务

| 变量 | 用途 | 示例值 |
| --- | --- | --- |
| `MINERU_API_KEYS` | MinerU API Key 池，用于 PDF 解析。支持 JSON 数组、逗号分隔或换行分隔，条目也可写成 `token_id=api_key`。 | `mineru-key-1,mineru-key-2` |
| `DS_KEY` | DeepSeek API Key。使用 DeepSeek 作为文本模型时填写。 | `sk-...` |
| `ALI_API_KEYS` | 阿里云百炼 DashScope API Key 池。使用 Qwen 模型时填写，格式同 `MINERU_API_KEYS`。 | `sk-...` |

Key 请从各服务商官网获取：

```text
MinerU: https://mineru.net/
DeepSeek: https://platform.deepseek.com/
阿里云百炼 DashScope: https://bailian.console.aliyun.com/
```

## AI 模型和供应商

| 变量 | 用途 | 示例值 |
| --- | --- | --- |
| `DS_URL` | DeepSeek OpenAI-compatible base URL。 | `https://api.deepseek.com/v1` |
| `ALI_URL` | DashScope OpenAI-compatible base URL。 | `https://dashscope.aliyuncs.com/compatible-mode/v1` |
| `GPT_API_KEY` | OpenAI 或其他兼容服务的 Key。当前默认 URL 路由仍以模型名判断，使用前请确认镜像支持对应 provider。 | `sk-...` |
| `GLM_API_KEY` | 智谱 GLM API Key。 | `...` |
| `GLM_URL` | 智谱 GLM base URL。 | `https://open.bigmodel.cn/api/paas/v4` |
| `ARK_API_KEY` | 火山方舟 API Key。 | `...` |
| `ARK_URL` | 火山方舟 chat completions URL。 | `https://ark.cn-beijing.volces.com/api/v3/chat/completions` |
| `NORMOL_MODEL` | 主要文本、表格理解和摘要模型。 | `deepseek-chat`、`qwen-plus` |
| `HIERARCHY_LLM_MODEL` | 文档标题层级、目录识别模型；为空时回退到 `NORMOL_MODEL`。 | `deepseek-chat`、`qwen-plus` |
| `IMAGE_MODEL` | 图片摘要、图集和 OCR 相关的默认视觉模型。 | `qwen-vl-plus` |
| `IMAGE_MODEL_MAX` | 更高能力的图片问答和 OCR 模型。 | `qwen-vl-plus` |
| `EMBEDDING_MODEL` | 检索使用的 embedding 模型名。 | `text-embedding-v4` |
| `OPENAI_CLIENT_TIMEOUT` | OpenAI-compatible 客户端超时时间，单位秒。 | `300` |
| `LLM_MOCK_ENABLED` | 是否用 mock 响应短路 LLM 调用，主要用于测试。 | `false` |
| `HEADING_LLM_MAX_CONCURRENT` | 标题识别并发 LLM 调用上限。 | `8` |
| `SUMMARY_LLM_MAX_CONCURRENT` | 摘要、图片、表格 LLM 调用并发上限。 | `8` |
| `ALI_TOKEN_RPM_LIMIT` | 每个 DashScope Key 的每分钟请求上限。 | `300` |
| `ALI_TOKEN_DAILY_LIMIT` | 每个 DashScope Key 的每日请求上限。 | `10000` |
| `ALI_TOKEN_COOLDOWN_SECONDS` | DashScope Key 触发 429 后冷却秒数。 | `60` |
| `ALI_INLINE_MAX_RETRIES` | DashScope token 轮换重试次数。 | `3` |
| `ALI_SDK_MAX_RETRIES` | 单个 DashScope token 内部 SDK 重试次数。 | `3` |

DeepSeek 示例：

```bash
DS_KEY=your-deepseek-api-key
NORMOL_MODEL=deepseek-chat
HIERARCHY_LLM_MODEL=deepseek-chat
```

阿里云百炼示例：

```bash
ALI_API_KEYS=your-dashscope-api-key
NORMOL_MODEL=qwen-plus
HIERARCHY_LLM_MODEL=qwen-plus
IMAGE_MODEL=qwen-vl-plus
IMAGE_MODEL_MAX=qwen-vl-plus
EMBEDDING_MODEL=text-embedding-v4
```

## MinerU 和可选解析服务

| 变量 | 用途 | 示例值 |
| --- | --- | --- |
| `MINERU_URL` | MinerU API base URL。 | `https://mineru.net/api/v4` |
| `FORCE_MINERU_UPLOAD_ENABLED` | 强制使用 MinerU 直传模式，不使用可复用 S3 URL。 | `true` |
| `MINERU_TOKEN_RPM_LIMIT` | 每个 MinerU Key 的每分钟请求上限。 | `300` |
| `MINERU_TOKEN_DAILY_LIMIT` | 每个 MinerU Key 的每日请求上限。 | `10000` |
| `MINERU_TOKEN_COOLDOWN_SECONDS` | MinerU Key 触发限流后的冷却秒数。 | `60` |
| `MINERU_API_TIMEOUT` | MinerU API 请求超时，单位秒。 | `60` |
| `MINERU_UPLOAD_CONNECT_TIMEOUT` | MinerU 文件上传连接超时，单位秒。 | `10` |
| `MINERU_UPLOAD_READ_TIMEOUT` | MinerU 文件上传读取超时，单位秒。 | `600` |
| `MINERU_RATE_LIMIT_MAX_RETRY_AFTER` | MinerU 429 retry-after 最大等待秒数。 | `60` |
| `MINERU_POOL_MAXSIZE` | MinerU HTTP 连接池大小。 | `50` |
| `MINERU_UPLOAD_RETRY_TOTAL` | MinerU 上传瞬时失败重试次数。 | `3` |
| `MINERU_UPLOAD_RETRY_BACKOFF_FACTOR` | MinerU 上传重试退避系数。 | `2` |
| `MINERU_URL_MODE_PRESIGN_EXPIRY` | MinerU URL 模式下预签名 URL 有效期，单位秒。 | `3600` |
| `ILOVEAPI_PUBLIC_KEY` | iLoveAPI public key，用于 PPTX 转 PDF。 | `project_public_key` |
| `ILOVEAPI_SECRET_KEY` | iLoveAPI secret key。 | `project_secret_key` |
| `ILOVEAPI_KEYS` | iLoveAPI 项目池，JSON 数组，每项包含 `public_key` 和 `secret_key`。 | `[{"public_key":"...","secret_key":"..."}]` |
| `ILOVEAPI_BASE_URL` | iLoveAPI base URL。 | `https://api.ilovepdf.com/v1` |
| `ILOVEAPI_TIMEOUT` | iLoveAPI 请求超时，单位秒。 | `120` |
| `ILOVEAPI_TOKEN_RPM_LIMIT` | 每个 iLoveAPI 项目的分钟请求上限。 | `25` |
| `ILOVEAPI_TOKEN_DAILY_LIMIT` | 每个 iLoveAPI 项目的每日文件上限。 | `250` |
| `ILOVEAPI_MAX_CONCURRENT` | iLoveAPI 并发转换上限。 | `5` |

## Dashboard、认证和品牌

| 变量 | 用途 | 示例值 |
| --- | --- | --- |
| `NEXT_PUBLIC_APP_URL` | Dashboard 公开地址；未设置时由 `DASHBOARD_PUBLIC_URL` 派生。 | `https://knowhere.example.com` |
| `BETTER_AUTH_URL` | Better Auth 回调和可信来源地址；未设置时由 `NEXT_PUBLIC_APP_URL` 派生。 | `https://knowhere.example.com` |
| `NEXT_PUBLIC_API_URL` | Dashboard 代理到 API 的 base URL。单容器默认用本机 API。 | `http://127.0.0.1:5005/api` |
| `NEXT_PUBLIC_AUTH_BASE_URL` | Better Auth 路由前缀。 | `/api/auth` |
| `PASSWORD_LOGIN_ENABLED` | 是否在登录页显示密码登录入口。自托管默认开启。 | `true` |
| `BETTER_AUTH_SECRET` | Better Auth 密钥；未设置时首次启动自动生成并保存到 volume。 | `a-random-secret-at-least-32-chars` |
| `SECRET_KEY` | API JWT 密钥；未设置时首次启动自动生成并保存到 volume。 | `a-random-secret` |
| `USERS_VERIFY_TOKEN_SECRET` | 邮箱验证 token 密钥；未设置时自动生成。 | `a-random-secret` |
| `USERS_RESET_PASSWORD_TOKEN_SECRET` | 重置密码 token 密钥；未设置时自动生成。 | `a-random-secret` |
| `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` | GitHub OAuth 登录。 | `...` |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | Google OAuth 登录。 | `...` |
| `APPLE_CLIENT_ID` / `APPLE_CLIENT_SECRET` | 预留 Apple OAuth 配置。 | `...` |
| `RESEND_API_KEY` | Resend 邮件服务 Key，用于 magic link 和重置密码邮件。 | `re_...` |
| `RESEND_FROM` | Dashboard 认证邮件发件人。 | `Knowhere <noreply@example.com>` |
| `RESEND_FROM_EMAIL` | API 邮件发件邮箱。 | `noreply@example.com` |
| `RESEND_FROM_NAME` | API 邮件发件名称。 | `Knowhere` |
| `RESEND_MAX_RETRIES` | API 发送 Resend 邮件的最大重试次数。 | `3` |
| `RESEND_RETRY_DELAY` | API 发送 Resend 邮件的重试间隔，单位秒。 | `1.0` |
| `COMPANY_NAME` | Dashboard 运行时品牌名称。 | `Knowhere AI` |
| `SIMPLE_COMPANY_NAME` | Dashboard 运行时品牌简称。 | `Knowhere` |
| `ICP_NUMBER` | ICP 备案号，填写后页脚显示。 | `沪ICP备...号` |
| `ICP_URL` | ICP 备案链接。 | `https://beian.miit.gov.cn/` |
| `DEV_EXTERNAL_API_AUTHORIZATION` | Dashboard 开发环境转发 API 请求时使用的固定 `Authorization` 头。生产环境不要设置。 | `Bearer dev-token` |

## 数据库

| 变量 | 用途 | 示例值 |
| --- | --- | --- |
| `POSTGRES_PASSWORD` | 内置 PostgreSQL 的 root 密码。 | `root123` |
| `API_DATABASE_URL` | API 使用的 PostgreSQL async URL；默认由内置 PostgreSQL 配置派生。 | `postgresql+asyncpg://root:root123@postgres:5432/Knowhere` |
| `DASHBOARD_DATABASE_URL` | Dashboard 使用的 PostgreSQL URL；默认由内置 PostgreSQL 配置派生。 | `postgresql://root:root123@postgres:5432/Knowhere` |
| `DATABASE_URL` | 上游 API/Dashboard 开发模式使用；自托管通常不用直接设置。 | `postgresql+asyncpg://...` |
| `DB_SSL_MODE` | PostgreSQL SSL 模式。 | `disable`、`require`、`verify-full` |
| `DB_SSL_CERT` | PostgreSQL 客户端证书路径。 | `/path/to/client-cert.pem` |
| `DB_SSL_KEY` | PostgreSQL 客户端私钥路径。 | `/path/to/client-key.pem` |
| `DB_SSL_ROOT_CERT` | PostgreSQL CA 证书路径。 | `/path/to/ca.pem` |
| `UNSAFE_DB_SSL_ENABLED` | Dashboard 数据库 SSL 开关，供部署环境兼容使用。 | `true` |
| `DB_POOL_SIZE` | API 数据库连接池大小。 | `20` |
| `DB_MAX_OVERFLOW` | API 数据库连接池最大溢出连接数。 | `30` |
| `DB_POOL_RECYCLE` | 数据库连接回收间隔，单位秒。 | `1800` |
| `DB_POOL_TIMEOUT` | 数据库连接获取超时，单位秒。 | `30` |
| `DB_SYNC_POOL_SIZE` | Worker 同步数据库连接池大小。 | `5` |
| `DB_SYNC_MAX_OVERFLOW` | Worker 同步数据库连接池最大溢出连接数。 | `5` |
| `DB_USE_NULL_POOL` | 是否禁用 API async SQLAlchemy 连接池。 | `false` |

## Redis、Celery 和 Worker

| 变量 | 用途 | 示例值 |
| --- | --- | --- |
| `REDIS_HOST` | Redis 主机。 | `redis` |
| `REDIS_PORT` | Redis 端口。 | `6379` |
| `REDIS_PASSWORD` | Redis 密码。 | `` |
| `REDIS_DATABASE` | Redis database index。 | `0` |
| `REDIS_SSL` | 是否使用 rediss/TLS。 | `false` |
| `REDIS_MAX_CONNECTIONS` | API Redis 连接池最大连接数。 | `20` |
| `REDIS_RETRY_ON_TIMEOUT` | Redis timeout 时是否重试。 | `true` |
| `REDIS_SOCKET_TIMEOUT` | Redis socket 超时，单位秒。 | `5.0` |
| `REDIS_SOCKET_CONNECT_TIMEOUT` | Redis 连接超时，单位秒。 | `5.0` |
| `REDIS_MAX_RETRIES` | Redis 最大重试次数。 | `3` |
| `REDIS_RETRY_DELAY` | Redis 重试间隔，单位秒。 | `1.0` |
| `REDIS_KEY_PREFIX` | Redis key 前缀。 | `knowhere-api` |
| `REDIS_DEFAULT_TTL` | Redis 默认 TTL，单位秒。 | `86400` |
| `REDIS_SYNC_MAX_CONNECTIONS` | Worker 同步 Redis 连接池最大连接数。 | `50` |
| `REDIS_SYNC_POOL_TIMEOUT` | Worker 同步 Redis 连接池等待超时，单位秒。 | `5` |
| `CELERY_REDIS_URL` | Celery broker/result backend/RedBeat Redis URL；默认由 `REDIS_*` 派生。 | `redis://redis:6379/0` |
| `BROKER_POOL_LIMIT` | Celery broker 连接池上限。 | `10` |
| `WORKER_CONCURRENCY` | Worker gevent 并发数。 | `50` |
| `KB_TASK_MAX_RETRIES` | 知识库任务最大重试次数。 | `2` |
| `KB_TASK_RETRY_COUNTDOWN` | 知识库任务重试间隔，单位秒。 | `120` |
| `PYMUPDF_MAX_CONCURRENT` | 单个 Pod 内 PyMuPDF 子进程并发上限。 | `2` |
| `WORKER_HEARTBEAT_FILE` | Worker heartbeat 文件路径。 | `/tmp/knowhere-worker-heartbeat.json` |
| `WORKER_HEARTBEAT_INTERVAL_SECONDS` | Worker heartbeat 写入间隔。 | `5` |
| `WORKER_HEARTBEAT_STALE_AFTER_SECONDS` | Worker heartbeat 判定过期时间。 | `45` |

## 本地 S3 兼容存储

| 变量 | 用途 | 示例值 |
| --- | --- | --- |
| `S3_TYPE` | 存储后端类型。 | `s3`、`oss`、`minio` |
| `S3_BUCKET_NAME` | 默认上传 bucket。 | `knowhere-uploads` |
| `S3_UPLOADS_BUCKET` | 上传文件 bucket；未设置时由 `S3_BUCKET_NAME` 派生。 | `knowhere-uploads` |
| `S3_RESULTS_BUCKET` | 处理结果 bucket。 | `knowhere-results` |
| `S3_ACCESS_KEY_ID` | S3/OSS/MinIO access key。LocalStack 默认 `test`。 | `test` |
| `S3_SECRET_ACCESS_KEY` | S3/OSS/MinIO secret key。LocalStack 默认 `test`。 | `test` |
| `S3_ENDPOINT_URL` | S3 兼容服务 endpoint。 | `http://localhost.localstack.cloud:4566` |
| `S3_PRIVATE_DOMAIN` | 内部访问对象的 domain。 | `http://localhost.localstack.cloud:4566` |
| `S3_REGION` | S3 region。 | `us-west-1` |
| `S3_USE_SSL` | 是否用 SSL 连接存储服务。 | `false` |
| `S3_ADDRESSING_STYLE` | S3 地址风格。 | `path`、`virtual`、`auto` |
| `S3_TEMP_PATH` | S3 临时文件路径。 | `/tmp/knowhere` |
| `S3_WEBHOOK_AUTH_TOKEN` | S3 事件 webhook 鉴权 token。 | `change-me-storage-webhook-token` |
| `SNS_SIGNATURE_VERIFICATION` | 是否校验 SNS 签名。LocalStack 默认关闭。 | `false` |
| `OSS_ENDPOINT` | 阿里云 OSS endpoint；`S3_TYPE=oss` 时需要。 | `oss-cn-hangzhou.aliyuncs.com` |
| `OSS_EVENT_CALLBACK_KEY` | OSS 事件回调签名 key。 | `...` |
| `OSS_EVENT_VERIFY_SIGNATURE` | 是否校验 OSS 事件签名。 | `true` |
| `SELF_HOSTED_CREATE_STORAGE_BUCKETS` | 启动时自动创建 bucket。 | `true` |
| `SELF_HOSTED_CONFIGURE_STORAGE_EVENTS` | 启动时自动配置上传事件。 | `true` |
| `SELF_HOSTED_S3_EVENT_TOPIC_NAME` | LocalStack SNS topic 名称。 | `knowhere-s3-upload-events` |
| `SELF_HOSTED_S3_EVENT_WEBHOOK_URL` | S3 上传事件回调到 API 的 URL。 | `http://app:5005/v1/internal/s3-events` |
| `SELF_HOSTED_STORAGE_CORS_ALLOWED_ORIGINS` | Bucket CORS 允许来源，逗号分隔；为空时自动包含本地 Dashboard/API 地址。 | `https://knowhere.example.com` |
| `SELF_HOSTED_AWS_ENDPOINT_URL` | 自托管存储初始化脚本使用的 AWS endpoint；为空时使用 `S3_ENDPOINT_URL`。 | `http://localstack:4566` |

## 文件处理和检索

| 变量 | 用途 | 示例值 |
| --- | --- | --- |
| `SUPPORTED_EXTENSIONS` | 允许上传的文件扩展名，逗号分隔。 | `.doc,.docx,.pdf,.txt,.xls,.xlsx,.csv,.pptx,.jpg,.jpeg,.png,.md` |
| `MAX_FILE_SIZE` | 最大文件大小，单位字节。 | `104857600` |
| `MAX_IMAGE_SIZE` | 最大图片大小，单位字节。 | `10485760` |
| `USERS_DATA_PATH` | API 和 Worker 共享用户数据目录，必须是绝对路径。 | `/data/users` |
| `TMP_PATH` | 应用临时目录。 | `/tmp/knowhere` |
| `FONT_PATH` | 字体文件路径。 | `/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf` |
| `CHROMEDRIVER_PATH` | ChromeDriver 路径。 | `/usr/bin/chromedriver` |
| `MIN_CONFIDENCE_THRESHOLD` | 解析置信度阈值。 | `0.05` |
| `HIGH_IOU_THRESHOLD` | 高 IoU 阈值。 | `0.9` |
| `DEFAULT_EMBEDDING_DIM` | 默认 embedding 维度。 | `1024` |
| `DEFAULT_TOP_K` | 默认检索 top-k。 | `5` |
| `DEFAULT_BATCH_SIZE` | 默认批大小。 | `32` |
| `DEFAULT_EPOCHS` | 默认训练 epoch 数。 | `3` |
| `DEFAULT_THRESHOLD` | 默认阈值。 | `0.5` |
| `JOB_WAITING_EXPIRE_SECONDS` | Job 在 pending/waiting-file 状态的最大停留时间，也控制预签名 S3 URL 有效期。 | `7200` |
| `JOB_PROCESSING_EXPIRE_SECONDS` | Job 在 running/converting 状态的最大停留时间。 | `14400` |
| `KB_LAYOUT_LLM_COMPACT_INPUT` | 标题层级识别时是否压缩正文行以减少 prompt。 | `true` |
| `RETRIEVAL_AGENTIC_ENABLED` | 是否启用 agentic retrieval 路由。 | `false` |
| `RETRIEVAL_AGENTIC_MAX_STEPS` | Agentic retrieval 最大步骤数。 | `10` |
| `RETRIEVAL_AGENTIC_MAX_DOCS` | Agentic retrieval 最大文档数；`0` 表示不限制。 | `0` |
| `RETRIEVAL_AGENTIC_MAX_PATH_EXPANSIONS` | Agentic retrieval 最大路径扩展次数。 | `2` |
| `RETRIEVAL_AGENTIC_MAX_DOC_RETRIES` | Agentic retrieval 单文档最大重试次数。 | `2` |
| `RETRIEVAL_AGENTIC_LATENCY_BUDGET_MS` | Agentic retrieval 延迟预算，单位毫秒。 | `12000` |
| `RETRIEVAL_AGENTIC_MIN_EVIDENCE_PATHS` | Agentic retrieval 最少证据路径数。 | `1` |
| `RETRIEVAL_AGENTIC_TRACE_ENABLED` | 是否记录 agentic retrieval trace。 | `true` |
| `LOCAL_DEBUG` | 本地调试开关；部分解析流程会保存中间文件或跳过 Redis 状态写入。 | `0`、`1` |
| `KNOWHERE_HOME` | 旧版知识图谱和 MCP 自动注册使用的本地根目录。 | `~/.knowhere` |
| `KNOWHERE_API_KEY` | 自动注册 MCP server 时写入客户端配置的 Knowhere API Key。 | `kh_...` |

## Webhook、QStash 和异步回调

| 变量 | 用途 | 示例值 |
| --- | --- | --- |
| `WEBHOOK_SIGNING_SECRET` | 出站 webhook 签名密钥。 | `your-webhook-secret` |
| `WEBHOOK_MASTER_KEY` | Webhook secret 加密主密钥。 | `your-master-key` |
| `QSTASH_TOKEN` | Upstash QStash API token，用于异步 webhook 投递。 | `qstash_...` |
| `QSTASH_CALLBACK_BASE_URL` | QStash 回调的公开 API base URL。 | `https://api.example.com/api/v1` |
| `QSTASH_MAX_RETRIES` | QStash 最大投递重试次数。 | `5` |
| `QSTASH_CURRENT_SIGNING_KEY` | QStash 当前签名 key。 | `sig_...` |
| `QSTASH_NEXT_SIGNING_KEY` | QStash 下一签名 key，用于轮换。 | `sig_...` |

## 计费、额度和邮件模板

自托管默认关闭计费：`BILLING_ENABLED=false`。只有在 Stripe 和相关 API 端点都准备好时才开启。

| 变量 | 用途 | 示例值 |
| --- | --- | --- |
| `BILLING_ENABLED` | 是否启用 Stripe/credits 计费。 | `false` |
| `STRIPE_SECRET_KEY` | Stripe secret key。 | `sk_live_...` |
| `STRIPE_PUBLISHABLE_KEY` | Stripe publishable key。 | `pk_live_...` |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook secret。 | `whsec_...` |
| `FREE_PLAN_INITIAL_CREDITS` | 新用户初始 credits。 | `5` |
| `FREE_PLAN_CREDITS` | Free plan 每月 credits。 | `100` |
| `PLUS_PLAN_CREDITS` | Plus plan 每月 credits。 | `1000` |
| `PRO_PLAN_CREDITS` | Pro plan 每月 credits。 | `10000` |
| `MICRO_DOLLARS_PER_PAGE` | 每页微美元成本，`1 USD = 1,000,000 micro dollars`。 | `1500` |
| `LOW_BALANCE_THRESHOLD` | 低余额阈值。 | `10000000` |
| `CREDITS_VALID_DAYS` | credits 有效天数。 | `365` |
| `PLUS_PLAN_PRICE` | Plus plan 价格，单位美分。 | `999` |
| `PRO_PLAN_PRICE` | Pro plan 价格，单位美分。 | `2999` |
| `FRONTEND_URL` | Stripe Checkout 成功/取消回调使用的前端地址。 | `https://knowhere.example.com` |
| `RESEND_TEMPLATE_WELCOME` | Resend 欢迎邮件模板 ID。 | `tmpl_...` |
| `RESEND_TEMPLATE_PURCHASE_CONFIRMATION` | Resend 购买确认模板 ID。 | `tmpl_...` |
| `RESEND_TEMPLATE_JOB_COMPLETION` | Resend Job 完成模板 ID。 | `tmpl_...` |
| `RESEND_TEMPLATE_JOB_FAILURE` | Resend Job 失败模板 ID。 | `tmpl_...` |
| `RESEND_TEMPLATE_WELCOME_ENABLED` | 是否启用欢迎邮件模板。 | `false` |
| `RESEND_TEMPLATE_PURCHASE_CONFIRMATION_ENABLED` | 是否启用购买确认邮件模板。 | `false` |
| `RESEND_TEMPLATE_JOB_COMPLETION_ENABLED` | 是否启用 Job 完成邮件模板。 | `false` |
| `RESEND_TEMPLATE_JOB_FAILURE_ENABLED` | 是否启用 Job 失败邮件模板。 | `false` |

## 限流和观测

| 变量 | 用途 | 示例值 |
| --- | --- | --- |
| `RATE_LIMIT_ENABLED` | 是否启用 API 限流。自托管默认关闭。 | `false` |
| `RATE_LIMIT_WINDOW` | Redis 简单限流窗口，单位秒。 | `60` |
| `RATE_LIMIT_MAX_REQUESTS` | Redis 简单限流窗口内最大请求数。 | `1000` |
| `LOG_LEVEL` | 日志级别。 | `INFO`、`DEBUG` |
| `DEBUG` | API debug 模式。 | `false` |
| `LOGFIRE_TOKEN` | Logfire tracing token。 | `...` |
| `MOESIF_APPLICATION_ID` | Moesif application ID。 | `...` |
| `NEXT_PUBLIC_POSTHOG_KEY` | PostHog project key。 | `phc_...` |
| `NEXT_PUBLIC_POSTHOG_HOST` | PostHog host。 | `https://app.posthog.com` |
| `GA_MEASUREMENT_ID` | Google Analytics measurement ID，格式如 `G-XXXXXXXXXX`。 | `G-ABC1234567` |

## 运行时和自托管启动控制

| 变量 | 用途 | 示例值 |
| --- | --- | --- |
| `ENVIRONMENT` | API 运行环境，允许 `development`、`staging`、`production`。 | `production` |
| `APP_ENV` | 部署环境标识，可为空或 `development`、`staging`、`production`。 | `production` |
| `APP_TITLE` | API 标题。 | `Knowhere API` |
| `APP_VERSION` | 应用版本；镜像也会注入构建版本。 | `1.0.0` |
| `APP_DESCRIPTION` | API 描述。 | `Document ingestion, retrieval, and MCP backend` |
| `ALGORITHM` | JWT 签名算法。 | `HS256` |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | API access token 有效期，单位分钟。 | `10080` |
| `API_STANDALONE_MODE_ENABLED` | API-only 模式。组合自托管应保持 `false`，由 Dashboard 初始化用户表。 | `false` |
| `NODE_ENV` | Dashboard Node 环境。 | `production` |
| `DASHBOARD_PORT` | 容器内部 Dashboard 端口。通常不要改。 | `3000` |
| `API_PORT` | 容器内部 API 端口。通常不要改。 | `5005` |
| `INTERNAL_DASHBOARD_ENDPOINT` | API 内部访问 Dashboard 的地址。 | `http://127.0.0.1:3000` |
| `SELF_HOSTED_SECRETS_PATH` | 自动生成密钥的保存目录。 | `/data/secrets` |
| `SELF_HOSTED_WAIT_ATTEMPTS` | 启动时等待依赖的最大尝试次数。 | `60` |
| `SELF_HOSTED_WAIT_DELAY_SECONDS` | 启动时等待依赖的重试间隔。 | `2` |
| `SELF_HOSTED_INIT_POSTGRES_EXTENSIONS` | 启动时自动创建 PostgreSQL 扩展。 | `true` |
| `HTTPS_PROXY` / `HTTP_PROXY` | Dashboard auth/email 等出站请求代理。 | `http://127.0.0.1:7890` |
| `SKIP_ENV_VALIDATION` | Dashboard 构建或特殊调试时跳过 env schema 校验。生产运行不要设置。 | `1` |

## 兼容字段

这些字段保留给旧代码路径或内部路径约定，通常不要修改。

| 变量 | 用途 | 示例值 |
| --- | --- | --- |
| `ALL_DF_COLS` | 旧版 dataframe 列定义。 | `content,path,type,length,keywords,summary,know_id,tokens,connectto,addtime,page_nums` |
| `DEFAULT_FOLDERS` | 旧版默认目录列表。 | `Supplementary_Files,Temporary_Files,templates,images,fragments` |
| `KB_TERM` | 旧版知识库数据目录名。 | `KB_DATA` |
| `KB_VEC_TERM` | 旧版知识库向量目录名。 | `KB_VECS` |
| `META_PATH` | 旧版 metadata 路径。 | `app/core/config/Meta_setting.csv` |
| `CONFIG_PATH` | 旧版 config 路径。 | `app/core/config/config.txt` |
| `PATH_IMAGE_PATTERN` | 旧版图片路径正则。 | `.*\.(png|jpe?g|gif)$` |
| `IMG_TBL_PATTERN` | 旧版图片/表格 markdown 正则。 | `\[(?:images|tables)/[^\]]+\]` |
| `SPLIT_CHAR` | 路径分隔符。 | `/` |

## 示例：公开域名部署

```bash
DASHBOARD_PUBLIC_URL=https://knowhere.example.com
MINERU_API_KEYS=your-mineru-api-key
DS_KEY=your-deepseek-api-key
```

修改后重启：

```bash
docker compose up -d
```
