#!/bin/sh

set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this script with sudo." >&2
  exit 1
fi

RUNNER_USER=${1:-piotr}
DEPLOY_ROOT=${DEPLOY_ROOT:-/opt/zakupy}
RUNNER_HOME=${RUNNER_HOME:-/home/$RUNNER_USER}
RUNNER_DIR=${RUNNER_DIR:-$RUNNER_HOME/actions-runner}

if ! id "$RUNNER_USER" >/dev/null 2>&1; then
  echo "User $RUNNER_USER does not exist." >&2
  exit 1
fi

mkdir -p \
  "$DEPLOY_ROOT/gateway" \
  "$DEPLOY_ROOT/dev" \
  "$DEPLOY_ROOT/prod"

chown -R "$RUNNER_USER:$RUNNER_USER" "$DEPLOY_ROOT"

if getent group docker >/dev/null 2>&1; then
  usermod -aG docker "$RUNNER_USER"
fi

mkdir -p "$RUNNER_DIR"
chown -R "$RUNNER_USER:$RUNNER_USER" "$RUNNER_DIR"

cat <<EOF
Bootstrap completed.

Directories prepared:
  $DEPLOY_ROOT/gateway
  $DEPLOY_ROOT/dev
  $DEPLOY_ROOT/prod

Runner directory prepared:
  $RUNNER_DIR

User updated:
  $RUNNER_USER added to docker group if the group exists

Next:
1. Re-login as $RUNNER_USER or restart the runner service after group changes.
2. Install the GitHub self-hosted runner into $RUNNER_DIR.
3. Log Docker into ghcr.io as $RUNNER_USER.
EOF
