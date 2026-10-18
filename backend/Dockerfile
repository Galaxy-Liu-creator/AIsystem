# ============================================
# 阶段1: 构建阶段
# ============================================
FROM python:3.11-slim-bookworm AS builder

WORKDIR /app

# 使用稳定镜像并增强 APT 网络健壮性（适配国内网络）
RUN set -eux; \
    sed -i 's|http://deb.debian.org/debian|https://mirrors.tuna.tsinghua.edu.cn/debian|g; s|http://deb.debian.org/debian-security|https://mirrors.tuna.tsinghua.edu.cn/debian-security|g' /etc/apt/sources.list.d/debian.sources; \
    printf 'Acquire::Retries "8";\nAcquire::http::Timeout "30";\nAcquire::https::Timeout "30";\nAcquire::ForceIPv4 "true";\n' > /etc/apt/apt.conf.d/99-network-retry

# 安装构建依赖
RUN set -eux; \
        for i in 1 2 3; do \
            apt-get update -o Acquire::Retries=5 && \
            apt-get install -y --no-install-recommends gcc libpq-dev && \
            break; \
            if [ "$i" -eq 3 ]; then exit 1; fi; \
            sleep 5; \
        done; \
        rm -rf /var/lib/apt/lists/*

# 创建虚拟环境
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# pip 下载加速与网络健壮性参数（默认使用清华源，可通过 build-arg 覆盖）
ARG PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
ARG PIP_TRUSTED_HOST=pypi.tuna.tsinghua.edu.cn
ARG PIP_RETRIES=10
ARG PIP_TIMEOUT=120

# 复制依赖文件并安装（先 requirements，后本项目）
COPY requirements.txt ./
# 本地演示使用 CPU 嵌入模型，避免安装数 GB 的 CUDA 运行库。
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --index-url https://download.pytorch.org/whl/cpu \
        --retries ${PIP_RETRIES} --timeout ${PIP_TIMEOUT} "torch>=2.6" && \
    pip install \
        -i ${PIP_INDEX_URL} \
        --trusted-host ${PIP_TRUSTED_HOST} \
        --retries ${PIP_RETRIES} \
        --timeout ${PIP_TIMEOUT} \
        -r requirements.txt

# ============================================
# 阶段2: 运行阶段
# ============================================
FROM python:3.11-slim-bookworm AS runner

WORKDIR /app

# 使用稳定镜像并增强 APT 网络健壮性（适配国内网络）
RUN set -eux; \
    sed -i 's|http://deb.debian.org/debian|https://mirrors.tuna.tsinghua.edu.cn/debian|g; s|http://deb.debian.org/debian-security|https://mirrors.tuna.tsinghua.edu.cn/debian-security|g' /etc/apt/sources.list.d/debian.sources; \
    printf 'Acquire::Retries "8";\nAcquire::http::Timeout "30";\nAcquire::https::Timeout "30";\nAcquire::ForceIPv4 "true";\n' > /etc/apt/apt.conf.d/99-network-retry

# 安装运行时依赖
RUN set -eux; \
        for i in 1 2 3; do \
            apt-get update -o Acquire::Retries=5 && \
            apt-get install -y --no-install-recommends \
                libpq5 \
                ffmpeg \
                pandoc \
                fonts-wqy-zenhei \
                # Playwright/Chromium runtime deps
                libnss3 \
                libnspr4 \
                libatk1.0-0 \
                libatk-bridge2.0-0 \
                libcups2 \
                libdrm2 \
                libxkbcommon0 \
                libxcomposite1 \
                libxdamage1 \
                libxfixes3 \
                libxrandr2 \
                libgbm1 \
                libasound2 \
                libatspi2.0-0 \
                libx11-6 \
                libx11-xcb1 \
                libxcb1 \
                libxext6 \
                libxrender1 \
                libxshmfence1 \
                libpangocairo-1.0-0 \
                libpango-1.0-0 \
                libcairo2 \
                libglib2.0-0 \
                ca-certificates && \
            break; \
            if [ "$i" -eq 3 ]; then exit 1; fi; \
            sleep 8; \
        done; \
        rm -rf /var/lib/apt/lists/*

# 从构建阶段复制虚拟环境
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 在共享路径安装 Chromium，确保非 root 用户也可访问。
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright
ARG INSTALL_PLAYWRIGHT=true
RUN if [ "$INSTALL_PLAYWRIGHT" = "true" ]; then \
            python -m playwright install chromium; \
        else \
            echo "Skip Playwright browser install (INSTALL_PLAYWRIGHT=false)"; \
        fi

# 复制应用代码
COPY app/ ./app/
COPY alembic/ ./alembic/
COPY alembic.ini ./
COPY .env.example ./

# 创建非 root 用户
RUN useradd -m -u 1000 appuser && \
    mkdir -p /app/media /app/uploads /app/chroma_data /app/lightrag_data /home/appuser/.cache && \
    chown -R appuser:appuser /app /home/appuser
USER appuser

# 暴露端口
EXPOSE 8000

# 启动命令
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
