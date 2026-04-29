# Knowhere Self-Hosted

[English](README.md) | 中文

Knowhere Self-Hosted 用于 Knowhere 的自托管部署。如果你想使用或了解 SaaS/API 版本，请查看 [Ontos-AI/knowhere-api](https://github.com/Ontos-AI/knowhere-api)。

## 准备工作

- Docker 和 Docker Compose。
- MinerU API Key，用于 PDF 文档基础解析。
- 大模型 API Key：DeepSeek 或阿里云百炼 DashScope。

## 1. 准备 API Key

- [MinerU](https://mineru.net/)
- [DeepSeek](https://platform.deepseek.com/)
- [阿里云百炼 DashScope](https://bailian.console.aliyun.com/)

## 2. 配置 `.env`

新建一个 `.env` 文件。

使用 DeepSeek：

```bash
MINERU_API_KEYS=your-mineru-api-key
DS_KEY=your-deepseek-api-key
```

使用阿里云百炼 DashScope：

```bash
MINERU_API_KEYS=your-mineru-api-key
ALI_API_KEYS=your-dashscope-api-key
NORMOL_MODEL=qwen-plus
HIERARCHY_LLM_MODEL=qwen-plus
IMAGE_MODEL=qwen-vl-plus
IMAGE_MODEL_MAX=qwen-vl-plus
```

`MINERU_API_KEYS` 和 `ALI_API_KEYS` 都支持多个 Key，用英文逗号分隔。多个 Key 不是必需的；它们会组成一个 Key 池，当某个 Key 触发限流时，Knowhere 可以轮换使用其他 Key。

```bash
MINERU_API_KEYS=mineru-key-1,mineru-key-2
ALI_API_KEYS=dashscope-key-1,dashscope-key-2
```

本地访问默认不需要修改其他配置。宿主机端口默认只绑定到 `127.0.0.1`。

如果通过本机反向代理对外访问，保持默认绑定即可，同时把 `DASHBOARD_PUBLIC_URL` 改成用户浏览器实际打开的地址：

```bash
DASHBOARD_PUBLIC_URL=https://knowhere.example.com
```

如果 `DASHBOARD_PUBLIC_URL` 和浏览器地址不一致，登录或注册可能失败。

如果需要让其他机器直接访问宿主机端口，只开放必要的公开服务：

```bash
DASHBOARD_HOST_BIND=0.0.0.0
API_HOST_BIND=0.0.0.0
```

如果从 GHCR 拉取默认镜像较慢或不可用，可以使用阿里云 Docker 镜像：

```bash
KNOWHERE_IMAGE=knowhere-registry.cn-shenzhen.cr.aliyuncs.com/knowhere/knowhere:latest
```

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

## API 使用

请使用官方 SDK 调用 API：

- Node.js SDK：[Ontos-AI/knowhere-node-sdk](https://github.com/Ontos-AI/knowhere-node-sdk)
- Python SDK：[Ontos-AI/knowhere-python-sdk](https://github.com/Ontos-AI/knowhere-python-sdk)

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

除上述必填项以外的配置通常不需要修改。端口、模型、存储、Webhook、数据库和 Redis 等可选配置见 [docs/configuration.zh-CN.md](docs/configuration.zh-CN.md)。
