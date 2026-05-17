# Backend Ubuntu Next Steps

This file is the shortest path from the current repository changes to a working automated backend deploy host.

## What is already prepared in the repo

- automatic `develop -> dev` workflow
- automatic `main -> prod` workflow
- Ubuntu deploy stack templates in [`infra/ubuntu/`](/home/piotr/sandbox/zakupy/infra/ubuntu)
- deployment guide in [`docs/backend-cicd-ubuntu.md`](/home/piotr/sandbox/zakupy/docs/backend-cicd-ubuntu.md)
- host bootstrap helper in [`infra/ubuntu/scripts/bootstrap-ubuntu-host.sh`](/home/piotr/sandbox/zakupy/infra/ubuntu/scripts/bootstrap-ubuntu-host.sh)

## What still has to be done on the Ubuntu server

Run this once with sudo:

```bash
cd /home/piotr/sandbox/zakupy
sudo sh infra/ubuntu/scripts/bootstrap-ubuntu-host.sh piotr
```

This will:
- create `/opt/zakupy/gateway`
- create `/opt/zakupy/dev`
- create `/opt/zakupy/prod`
- add `piotr` to the `docker` group if available
- prepare `/home/piotr/actions-runner`

After that:
- log out and back in, or reboot, so the `docker` group change applies

## Install the self-hosted runner

In GitHub:
- open the repository
- go to `Settings -> Actions -> Runners`
- click `New self-hosted runner`
- choose Linux x64

Then run the commands from GitHub, but use:
- runner directory: `/home/piotr/actions-runner`
- custom label: `zakupy-deploy`

When GitHub shows the config command, make sure the labels include:

```text
zakupy-deploy
```

Install the runner as a service:

```bash
cd /home/piotr/actions-runner
sudo ./svc.sh install
sudo ./svc.sh start
```

## Optional manual local deploy path

The workflows already log into GHCR automatically with `GITHUB_TOKEN`, so a separate host-level `docker login ghcr.io` is not required for normal GitHub-triggered deploys.

If you want a manual fallback from a local repo checkout on the Ubuntu machine, prepare env files and run:

```bash
cd /home/piotr/sandbox/zakupy
sh infra/ubuntu/scripts/deploy-from-checkout.sh gateway /path/to/gateway.env
sh infra/ubuntu/scripts/deploy-from-checkout.sh dev /path/to/dev.env
```

For production fallback:

```bash
cd /home/piotr/sandbox/zakupy
sh infra/ubuntu/scripts/deploy-from-checkout.sh prod /path/to/prod.env
```

## Configure GitHub repository variables

Repository `Settings -> Secrets and variables -> Actions -> Variables`

Create:
- `TAILSCALE_HOSTNAME`
- `CADDY_HTTP_PORT`
- `CADDY_DEV_PORT`

Suggested values:

```text
TAILSCALE_HOSTNAME=besztia.tail218f8.ts.net
CADDY_HTTP_PORT=80
CADDY_DEV_PORT=8080
```

## Configure GitHub environments

Create:
- `backend-dev`
- `backend-prod`

Then fill them exactly as described in:
- [`docs/backend-cicd-ubuntu.md`](/home/piotr/sandbox/zakupy/docs/backend-cicd-ubuntu.md)

The key point:
- `backend-dev` must use `zakupy_dev`
- `backend-prod` must use `zakupy_prod`
- they must not share the same database

## First verification

### Check Docker access as `piotr`

```bash
docker ps
```

This should work without `sudo`.

### Check runner service

```bash
cd /home/piotr/actions-runner
sudo ./svc.sh status
```

### First dev deploy

Push any backend change to `develop`.

Expected result:
- GitHub builds and pushes `:dev`
- the self-hosted runner on the same Ubuntu host deploys `/opt/zakupy/dev`

Then verify:

```bash
docker ps
docker logs zakupy-backend-dev --tail 50
curl http://besztia.tail218f8.ts.net:8080/health
```

### First prod deploy

Merge `develop` into `main`.

Expected result:
- GitHub builds and pushes `:stable`
- the self-hosted runner on the same Ubuntu host deploys `/opt/zakupy/prod`

Then verify:

```bash
docker logs zakupy-backend-prod --tail 50
curl http://besztia.tail218f8.ts.net/health
```
