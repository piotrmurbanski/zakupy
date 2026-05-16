# Backend CI/CD for Ubuntu

## Goal

The backend pipeline should be fully automatic:
- every push to `develop` deploys the `dev` backend
- every push to `main` deploys the `prod` backend
- Docker images are still built in GitHub Actions
- the Ubuntu server only pulls and starts ready-made images

This keeps the server simple while giving you fully automated deployments.
In this model, GitHub Actions remains the control plane, but the actual deploy command runs locally on your Ubuntu VM through a self-hosted runner.

## Delivery model

```text
push to develop
  -> Backend CI
  -> build ghcr.io/<owner>/zakupy-backend:dev
  -> self-hosted Ubuntu runner deploys /opt/zakupy/dev

push to main
  -> Backend CI
  -> build ghcr.io/<owner>/zakupy-backend:stable
  -> self-hosted Ubuntu runner deploys /opt/zakupy/prod
```

## What is included in the repository

- [`.github/workflows/backend-ci.yml`](/home/piotr/sandbox/zakupy/.github/workflows/backend-ci.yml)
  common backend verification on pull requests and pushes to `develop` and `main`
- [`.github/workflows/backend-deploy-dev.yml`](/home/piotr/sandbox/zakupy/.github/workflows/backend-deploy-dev.yml)
  builds the `dev` image and deploys the `dev` stack on Ubuntu
- [`.github/workflows/backend-deploy-prod.yml`](/home/piotr/sandbox/zakupy/.github/workflows/backend-deploy-prod.yml)
  builds the `stable` image and deploys the production stack on Ubuntu
- [`infra/ubuntu/`](/home/piotr/sandbox/zakupy/infra/ubuntu)
  shared gateway stack plus separate `dev` and `prod` backend stacks
- [`infra/ubuntu/scripts/deploy-stack.sh`](/home/piotr/sandbox/zakupy/infra/ubuntu/scripts/deploy-stack.sh)
  syncs stack files to `/opt/zakupy/...` and runs `docker compose pull && up -d`

## Branch strategy

- `develop`
  auto-deploys the development backend
- `main`
  auto-deploys the stable backend used by production mobile builds

Recommended discipline:
- everyday work lands on feature branches
- feature branches merge into `develop`
- after verifying `dev`, merge `develop` into `main`

## Server layout

The workflows assume one Ubuntu server with these directories:

```text
/opt/zakupy/gateway
/opt/zakupy/dev
/opt/zakupy/prod
```

The gateway is shared:
- one Caddy container listening on port 80
- one Docker network `zakupy-public`
- host-based routing:
  - `DEV_HOSTNAME` -> `zakupy-backend-dev`
  - `PROD_HOSTNAME` -> `zakupy-backend-prod`

The backend stacks are isolated:
- separate PostgreSQL container per environment
- separate Compose project name
- separate `.env`
- separate named volumes

## One-time Ubuntu setup

### 1. Install Docker and Compose

Install:
- Docker Engine
- Docker Compose plugin

Verify:

```bash
docker --version
docker compose version
```

### 2. Add the self-hosted GitHub runner

Create a Linux self-hosted runner for this repository and add the custom label:
- `zakupy-deploy`

Run it as a service on the same Ubuntu VM that hosts Docker so GitHub can trigger local deployments after each push.

### 3. Allow the runner user to use Docker

Usually:

```bash
sudo usermod -aG docker <runner-user>
```

Then restart the runner service or log out and back in.

### 4. Prepare deploy directories

```bash
sudo mkdir -p /opt/zakupy/gateway /opt/zakupy/dev /opt/zakupy/prod
sudo chown -R <runner-user>:<runner-user> /opt/zakupy
```

## GitHub configuration

### Repository variables

Create these repository-level Variables:

- `DEV_HOSTNAME`
  example: `dev-api.twoj-serwer.tailnet.ts.net`
- `PROD_HOSTNAME`
  example: `api.twoj-serwer.tailnet.ts.net`
- `CADDY_HTTP_PORT`
  usually `80`

These are shared by both deploy workflows because the same gateway routes both hostnames.

### Environment: `backend-dev`

Create a GitHub Environment named `backend-dev`.

Environment Variables:
- `COMPOSE_PROJECT_NAME`
  example: `zakupy-dev`
- `POSTGRES_DB`
  example: `zakupy_dev`
- `POSTGRES_USER`
  example: `zakupy_dev`
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_SECURE`
- `SMTP_FROM`

Environment Secrets:
- `POSTGRES_PASSWORD`
- `DATABASE_URL`
- `JWT_SECRET`
- `SMTP_USER`
- `SMTP_PASSWORD`

### Environment: `backend-prod`

Create a GitHub Environment named `backend-prod`.

Environment Variables:
- `COMPOSE_PROJECT_NAME`
  example: `zakupy-prod`
- `POSTGRES_DB`
  example: `zakupy_prod`
- `POSTGRES_USER`
  example: `zakupy_prod`
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_SECURE`
- `SMTP_FROM`

Environment Secrets:
- `POSTGRES_PASSWORD`
- `DATABASE_URL`
- `JWT_SECRET`
- `SMTP_USER`
- `SMTP_PASSWORD`

Notes:
- `DATABASE_URL` should point to the Compose-local host `postgres`
- `dev` and `prod` must use different database names
- `dev` and `prod` should also use different `JWT_SECRET` values

## How deploy works

For each environment:
1. GitHub Actions checks out the repo.
2. It builds and pushes a Docker image to GHCR.
3. The self-hosted runner logs into GHCR with the workflow `GITHUB_TOKEN`.
4. The workflow renders a fresh `.env` file from GitHub Variables and Secrets.
5. The deploy script copies the current Compose files into `/opt/zakupy/<env>`.
6. The script runs:

```bash
docker compose pull
docker compose up -d --remove-orphans
```

## Image tags

The workflows publish:

### `develop`
- `ghcr.io/<owner>/zakupy-backend:dev`
- `ghcr.io/<owner>/zakupy-backend:dev-<sha>`

### `main`
- `ghcr.io/<owner>/zakupy-backend:stable`
- `ghcr.io/<owner>/zakupy-backend:stable-<sha>`

The moving tag powers automatic deploys.
The SHA tag gives you a simple rollback path.

## Manual local redeploy

If you want to redeploy directly on the Ubuntu host without pushing a new commit, use the checked-out repository together with the same stack templates:

```bash
cd /path/to/zakupy
sh infra/ubuntu/scripts/deploy-from-checkout.sh gateway /path/to/gateway.env
sh infra/ubuntu/scripts/deploy-from-checkout.sh dev /path/to/dev.env
```

For production:

```bash
cd /path/to/zakupy
sh infra/ubuntu/scripts/deploy-from-checkout.sh prod /path/to/prod.env
```

Notes:
- `gateway.env`, `dev.env`, and `prod.env` can be copied from the example files in [`infra/ubuntu/`](/home/piotr/sandbox/zakupy/infra/ubuntu)
- `COMPOSE_PROJECT_NAME` can be overridden when running `dev` or `prod`
- this path is meant as a fallback for local operator use; the default path remains GitHub-triggered deploy through the self-hosted runner

## Rollback

If a deployment breaks:
1. edit `/opt/zakupy/dev/.env` or `/opt/zakupy/prod/.env`
2. replace `BACKEND_IMAGE=...:dev` or `...:stable` with a previous SHA tag
3. rerun:

```bash
docker compose --project-name zakupy-dev --env-file /opt/zakupy/dev/.env -f /opt/zakupy/dev/docker-compose.yml up -d
```

or:

```bash
docker compose --project-name zakupy-prod --env-file /opt/zakupy/prod/.env -f /opt/zakupy/prod/docker-compose.yml up -d
```

## Notes about HTTP vs HTTPS

The included gateway uses plain HTTP hostnames on port 80:
- `http://DEV_HOSTNAME`
- `http://PROD_HOSTNAME`

This keeps the first self-hosted setup simple and avoids certificate automation assumptions.

If you later want HTTPS for physical iPhones, the next reasonable step is:
- add certificates for your chosen hostname strategy
- or move the gateway to a Tailscale-compatible HTTPS setup

## Suggested mobile API base URLs

- development mobile build:
  `http://DEV_HOSTNAME`
- production mobile build:
  `http://PROD_HOSTNAME`
