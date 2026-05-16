#!/bin/sh

set -eu

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <source_dir> <target_dir> <env_file> <project_name>" >&2
  exit 1
fi

SOURCE_DIR=$1
TARGET_DIR=$2
ENV_FILE=$3
PROJECT_NAME=$4

mkdir -p "$TARGET_DIR"

cp "$SOURCE_DIR/docker-compose.yml" "$TARGET_DIR/docker-compose.yml"

if [ -f "$SOURCE_DIR/Caddyfile" ]; then
  cp "$SOURCE_DIR/Caddyfile" "$TARGET_DIR/Caddyfile"
fi

install -m 600 "$ENV_FILE" "$TARGET_DIR/.env"

docker network inspect zakupy-public >/dev/null 2>&1 || docker network create zakupy-public

docker compose \
  --project-name "$PROJECT_NAME" \
  --env-file "$TARGET_DIR/.env" \
  -f "$TARGET_DIR/docker-compose.yml" \
  pull

docker compose \
  --project-name "$PROJECT_NAME" \
  --env-file "$TARGET_DIR/.env" \
  -f "$TARGET_DIR/docker-compose.yml" \
  up -d --remove-orphans

docker image prune -f
