#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
UBUNTU_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <gateway|dev|prod> <env-file>" >&2
  exit 1
fi

STACK_NAME=$1
ENV_FILE=$2
DEPLOY_ROOT=${DEPLOY_ROOT:-/opt/zakupy}

case "$STACK_NAME" in
  gateway)
    SOURCE_DIR="$UBUNTU_DIR/gateway"
    TARGET_DIR="$DEPLOY_ROOT/gateway"
    PROJECT_NAME=zakupy-gateway
    ;;
  dev)
    SOURCE_DIR="$UBUNTU_DIR/dev"
    TARGET_DIR="$DEPLOY_ROOT/dev"
    PROJECT_NAME=${COMPOSE_PROJECT_NAME:-zakupy-dev}
    ;;
  prod)
    SOURCE_DIR="$UBUNTU_DIR/prod"
    TARGET_DIR="$DEPLOY_ROOT/prod"
    PROJECT_NAME=${COMPOSE_PROJECT_NAME:-zakupy-prod}
    ;;
  *)
    echo "Unknown stack: $STACK_NAME" >&2
    echo "Expected one of: gateway, dev, prod" >&2
    exit 1
    ;;
esac

if [ ! -f "$ENV_FILE" ]; then
  echo "Env file not found: $ENV_FILE" >&2
  exit 1
fi

sh "$SCRIPT_DIR/deploy-stack.sh" \
  "$SOURCE_DIR" \
  "$TARGET_DIR" \
  "$ENV_FILE" \
  "$PROJECT_NAME"
