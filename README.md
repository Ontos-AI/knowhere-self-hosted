# Knowhere Self-Hosted

Knowhere Self-Hosted 用 Docker Compose 在一台机器上启动完整的 Knowhere 服务，包括 Dashboard、API、Worker、PostgreSQL、Redis 和本地 S3 兼容存储。

## 准备工作

- 已安装 Docker 和 Docker Compose。
- 一个 MinerU API Key，用于 PDF 文档解析。
- 一个大模型 API Key：DeepSeek 或阿里云百炼 DashScope 二选一。

## 1. 获取 API Key

### MinerU

进入 MinerU 官网并登录：

```text
https://mineru.net/apiManage/token
```

创建或复制 API Token，后面填入 `MINERU_API_KEYS`。

### DeepSeek

进入 DeepSeek 开放平台并登录：

```text
https://platform.deepseek.com/api_keys
```

创建或复制 API Key，后面填入 `DS_KEY`。

### 阿里云百炼 DashScope

进入阿里云百炼控制台并登录：

```text
https://bailian.console.aliyun.com/?tab=model#/api-key
```

创建或复制 API Key，后面填入 `ALI_API_KEYS`。

## 2. 配置 `.env`

复制默认配置：

```bash
cp .env.defaults .env
```

如果已经有 `.env`，直接编辑现有文件即可。至少填写 MinerU Key 和一个大模型 Key。

使用 DeepSeek：

```bash
MINERU_API_KEYS=your-mineru-api-key
DS_KEY=your-deepseek-api-key
```

或使用阿里云百炼 DashScope：

```bash
MINERU_API_KEYS=your-mineru-api-key
ALI_API_KEYS=your-dashscope-api-key
NORMOL_MODEL=qwen-plus
HIERARCHY_LLM_MODEL=qwen-plus
IMAGE_MODEL=qwen-vl-plus
IMAGE_MODEL_MAX=qwen-vl-plus
```

`MINERU_API_KEYS` 和 `ALI_API_KEYS` 都支持多个 Key，用英文逗号分隔：

```bash
MINERU_API_KEYS=mineru-key-1,mineru-key-2
ALI_API_KEYS=dashscope-key-1,dashscope-key-2
```

本地访问默认不需要修改其他配置。外部访问时，把 `DASHBOARD_PUBLIC_URL` 改成用户浏览器实际打开的地址：

```bash
DASHBOARD_PUBLIC_URL=https://knowhere.example.com
```

如果 `DASHBOARD_PUBLIC_URL` 和浏览器地址不一致，登录或注册可能失败。

## 3. 启动服务

```bash
docker compose up -d
```

打开 Dashboard：

```text
http://localhost:3000/login
```

API 健康检查：

```text
http://localhost:5005/health
```

## 常用命令

查看服务状态：

```bash
docker compose ps
```

查看应用日志：

```bash
docker compose logs -f app
```

停止服务：

```bash
docker compose down
```

更新镜像并重启：

```bash
docker compose pull
docker compose up -d
```

数据库和上传文件会保存在 Docker volumes 中，执行 `docker compose down` 不会删除这些数据。

## 更多配置

除上述必填项以外的配置通常不需要修改。端口、公开 URL、模型、存储、认证、邮件、计费、Webhook、数据库和 Redis 等可选配置见 [docs/configuration.md](docs/configuration.md)。
