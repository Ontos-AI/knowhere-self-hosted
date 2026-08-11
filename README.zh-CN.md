# Knowhere Self-Hosted

[English](README.md) | 中文

Knowhere Self-Hosted 用于 Knowhere 的自托管部署。如果你想使用或了解 SaaS/API 版本，请查看 [Ontos-AI/knowhere](https://github.com/Ontos-AI/knowhere)。

## 准备工作

- Docker 和 Docker Compose。
- MinerU API Key，用于 PDF 文档的初始解析。
- 大模型 API Key：DeepSeek 或阿里云百炼 DashScope。

目前，我们的配置默认使用 MinerU 作为 PDF 解析器。如果你需要自定义解析流程，也可以接入自己的解析器；只要它能产出 Markdown（`.md`）文件，Knowhere 就可以继续处理。如果你想为更多 PDF 解析器贡献支持，欢迎提交 pull request。

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
IMAGE_MODEL=qwen3.6-flash
IMAGE_MODEL_MAX=qwen3.6-flash
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

自托管部署默认会发送匿名产品遥测（`TELEMETRY_ENABLED=true`）。遥测使用随机安装 ID 与聚合指标，不包含 prompt、文件名、用户身份或请求 body。如需关闭，设置 `TELEMETRY_ENABLED=false`。事件目录、隐私边界与属性表见
[匿名产品遥测](docs/configuration.zh-CN.md#匿名产品遥测)。

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

### 输入格式建议

**上传前请先将 Office 文件转换为 PDF。** Knowhere 使用 MinerU 解析 PDF，能够输出最完整、结构化的结果
（完整 markdown、表格单元格结构、页脚及脚注）。Word 文档（`.docx`）走的是另一套较简单的解析流程，其局限包括：

- 表格被拍平为纯文本，丢失了「行到列」的数值对应关系；
- 丢弃页脚及页脚注释说明；
- 不产出 `full.md` 产物。

当前版本的 MinerU office 后端对真实 `.docx` 文件并不可靠。对政府资助申请表格的实测发现：将 `.docx`
直接提交给 MinerU 返回的是空 markdown（仅保留了页码页眉），而使用第三方转换工具生成的 PDF 偶尔也会丢失
「净新增经常性开支」等关键数字。原始 `.docx` 从不丢失数字，但缺少表格结构，难以判断数值属于哪一列。

**进行准确的成本/节省分析时，推荐流程：**

1. 上传前先用办公套件（如 LibreOffice、Microsoft Word 或 Adobe Acrobat）将源 `.docx` 转换为 PDF；
2. 将 **PDF** 上传到 Knowhere；
3. 保留原始 `.docx` 作为第二参考——如果某个数字可疑，请对照源文档核对；合计行不要只依赖单次转换的输出。

这样既能获得 MinerU 完整的结构化输出，又能保留原始文件的准确性。

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
