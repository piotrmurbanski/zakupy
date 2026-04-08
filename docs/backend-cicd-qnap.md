# Backend CI/CD for QNAP

## Goal

The backend deployment flow should stay simple:
- GitHub Actions verifies backend changes
- GitHub Actions publishes a production Docker image to GHCR
- QNAP pulls the latest image and restarts only the backend stack

This keeps the QNAP setup light and avoids building TypeScript code on the NAS.

## Recommended flow

```text
git push
  -> GitHub Actions CI
  -> GitHub Actions builds and pushes ghcr.io/<owner>/zakupy-backend:latest
  -> QNAP runs docker compose pull && docker compose up -d
  -> mobile app connects through Tailscale/Caddy
```

## What is included in the repository

- `backend/Dockerfile`
  production-ready image that builds TypeScript ahead of time and runs Prisma migrations on startup
- `.github/workflows/backend-ci.yml`
  installs dependencies, runs Prisma generate, builds the backend, runs tests, and verifies Docker build
- `.github/workflows/backend-cd.yml`
  publishes the backend image to GHCR on push to `main`
- `infra/docker-compose.qnap.yml`
  production compose file for QNAP using a prebuilt backend image
- `infra/qnap.backend.env.example`
  example environment file for the NAS
- `infra/scripts/deploy-backend.sh`
  one-command pull and restart script for QNAP

## GitHub setup

### 1. Enable GHCR package publishing

The workflow uses the built-in `GITHUB_TOKEN`, so no extra registry password is needed for publishing from Actions.

### 2. Make the package readable by QNAP

If the repository or package is private, create a GitHub personal access token with:
- `read:packages`

You will use that token on the QNAP machine for `docker login ghcr.io`.

## QNAP setup

### 1. Install Container Station / Docker Compose support

You need Docker with Compose support available from shell.

### 2. Copy the infra files to QNAP

At minimum copy:
- `infra/docker-compose.qnap.yml`
- `infra/Caddyfile`
- `infra/qnap.backend.env.example`
- `infra/scripts/deploy-backend.sh`

### 3. Create the production env file

On QNAP:

```bash
cd /share/Container/zakupy/infra
cp qnap.backend.env.example qnap.backend.env
```

Then update:
- `POSTGRES_PASSWORD`
- `DATABASE_URL`
- `JWT_SECRET`
- `BACKEND_IMAGE`
- SMTP settings

### 4. Log in to GHCR from QNAP

```bash
docker login ghcr.io
```

Use:
- GitHub username
- personal access token with `read:packages`

### 5. First start

```bash
cd /share/Container/zakupy/infra
sh scripts/deploy-backend.sh
```

## Deploying updates

After every merge to `main`:
1. GitHub Actions publishes a new image to GHCR.
2. On QNAP run `sh scripts/deploy-backend.sh`.

This is already a valid CD flow: build and release are automated, while deploy on the private host is a single pull-based command.

The current QNAP compose file binds Caddy only on HTTP port `80`, because the bundled `Caddyfile` is HTTP-only and many QNAP setups already use `443`.

## Optional next step: full automatic deploy

If you later want zero-touch deploys, the safest next options are:
- run a self-hosted GitHub Actions runner inside your Tailscale network
- or schedule the QNAP to run `sh scripts/deploy-backend.sh` periodically

For the MVP, pull-based deploy is easier to debug and safer than exposing SSH from GitHub Actions into your private network.
