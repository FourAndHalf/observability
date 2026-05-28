#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
  printf '%s\n' "Usage: ./scripts/restore-local.sh ./backups/YYYYMMDDTHHMMSSZ" >&2
  exit 1
fi

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
BACKUP_PATH="$1"
cd "$PROJECT_DIR"

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

test -f "$BACKUP_PATH/openobserve-data.tar.gz"
test -f "$BACKUP_PATH/phoenix.dump"

docker compose stop otel-collector phoenix openobserve

rm -rf data/openobserve
tar -xzf "$BACKUP_PATH/openobserve-data.tar.gz" -C "$PROJECT_DIR"

docker compose up -d phoenix-postgres
docker compose exec -T phoenix-postgres sh -c "dropdb -U '$PHOENIX_POSTGRES_USER' '$PHOENIX_POSTGRES_DB' --if-exists && createdb -U '$PHOENIX_POSTGRES_USER' '$PHOENIX_POSTGRES_DB'"
docker compose cp "$BACKUP_PATH/phoenix.dump" phoenix-postgres:/tmp/phoenix.dump
docker compose exec -T phoenix-postgres pg_restore -U "$PHOENIX_POSTGRES_USER" -d "$PHOENIX_POSTGRES_DB" --clean --if-exists /tmp/phoenix.dump
docker compose exec -T phoenix-postgres rm -f /tmp/phoenix.dump

docker compose up -d

printf '%s\n' "Restore complete from $BACKUP_PATH"
