#!/usr/bin/env sh
set -eu

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$PROJECT_DIR"

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DEST="$BACKUP_DIR/$STAMP"

mkdir -p "$DEST"

docker compose exec -T phoenix-postgres pg_dump \
  -U "$PHOENIX_POSTGRES_USER" \
  -d "$PHOENIX_POSTGRES_DB" \
  --format=custom \
  --file=/tmp/phoenix.dump

docker compose cp phoenix-postgres:/tmp/phoenix.dump "$DEST/phoenix.dump"
docker compose exec -T phoenix-postgres rm -f /tmp/phoenix.dump

tar -czf "$DEST/openobserve-data.tar.gz" -C "$PROJECT_DIR" data/openobserve
tar -czf "$DEST/config.tar.gz" -C "$PROJECT_DIR" docker-compose.yml config caddy .env

find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} +

printf '%s\n' "Backup written to $DEST"
