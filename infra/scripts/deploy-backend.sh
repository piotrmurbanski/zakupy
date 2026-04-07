#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
INFRA_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

cd "$INFRA_DIR"

docker compose --env-file qnap.backend.env -f docker-compose.qnap.yml pull
docker compose --env-file qnap.backend.env -f docker-compose.qnap.yml up -d
docker image prune -f
