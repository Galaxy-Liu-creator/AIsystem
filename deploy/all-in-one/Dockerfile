# 前后端、PostgreSQL、Redis、Celery 放在同一个容器里，和其他项目隔离。

FROM node:22-alpine AS frontend
WORKDIR /src
COPY teacher-platform/package.json teacher-platform/package-lock.json ./
RUN npm ci --registry=https://registry.npmmirror.com
COPY teacher-platform/ ./
ENV VITE_API_BASE=http://127.0.0.1:5174
RUN npm run build

FROM python:3.11-slim-bookworm AS builder
WORKDIR /build
RUN set -eux; \
    sed -i 's|http://deb.debian.org/debian|https://mirrors.tuna.tsinghua.edu.cn/debian|g; s|http://deb.debian.org/debian-security|https://mirrors.tuna.tsinghua.edu.cn/debian-security|g' /etc/apt/sources.list.d/debian.sources; \
    apt-get update; \
    apt-get install -y --no-install-recommends gcc g++ libpq-dev; \
    rm -rf /var/lib/apt/lists/*
COPY backend/requirements.txt ./
RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install -U pip uv \
    && /opt/venv/bin/uv pip install \
        --python /opt/venv/bin/python \
        --torch-backend cpu \
        --default-index https://pypi.tuna.tsinghua.edu.cn/simple \
        -r requirements.txt

FROM python:3.11-slim-bookworm
ENV DEBIAN_FRONTEND=noninteractive \
    PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PLAYWRIGHT_BROWSERS_PATH=/opt/playwright \
    PLAYWRIGHT_DOWNLOAD_HOST=https://npmmirror.com/mirrors/playwright \
    LANG=C.UTF-8

RUN set -eux; \
    sed -i 's|http://deb.debian.org/debian|https://mirrors.tuna.tsinghua.edu.cn/debian|g; s|http://deb.debian.org/debian-security|https://mirrors.tuna.tsinghua.edu.cn/debian-security|g' /etc/apt/sources.list.d/debian.sources; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        postgresql \
        postgresql-contrib \
        redis-server \
        nginx \
        tini \
        ca-certificates \
        libpq5 \
        ffmpeg \
        pandoc \
        fonts-wqy-zenhei \
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
        libglib2.0-0; \
    rm -rf /var/lib/apt/lists/* /etc/nginx/sites-enabled/default

COPY --from=builder /opt/venv /opt/venv
RUN python -m playwright install chromium

WORKDIR /app
COPY backend/app ./app
COPY backend/alembic ./alembic
COPY backend/alembic.ini ./
COPY --from=frontend /src/dist /usr/share/nginx/html
COPY deploy/all-in-one/nginx.conf /etc/nginx/conf.d/default.conf
COPY deploy/all-in-one/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && mkdir -p /app/media /app/uploads /app/chroma_data /app/lightrag_data

EXPOSE 80 8000
HEALTHCHECK --interval=15s --timeout=5s --start-period=90s --retries=12 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=4)"
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
