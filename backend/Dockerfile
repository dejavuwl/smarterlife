FROM rust:1.85-slim AS builder
WORKDIR /app

# 依赖缓存层：仅 Cargo 文件变更时才重新下载依赖
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs \
    && cargo build --release \
    && rm -f target/release/deps/smarterlife_api*

# 编译业务代码
COPY src ./src
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=builder /app/target/release/smarterlife-api /usr/local/bin/smarterlife-api
ENV PORT=8080
EXPOSE 8080
CMD ["smarterlife-api"]
