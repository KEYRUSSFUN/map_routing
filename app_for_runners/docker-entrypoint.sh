#!/bin/sh
set -e

wait_for_db() {
  echo "Waiting for database..."
  python - <<'PY'
import os
import sys
import time

import psycopg2

url = os.environ.get("DATABASE_URL", "").replace(
    "postgresql+psycopg2://", "postgresql://", 1
)
if not url:
    sys.exit(0)

for attempt in range(1, 31):
    try:
        conn = psycopg2.connect(url)
        conn.close()
        print("Database is ready.")
        sys.exit(0)
    except psycopg2.OperationalError:
        print(f"Database not ready (attempt {attempt}/30)...")
        time.sleep(2)

print("Database is still unavailable after retries.")
sys.exit(1)
PY
}

wait_for_db

echo "Applying database migrations..."
if ! flask db upgrade; then
  echo ""
  echo "!!! Migration failed !!!"
  CURRENT="$(flask db current 2>/dev/null || true)"
  echo "Current DB revision: ${CURRENT}"
  echo ""
  echo "If you see 'Can't locate revision', run:"
  echo "  docker compose down"
  echo "  docker compose up -d --build"
  echo ""
  echo "Or reset alembic stamp to the last working revision:"
  echo "  docker compose run --rm api flask db stamp 010_challenges"
  echo "  docker compose up -d"
  exit 1
fi

echo "Starting server on port 5000..."
exec python run.py
