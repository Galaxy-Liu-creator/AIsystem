#!/bin/bash
set -euo pipefail

PG_VER="$(ls /usr/lib/postgresql | sort | tail -1)"
PG_BIN="/usr/lib/postgresql/${PG_VER}/bin"
PGDATA="/var/lib/postgresql/${PG_VER}/main"

mkdir -p "$PGDATA" /var/lib/redis /var/log/postgresql /app/media /app/uploads /app/chroma_data /app/lightrag_data
chown -R postgres:postgres /var/lib/postgresql /var/log/postgresql
chown -R redis:redis /var/lib/redis

if [[ ! -f "${PGDATA}/postgresql.conf" ]]; then
  rm -rf "$PGDATA"
  mkdir -p "$PGDATA"
  chown -R postgres:postgres /var/lib/postgresql
  runuser -u postgres -- "${PG_BIN}/initdb" \
    -D "$PGDATA" \
    --encoding=UTF8 \
    --locale=C \
    --auth-local=peer \
    --auth-host=scram-sha-256
fi

runuser -u postgres -- "${PG_BIN}/pg_ctl" -D "$PGDATA" -w -l /var/log/postgresql/postgresql.log start

for _ in $(seq 1 30); do
  if runuser -u postgres -- "${PG_BIN}/pg_isready" -d postgres; then
    break
  fi
  sleep 1
done

runuser -u postgres -- psql -v ON_ERROR_STOP=1 -d postgres <<'SQL'
ALTER USER postgres WITH PASSWORD 'postgres';
SQL

if ! runuser -u postgres -- psql -tAc "SELECT 1 FROM pg_database WHERE datname='ai_teaching'" | grep -q 1; then
  runuser -u postgres -- psql -v ON_ERROR_STOP=1 -d postgres <<'SQL'
CREATE DATABASE ai_teaching OWNER postgres;
SQL
fi

redis-server \
  --bind 127.0.0.1 \
  --port 6379 \
  --daemonize yes \
  --appendonly yes \
  --dir /var/lib/redis \
  --protected-mode yes

export DATABASE_URL="postgresql+asyncpg://postgres:postgres@127.0.0.1:5432/ai_teaching"
export DATABASE_URL_SYNC="postgresql://postgres:postgres@127.0.0.1:5432/ai_teaching"
export REDIS_URL="redis://127.0.0.1:6379/0"
export CHROMA_PERSIST_DIR="/app/chroma_data"
export LIGHTRAG_WORKING_DIR="/app/lightrag_data"
export APP_HOST="0.0.0.0"
export APP_PORT="8000"
export DEBUG="false"

cd /app
python - <<'PY'
import asyncio
from app.core.database import init_db

asyncio.run(init_db())
print("database schema created")
PY

uvicorn app.main:app --host 0.0.0.0 --port 8000 &
UVICORN_PID=$!

celery -A app.celery:celery_app worker --loglevel=info --concurrency=2 -Q default,celery &
CELERY_PID=$!

cleanup() {
  nginx -s quit >/dev/null 2>&1 || true
  kill "$UVICORN_PID" "$CELERY_PID" >/dev/null 2>&1 || true
  redis-cli shutdown nosave >/dev/null 2>&1 || true
  runuser -u postgres -- "${PG_BIN}/pg_ctl" -D "$PGDATA" -m fast -w stop >/dev/null 2>&1 || true
}
trap cleanup TERM INT

nginx -g 'daemon off;' &
NGINX_PID=$!

set +e
wait -n "$UVICORN_PID" "$NGINX_PID" "$CELERY_PID"
STATUS=$?
set -e
cleanup
exit "$STATUS"
