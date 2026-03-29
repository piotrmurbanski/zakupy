# Zakupy Architecture

## Overview

Zakupy starts as a private family shopping-list app for two users:
- one Android phone
- one iPhone
- one backend running on a home VM
- private network access through Tailscale

The first version should prioritize:
- simple deployment
- stable data sync
- low operational cost
- easy future extension

The recommended architecture is a modular monolith:
- one Flutter mobile app
- one Fastify backend
- one PostgreSQL database
- one reverse proxy

## High-level architecture

```text
+-------------------+       +-------------------+
| Android phone     |       | iPhone            |
| Flutter app       |       | Flutter app       |
+---------+---------+       +---------+---------+
          |                           |
          | HTTPS over Tailscale      |
          +-------------+-------------+
                        |
                +-------v--------+
                | Caddy          |
                | reverse proxy  |
                +-------+--------+
                        |
                +-------v--------+
                | Fastify API    |
                | TypeScript     |
                +-------+--------+
                        |
                +-------v--------+
                | PostgreSQL     |
                +----------------+
```

## Why this architecture

This setup is intentionally conservative:
- one mobile codebase reduces development effort
- one backend keeps logic centralized
- PostgreSQL handles relational data cleanly
- Tailscale avoids public exposure and router complexity
- Docker Compose keeps deployment manageable on a small VM

It is also a good stepping stone:
- the mobile app can later point to a public backend
- the backend can later add websockets, workers, and notifications
- the database model can grow without rethinking the core design

## Mobile application

### Recommended stack
- Flutter
- Dart
- `dio` or `http` for API requests
- `flutter_secure_storage` for tokens
- local storage later with SQLite or Drift if offline becomes important

### Responsibilities
- authenticate the user
- show lists and list items
- submit create/update/delete actions
- refresh state after writes
- handle loading, empty, and error states cleanly

### MVP sync strategy

Use a simple sync flow first:
- fetch lists when opening the app
- fetch list items when entering a list
- after each write, re-fetch the affected resource
- optionally auto-refresh active screens every few seconds

This is not the most efficient approach, but it is reliable and easy to debug.

### Future mobile improvements
- optimistic UI updates
- background refresh
- local offline cache
- websocket-driven updates
- push notifications

## Backend application

### Recommended stack
- Node.js
- TypeScript
- Fastify
- Prisma
- Zod for request validation where useful

### Responsibilities
- authentication
- authorization
- shopping list CRUD
- list sharing
- item CRUD
- data validation
- audit-friendly timestamps

### Suggested module layout

```text
backend/
  src/
    app.ts
    modules/
      auth/
      users/
      lists/
      items/
      shares/
    lib/
    plugins/
```

### Why Fastify
- lightweight
- fast startup and low overhead
- pleasant TypeScript support
- simpler than a larger framework for an MVP

NestJS is also valid, but Fastify keeps the first version leaner.

## Database design

### Core tables
- `users`
- `shopping_lists`
- `list_members`
- `list_items`

### Example schema outline

#### users
- `id`
- `email`
- `password_hash`
- `display_name`
- `created_at`
- `updated_at`

#### shopping_lists
- `id`
- `name`
- `owner_user_id`
- `created_at`
- `updated_at`

#### list_members
- `id`
- `list_id`
- `user_id`
- `role`
- `created_at`

#### list_items
- `id`
- `list_id`
- `name`
- `quantity`
- `unit`
- `is_checked`
- `sort_order`
- `created_by_user_id`
- `created_at`
- `updated_at`

### Notes
- `list_members` allows sharing lists with another user cleanly.
- `role` can start with `owner` and `editor`.
- `sort_order` makes manual ordering possible later.
- `updated_at` is enough for the first synchronization approach.

## API design

### Style
- REST over HTTPS
- JSON request and response bodies
- JWT access tokens for authenticated requests

### Initial endpoints

#### auth
- `POST /auth/register`
- `POST /auth/login`
- `GET /auth/me`

#### lists
- `GET /lists`
- `POST /lists`
- `GET /lists/:listId`
- `PATCH /lists/:listId`
- `DELETE /lists/:listId`

#### members
- `POST /lists/:listId/members`
- `DELETE /lists/:listId/members/:userId`

#### items
- `GET /lists/:listId/items`
- `POST /lists/:listId/items`
- `PATCH /lists/:listId/items/:itemId`
- `DELETE /lists/:listId/items/:itemId`

### Authorization rules
- only authenticated users can call business endpoints
- a user must belong to a list to read or modify it
- only the owner should remove the list or manage members at first

## Networking and deployment

### VM deployment model

Run on the Dell 5070 VM using Docker Compose:
- `api`
- `postgres`
- `caddy`

### Tailscale

The VM and both phones join the same tailnet.

Benefits:
- no public IP required
- no router port forwarding
- private access only

Tradeoffs:
- both users need Tailscale access
- app availability depends on Tailscale and home internet

### Reverse proxy

Use Caddy to:
- terminate TLS
- route traffic to the API container
- simplify HTTPS configuration

## Security

### MVP security baseline
- HTTPS only
- password hashing with Argon2
- JWT authentication
- authorization checks on every protected route
- environment variables for secrets
- regular database backups

### Important constraint

Do not trust any `list_id` from the client without checking membership server-side.

## Operations

### Minimum operational checklist
- Docker Compose file committed to the repo
- `.env.example` committed without secrets
- PostgreSQL data stored on a persistent volume
- scheduled DB backup to another disk or host
- application logs available through Docker

### Nice next steps
- Sentry for backend errors
- health endpoint
- simple uptime monitor
- staging environment if the app grows

## Growth path

When the MVP works well, add features in this order:

1. Better refresh strategy
2. Optimistic UI
3. Local cache and partial offline support
4. Websocket or SSE realtime updates
5. Push notifications
6. Public hosting if needed beyond Tailscale

## Decisions for now

- Choose one shared Flutter app instead of separate iOS and Android apps.
- Choose one backend on the VM instead of two independent services.
- Keep the backend private behind Tailscale.
- Delay complex realtime and offline-first mechanics.
- Build a strong base around lists, members, and items first.
