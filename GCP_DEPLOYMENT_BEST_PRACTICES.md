# GCP 部署最佳实践 — smarterlife-api

> 技术栈：Rust (Axum) · Firebase Auth · Firestore · Cloud Run · OpenAI API  
> 更新日期：2026-04-26

---

## 目录

1. [部署平台选择](#1-部署平台选择)
2. [容器镜像优化](#2-容器镜像优化)
3. [密钥与配置管理](#3-密钥与配置管理)
4. [IAM 与最小权限](#4-iam-与最小权限)
5. [Cloud Run 配置](#5-cloud-run-配置)
6. [CI/CD 流水线](#6-cicd-流水线)
7. [可观测性](#7-可观测性)
8. [安全加固](#8-安全加固)
9. [成本控制](#9-成本控制)
10. [网络与域名](#10-网络与域名)
11. [灾备与高可用](#11-灾备与高可用)
12. [快速检查清单](#12-快速检查清单)

---

## 1. 部署平台选择

**推荐：Cloud Run（全托管）**

| 方案 | 适合场景 | 说明 |
|------|---------|------|
| **Cloud Run** | ✅ 当前项目首选 | 无服务器容器，按请求计费，已有 Dockerfile |
| GKE Autopilot | 需要复杂编排、有状态服务 | 运维成本更高 |
| Compute Engine | 需要完全控制底层 | 需自行管理补丁、扩缩容 |

理由：项目已有多阶段 Dockerfile，服务无状态（状态存于 Firestore），天然适合 Cloud Run。

---

## 2. 容器镜像优化

### 2.1 现有 Dockerfile 改进点

当前 `backend/Dockerfile` 存在以下问题，建议修正：

```dockerfile
# ❌ 当前问题：cargo build --release || true 会掩盖编译错误
RUN cargo build --release || true

# ✅ 改为依赖缓存层（利用 Docker layer cache 加速 CI）
COPY Cargo.toml Cargo.lock ./
RUN cargo build --release --bin smarterlife-api 2>/dev/null; true
COPY src ./src
# 强制重新编译业务代码（touch 触发 cargo 识别变更）
RUN touch src/main.rs && cargo build --release
```

### 2.2 推荐最终 Dockerfile

```dockerfile
FROM rust:1.82-slim AS builder
WORKDIR /app

# 依赖缓存层
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs \
    && cargo build --release \
    && rm -f target/release/deps/smarterlife_api*

# 编译业务代码
COPY src ./src
RUN cargo build --release

# 运行时镜像（最小化体积）
FROM gcr.io/distroless/cc-debian12
WORKDIR /app
COPY --from=builder /app/target/release/smarterlife-api /app/smarterlife-api
ENV PORT=8080
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/app/smarterlife-api"]
```

> **为什么用 distroless？** 相比 `debian:bookworm-slim`，distroless 没有 shell 和包管理器，攻击面更小，镜像体积减少约 60%。

### 2.3 推送到 Artifact Registry（替代 Container Registry）

```bash
# 创建仓库（只需一次）
gcloud artifacts repositories create smarterlife \
  --repository-format=docker \
  --location=asia-east1 \
  --description="smarterlife-api images"

# 构建并推送
gcloud builds submit --tag asia-east1-docker.pkg.dev/$PROJECT_ID/smarterlife/api:$GIT_SHA
```

---

## 3. 密钥与配置管理

项目需要以下敏感配置，**绝对不能** 写入 Dockerfile 或代码仓库：

| 环境变量 | 来源 | 推荐方式 |
|---------|------|---------|
| `FIREBASE_API_KEY` | Firebase 控制台 | Secret Manager |
| `OPENAI_API_KEY` | OpenAI | Secret Manager |
| `GCP_PROJECT` | 非敏感 | Cloud Run 环境变量 |
| `OPENAI_BASE_URL` | 非敏感 | Cloud Run 环境变量 |

### 3.1 使用 Secret Manager

```bash
# 创建密钥
echo -n "your-firebase-api-key" | \
  gcloud secrets create FIREBASE_API_KEY --data-file=-

echo -n "sk-..." | \
  gcloud secrets create OPENAI_API_KEY --data-file=-

# 授权 Cloud Run 服务账号读取
gcloud secrets add-iam-policy-binding FIREBASE_API_KEY \
  --member="serviceAccount:smarterlife-api@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### 3.2 在 Cloud Run 中挂载 Secret

```bash
gcloud run services update smarterlife-api \
  --update-secrets=FIREBASE_API_KEY=FIREBASE_API_KEY:latest \
  --update-secrets=OPENAI_API_KEY=OPENAI_API_KEY:latest
```

---

## 4. IAM 与最小权限

### 4.1 创建专用服务账号

```bash
gcloud iam service-accounts create smarterlife-api \
  --display-name="smarterlife API Service Account"
```

### 4.2 按需授权（最小权限原则）

```bash
SA="smarterlife-api@$PROJECT_ID.iam.gserviceaccount.com"

# Firestore 读写（项目当前使用）
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA" \
  --role="roles/datastore.user"

# Secret Manager 读取
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA" \
  --role="roles/secretmanager.secretAccessor"

# 不要授予 roles/editor 或 roles/owner
```

> **注意**：`gcp_auth` 在 Cloud Run 上会自动使用附加的服务账号，无需 `GOOGLE_APPLICATION_CREDENTIALS`。

---

## 5. Cloud Run 配置

### 5.1 部署命令

```bash
gcloud run deploy smarterlife-api \
  --image=asia-east1-docker.pkg.dev/$PROJECT_ID/smarterlife/api:$GIT_SHA \
  --region=asia-east1 \
  --service-account=smarterlife-api@$PROJECT_ID.iam.gserviceaccount.com \
  --set-env-vars="GCP_PROJECT=$PROJECT_ID,RUST_LOG=smarterlife_api=info" \
  --update-secrets="FIREBASE_API_KEY=FIREBASE_API_KEY:latest,OPENAI_API_KEY=OPENAI_API_KEY:latest" \
  --min-instances=0 \
  --max-instances=10 \
  --concurrency=80 \
  --cpu=1 \
  --memory=512Mi \
  --timeout=30s \
  --no-allow-unauthenticated
```

### 5.2 关键参数说明

| 参数 | 推荐值 | 原因 |
|------|-------|------|
| `--min-instances` | `0`（dev）/ `1`（prod） | prod 设为 1 避免冷启动 |
| `--max-instances` | `10` | 防止意外流量激增超出 Firestore 配额 |
| `--concurrency` | `80` | Rust async 天然高并发，可适当调高 |
| `--timeout` | `30s` | OpenAI 调用可能较慢，根据实际 P99 调整 |
| `--no-allow-unauthenticated` | ✅ | API 有自己的 Firebase Auth，不需要 Cloud Run IAM 再暴露 |

### 5.3 CORS 安全加固

当前代码使用 `allow_origin(Any)`，生产环境应限制来源：

```rust
// main.rs — 替换 .allow_origin(tower_http::cors::Any)
.allow_origin([
    "https://your-flutter-web-domain.com".parse::<HeaderValue>().unwrap(),
])
```

---

## 6. CI/CD 流水线

### 6.1 推荐：Cloud Build + GitHub

创建 `cloudbuild.yaml`（放在仓库根目录）：

```yaml
# cloudbuild.yaml
steps:
  # 构建镜像
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - build
      - -t
      - asia-east1-docker.pkg.dev/$PROJECT_ID/smarterlife/api:$COMMIT_SHA
      - -f
      - backend/Dockerfile
      - backend/
    id: build

  # 推送镜像
  - name: 'gcr.io/cloud-builders/docker'
    args: [push, 'asia-east1-docker.pkg.dev/$PROJECT_ID/smarterlife/api:$COMMIT_SHA']
    id: push
    waitFor: [build]

  # 部署到 Cloud Run
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: gcloud
    args:
      - run
      - deploy
      - smarterlife-api
      - --image=asia-east1-docker.pkg.dev/$PROJECT_ID/smarterlife/api:$COMMIT_SHA
      - --region=asia-east1
      - --platform=managed
    waitFor: [push]

images:
  - 'asia-east1-docker.pkg.dev/$PROJECT_ID/smarterlife/api:$COMMIT_SHA'

options:
  logging: CLOUD_LOGGING_ONLY
```

### 6.2 触发器设置

```bash
# 仅在 main 分支 push 时触发
gcloud builds triggers create github \
  --repo-name=smarterlife \
  --repo-owner=dejavuwl \
  --branch-pattern='^main$' \
  --build-config=cloudbuild.yaml
```

### 6.3 滚动发布（零停机）

Cloud Run 默认支持蓝绿发布，可用流量切分做金丝雀：

```bash
# 先部署新版本，但只导入 10% 流量
gcloud run services update-traffic smarterlife-api \
  --to-revisions=LATEST=10

# 验证无误后全量切换
gcloud run services update-traffic smarterlife-api \
  --to-latest
```

---

## 7. 可观测性

### 7.1 结构化日志

项目已使用 `tracing`，在 Cloud Run 上输出 JSON 格式让 Cloud Logging 自动解析：

```rust
// main.rs — 替换 tracing_subscriber::fmt()
tracing_subscriber::fmt()
    .json()                          // 输出 JSON
    .with_current_span(true)
    .with_env_filter(
        env::var("RUST_LOG")
            .unwrap_or_else(|_| "smarterlife_api=info,tower_http=info".into()),
    )
    .init();
```

添加依赖：
```toml
# Cargo.toml
tracing-subscriber = { version = "=0.3.18", features = ["env-filter", "json"] }
```

### 7.2 健康检查

现有 `/health` 端点已满足基本需求。建议增加依赖检查：

```rust
async fn health(State(state): State<Arc<AppState>>) -> impl IntoResponse {
    // 可选：ping Firestore 确认连通性
    Json(json!({ "status": "ok", "version": env!("CARGO_PKG_VERSION") }))
}
```

在 Cloud Run 中配置：
```bash
gcloud run services update smarterlife-api \
  --set-liveness-probe=httpGet.path=/health \
  --set-startup-probe=httpGet.path=/health
```

### 7.3 关键告警指标

在 Cloud Monitoring 中创建以下告警：

| 指标 | 阈值 | 说明 |
|------|------|------|
| `run.googleapis.com/request_latencies` P99 | > 5s | 接口超时 |
| `run.googleapis.com/request_count` (5xx) | > 1% | 服务端错误率 |
| `run.googleapis.com/container/instance_count` | > 8 | 扩容预警 |

---

## 8. 安全加固

### 8.1 VPC 私有访问（可选，高安全场景）

```bash
# 创建 Serverless VPC Connector
gcloud compute networks vpc-access connectors create smarterlife-connector \
  --region=asia-east1 \
  --subnet=default

# Cloud Run 走 VPC 访问 Firestore
gcloud run services update smarterlife-api \
  --vpc-connector=smarterlife-connector \
  --vpc-egress=private-ranges-only
```

### 8.2 二进制授权（Binary Authorization）

```bash
# 强制只允许 Cloud Build 签名的镜像部署
gcloud run services update smarterlife-api \
  --binary-authorization=default
```

### 8.3 依赖漏洞扫描

```bash
# 启用 Artifact Registry 漏洞扫描
gcloud artifacts repositories update smarterlife \
  --location=asia-east1 \
  --enable-vulnerability-scanning
```

### 8.4 Rust 供应链安全

```bash
# 在 CI 中加入 cargo audit
cargo install cargo-audit
cargo audit
```

---

## 9. 成本控制

| 优化项 | 操作 | 预期节省 |
|--------|------|---------|
| 最小实例为 0（非生产） | `--min-instances=0` | 无流量时零费用 |
| 配置请求并发数 | `--concurrency=80` | 减少实例数 |
| 合理设置内存 | `--memory=512Mi`（Rust 内存占用低） | 避免超额分配 |
| 镜像使用 distroless | 减少拉取时间 | 缩短冷启动 |
| Firestore 使用批量操作 | 减少读写次数 | 降低 Firestore 费用 |

---

## 10. 网络与域名

### 10.1 自定义域名（Flutter Web + API）

```bash
# 绑定自定义域名
gcloud run domain-mappings create \
  --service=smarterlife-api \
  --domain=api.yourdomain.com \
  --region=asia-east1
```

### 10.2 Cloud Armor（DDoS 防护）

如果 API 对外公开，建议在 Cloud Run 前加 Cloud Load Balancing + Cloud Armor：

```bash
# 创建安全策略，限制每 IP 请求速率
gcloud compute security-policies rules create 1000 \
  --security-policy=smarterlife-policy \
  --action=rate-based-ban \
  --rate-limit-threshold-count=100 \
  --rate-limit-threshold-interval-sec=60 \
  --ban-duration-sec=300 \
  --conform-action=allow \
  --exceed-action=deny-403
```

---

## 11. 灾备与高可用

### 11.1 多区域部署

```bash
# 同时部署到两个区域
for region in asia-east1 asia-northeast1; do
  gcloud run deploy smarterlife-api-$region \
    --image=... \
    --region=$region
done
```

### 11.2 Firestore 备份

```bash
# 配置每日自动导出到 GCS
gcloud firestore operations export gs://$PROJECT_ID-backups/$(date +%Y%m%d)
```

---

## 12. 快速检查清单

部署前务必确认以下各项：

- [ ] 密钥已迁移至 Secret Manager，代码中无硬编码
- [ ] 使用专用服务账号，无过度授权（无 `editor`/`owner`）
- [ ] Dockerfile 使用 distroless 或 minimal 基础镜像
- [ ] 生产环境 `--min-instances=1` 避免冷启动
- [ ] CORS `allow_origin` 已限制为具体域名
- [ ] `/health` 端点已配置为 Cloud Run 健康检查
- [ ] 结构化日志（JSON）已启用
- [ ] `cargo audit` 已加入 CI 流水线
- [ ] Cloud Monitoring 告警已配置
- [ ] Artifact Registry 漏洞扫描已启用
- [ ] 镜像标签使用 Git SHA（非 `latest`）
- [ ] 已测试蓝绿发布流程
