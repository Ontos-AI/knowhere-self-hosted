# Knowhere Self-Hosted

Knowhere Self-Hosted lets you run Knowhere on your own computer or server. It includes the web dashboard, API, worker, database, cache, and local file storage in one Docker Compose setup.

## What You Need

- A computer or server with Docker and Docker Compose installed.
- At least one AI provider API key, for example DeepSeek, OpenAI-compatible, Zhipu GLM, Alibaba DashScope, or Volcengine ARK.
- A public URL or server address if other people need to open Knowhere from another machine.

## Quick Start

1. Download this repository.
2. Create your config file:

```bash
cp .env.defaults .env
```

3. Edit `.env` and set the values you need:

```bash
DASHBOARD_PUBLIC_URL=http://localhost:3000
DS_KEY=your-ai-provider-key
```

Knowhere uses `.env.defaults` for built-in defaults and reads `.env` as your override file. `.env.defaults` is also the full settings reference. It includes a default database password for the built-in database, and it generates app secrets on first startup. You do not need to create these values manually. You can change any value in `.env` later and restart with `docker compose up -d`.

4. Start Knowhere:

```bash
docker compose up -d
```

5. Open the dashboard:

```text
http://localhost:3000/login
```

To stop Knowhere:

```bash
docker compose down
```

Your database and uploaded files stay in Docker volumes unless you delete the volumes.

## Public URL

`DASHBOARD_PUBLIC_URL` must match the address people use in their browser.

Use this for local testing:

```bash
DASHBOARD_PUBLIC_URL=http://localhost:3000
```

Use your real domain or server IP for a shared deployment:

```bash
DASHBOARD_PUBLIC_URL=https://knowhere.example.com
```

If this value does not match the browser address, login or signup may fail.

## AI Model Config

Choose your model provider by setting the related key and model names in `.env`.

Common examples:

```bash
DS_KEY=your-deepseek-key
NORMOL_MODEL=deepseek-chat
```

```bash
GPT_API_KEY=your-openai-compatible-key
NORMOL_MODEL=gpt-4o-mini
```

Useful model variables:

| Variable | What It Controls |
| --- | --- |
| `NORMOL_MODEL` | Main text and table understanding model. |
| `HIERARCHY_LLM_MODEL` | Document outline and heading model. |
| `IMAGE_MODEL` | Image understanding model. |
| `IMAGE_MODEL_MAX` | Higher-capacity image understanding model. |
| `EMBEDDING_MODEL` | Embedding model for search and retrieval. |

## Ports

Default ports:

| Service | URL |
| --- | --- |
| Dashboard | `http://localhost:3000` |
| API health check | `http://localhost:5005/health` |

To use different host ports:

```bash
DASHBOARD_HOST_PORT=8080
API_HOST_PORT=5005
```

Then set `DASHBOARD_PUBLIC_URL` to the address users will open, for example `http://localhost:8080`.

## Updating

Pull the latest image and restart:

```bash
docker compose pull
docker compose up -d
```

## China Registry

For users in China, use the Aliyun Container Registry mirror image:

```bash
KNOWHERE_IMAGE=knowhere-registry.cn-shenzhen.cr.aliyuncs.com/knowhere/knowhere:latest
```

Then pull and start normally:

```bash
docker compose pull
docker compose up -d
```

Release images are published to both `ghcr.io/ontos-ai/knowhere` and `knowhere-registry.cn-shenzhen.cr.aliyuncs.com/knowhere/knowhere`. Maintainers must configure the GitHub Actions secrets `ALIYUN_ACR_USERNAME` and `ALIYUN_ACR_PASSWORD` before running the publish workflow.

## Troubleshooting

Check whether the services are running:

```bash
docker compose ps
```

View app logs:

```bash
docker compose logs -f app
```

Restart everything:

```bash
docker compose down
docker compose up -d
```

If login or signup says the origin is invalid, check that `DASHBOARD_PUBLIC_URL` exactly matches the URL in your browser.
