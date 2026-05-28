#!/usr/bin/env sh
set -eu

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$PROJECT_DIR"

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

: "${AWS_S3_BACKUP_URI:?Set AWS_S3_BACKUP_URI in .env}"

./scripts/backup-local.sh
LATEST="$(find "${BACKUP_DIR:-./backups}" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1)"

if [ -n "${AWS_PROFILE:-}" ]; then
  aws s3 sync "$LATEST" "$AWS_S3_BACKUP_URI/$(basename "$LATEST")" --profile "$AWS_PROFILE" --sse AES256
else
  aws s3 sync "$LATEST" "$AWS_S3_BACKUP_URI/$(basename "$LATEST")" --sse AES256
fi

printf '%s\n' "Backup synced to $AWS_S3_BACKUP_URI/$(basename "$LATEST")"
