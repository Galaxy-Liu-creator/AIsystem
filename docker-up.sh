#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

if ! docker info >/dev/null 2>&1; then
    docker desktop start
    for attempt in {1..60}; do
        if docker info >/dev/null 2>&1; then break; fi
        sleep 2
    done
fi

if [[ ! -f backend/.env ]]; then
    printf '请先创建 backend/.env 并配置 JWT_SECRET_KEY 和自己的 AI 密钥。\n' >&2
    exit 1
fi

docker compose up -d --build --wait --wait-timeout 600
printf '\n前端：http://127.0.0.1:5174/\nAPI 文档：http://127.0.0.1:8000/doc.html\n停止：docker compose down\n'
