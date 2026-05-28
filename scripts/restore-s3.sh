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

BACKUP_NAME="${1:-}"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

if [ -z "$BACKUP_NAME" ]; then
  if [ -n "${AWS_PROFILE:-}" ]; then
    BACKUP_NAME="$(aws s3 ls "$AWS_S3_BACKUP_URI/" --profile "$AWS_PROFILE" | awk '/PRE/ {print $2}' | sed 's:/$::' | sort | tail -n 1)"
  else
    BACKUP_NAME="$(aws s3 ls "$AWS_S3_BACKUP_URI/" | awk '/PRE/ {print $2}' | sed 's:/$::' | sort | tail -n 1)"
  fi
fi

if [ -z "$BACKUP_NAME" ]; then
  printf '%s\n' "No backup folders found at $AWS_S3_BACKUP_URI" >&2
  exit 1
fi

S3_SOURCE="$AWS_S3_BACKUP_URI/$BACKUP_NAME"
LOCAL_DEST="$TMP_DIR/$BACKUP_NAME"
mkdir -p "$LOCAL_DEST"

if [ -n "${AWS_PROFILE:-}" ]; then
  aws s3 sync "$S3_SOURCE" "$LOCAL_DEST" --profile "$AWS_PROFILE"
else
  aws s3 sync "$S3_SOURCE" "$LOCAL_DEST"
fi

./scripts/restore-local.sh "$LOCAL_DEST"

printf '%s\n' "Restore complete from $S3_SOURCE"
