# Knowhere Self-Hosted

English | [中文](README.zh-CN.md)

Knowhere Self-Hosted runs the full Knowhere stack with Docker Compose on one machine: Dashboard, API, Worker, PostgreSQL, Redis, and local S3-compatible storage.

## Background

This repository packages Knowhere for self-hosted deployments. If you want to use or study the SaaS/API version, see [Ontos-AI/knowhere-api](https://github.com/Ontos-AI/knowhere-api).

## Requirements

- Docker and Docker Compose.
- A MinerU API key for PDF parsing.
- One LLM provider API key: DeepSeek or Alibaba Cloud Model Studio DashScope.

## 1. Prepare API Keys

Use the providers' official websites to create or manage the required keys:

- MinerU: `https://mineru.net/`
- DeepSeek: `https://platform.deepseek.com/`
- Alibaba Cloud Model Studio DashScope: `https://bailian.console.aliyun.com/`

## 2. Configure `.env`

Copy the default configuration:

```bash
cp .env.defaults .env
```

If `.env` already exists, edit the existing file. At minimum, set the MinerU key and one LLM provider key.

Use DeepSeek:

```bash
MINERU_API_KEYS=your-mineru-api-key
DS_KEY=your-deepseek-api-key
```

Or use Alibaba Cloud Model Studio DashScope:

```bash
MINERU_API_KEYS=your-mineru-api-key
ALI_API_KEYS=your-dashscope-api-key
NORMOL_MODEL=qwen-plus
HIERARCHY_LLM_MODEL=qwen-plus
IMAGE_MODEL=qwen-vl-plus
IMAGE_MODEL_MAX=qwen-vl-plus
```

`MINERU_API_KEYS` and `ALI_API_KEYS` support multiple keys separated by commas:

```bash
MINERU_API_KEYS=mineru-key-1,mineru-key-2
ALI_API_KEYS=dashscope-key-1,dashscope-key-2
```

For local access, no other settings are required. For external access, set `DASHBOARD_PUBLIC_URL` to the exact URL users open in their browser:

```bash
DASHBOARD_PUBLIC_URL=https://knowhere.example.com
```

If `DASHBOARD_PUBLIC_URL` does not match the browser URL, login or signup may fail.

## 3. Start Knowhere

```bash
docker compose up -d
```

Open the Dashboard:

```text
http://localhost:3000/login
```

API health check:

```text
http://localhost:5005/health
```

## API Usage

Use an official SDK to call the API:

- Node.js SDK: [Ontos-AI/knowhere-node-sdk](https://github.com/Ontos-AI/knowhere-node-sdk)
- Python SDK: [Ontos-AI/knowhere-python-sdk](https://github.com/Ontos-AI/knowhere-python-sdk)

## Common Commands

Check service status:

```bash
docker compose ps
```

View application logs:

```bash
docker compose logs -f app
```

Stop the stack:

```bash
docker compose down
```

Update images and restart:

```bash
docker compose pull
docker compose up -d
```

Database data and uploaded files remain in Docker volumes after `docker compose down`.

## More Configuration

Most deployments do not need additional settings. Optional ports, public URLs, model choices, storage, auth, email, billing, webhooks, database, and Redis settings are documented in [docs/configuration.md](docs/configuration.md).
