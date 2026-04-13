# Listek Architecture

## Overview

Listek starts as a private family shopping-list app for two users:
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

## Delivery pipeline

The backend delivery path should stay lightweight:
- GitHub Actions runs CI for backend changes
- GitHub Actions builds and publishes a Docker image to a registry
- the QNAP host pulls the published image and restarts the stack with Docker Compose

This keeps production close to local Docker usage while avoiding source builds on the NAS.

## Mobile application

### Recommended stack
- Flutter
- Dart
- `dio` or `http` for API requests
- `flutter_secure_storage` for trusted session tokens
- local storage later with SQLite or Drift if offline becomes important

### Responsibilities
- request sign-in codes and verify them
- store and restore the trusted device session
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

### Passwordless delivery

For the MVP, sign-in codes should be delivered through the simplest reliable path available in each environment:

- local development can use application logs or a disposable SMTP sink such as Mailpit
- the home VM should expose SMTP-related environment variables so the backend can send codes through a private mail provider later
- the backend should not depend on public email infrastructure for the MVP

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
- `auth_codes`
- `auth_sessions`
- `list_invitations`
- `shopping_lists`
- `list_members`
- `list_items`

### Example schema outline

#### users
- `id`
- `email`
- `display_name`
- `created_at`
- `updated_at`

#### auth_codes
- `id`
- `email`
- `code_hash`
- `expires_at`
- `consumed_at`
- `attempt_count`
- `created_at`
- `updated_at`

#### auth_sessions
- `id`
- `user_id`
- `token_hash`
- `device_label`
- `last_used_at`
- `expires_at`
- `revoked_at`
- `created_at`
- `updated_at`

#### list_invitations
- `id`
- `list_id`
- `email`
- `role`
- `invited_by_user_id`
- `claimed_by_user_id`
- `claimed_at`
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
- `comment`
- `is_checked`
- `sort_order`
- `created_by_user_id`
- `created_at`
- `updated_at`

#### item_suggestions
- `id`
- `user_id`
- `name`
- `normalized_name`
- `comment`
- `normalized_comment`
- `usage_count`
- `last_used_at`
- `created_at`
- `updated_at`

### Notes
- `list_members` allows sharing lists with another user cleanly.
- `list_invitations` keeps email-based sharing working before the invited person has signed in for the first time.
- `auth_codes` should store only hashed one-time codes and should invalidate older active codes for the same email when a new code is requested.
- `auth_sessions` should back the trusted-device flow with opaque bearer tokens stored only as hashes in PostgreSQL.
- `role` can start with `owner` and `editor`.
- `sort_order` makes manual ordering possible later.
- `updated_at` is enough for the first synchronization approach.

## Authentication model

### MVP auth choice

The MVP should switch from passwords to `email + one-time code`.

Reasons:
- the app is private and used by two known people
- email remains the stable identity for sharing and sync
- removing passwords reduces UX and support overhead
- opaque trusted sessions are easier to revoke and reason about than long-lived password credentials

Magic links can be added later, but the initial contract should assume numeric or short alphanumeric one-time codes.

### Canonical sign-in flow

1. the app asks for an email address
2. the client calls `POST /auth/request-code`
3. the backend generates a short-lived one-time code, stores only its hash, and delivers it by email
4. the app collects the code and calls `POST /auth/verify-code`
5. after successful verification, the backend creates or reuses the `users` record, creates a trusted session, and returns an opaque bearer token
6. the app stores that trusted session token securely and restores it on future launches with `GET /auth/me`

### Trusted-device semantics

- a trusted session belongs to one app install on one device
- the mobile app stores the opaque session token in secure storage
- the same token is sent as `Authorization: Bearer <sessionToken>` on authenticated requests
- sessions should survive normal app restarts
- logout revokes only the current trusted session
- deleting app storage or reinstalling the app should require a new code verification
- sessions should have a long but finite lifetime, for example 90 days with rolling `last_used_at` updates

### Security constraints

- `POST /auth/request-code` should always return a generic success response to avoid revealing whether an email is already active
- one-time codes should expire quickly, recommended at 10 minutes
- only the newest unconsumed code for an email should remain valid
- verification attempts should be capped per code, recommended at 5 attempts
- resend should be throttled per email, recommended at 60 seconds minimum between sends
- request volume should be rate-limited per email and per IP
- code values and session tokens must be stored only as hashes in PostgreSQL

### User identity creation

- `email` remains the canonical identity key
- if the verified email does not exist yet, the backend creates the user during `POST /auth/verify-code`
- the first successful verification may include an optional `displayName`; if absent, the backend may derive a temporary fallback from the email local-part
- subsequent sign-ins ignore user creation fields and simply create a new trusted session

### Invitation and sharing model

- list owners can share a list with any email address, even if that email has not signed in yet
- if the email already belongs to an active user, the backend should create a `list_members` row immediately
- otherwise, the backend should create a `list_invitations` row keyed by normalized email
- pending email shares should be auto-claimed when a user signs in with the matching email address
- API responses should distinguish active members from pending email shares so mobile can explain share state clearly

## API design

### Style
- REST over HTTPS
- JSON request and response bodies
- opaque bearer session tokens for authenticated requests

### Initial endpoints

#### auth
- `POST /auth/request-code`
- `POST /auth/verify-code`
- `POST /auth/logout`
- `GET /auth/me`

#### lists
- `GET /lists`
- `POST /lists`
- `GET /lists/:listId`
- `PATCH /lists/:listId`
- `DELETE /lists/:listId`
- `POST /lists/:listId/archive`
- `POST /lists/:listId/restore`

#### members
- `POST /lists/:listId/members`
- `DELETE /lists/:listId/members/:userId`

#### items
- `GET /items/suggestions`
- `GET /lists/:listId/items`
- `POST /lists/:listId/items`
- `PATCH /lists/:listId/items/:itemId`
- `DELETE /lists/:listId/items/:itemId`

### Authorization rules
- only authenticated users can call business endpoints
- a user must belong to a list to read or modify it
- only the owner should remove the list or manage members at first
- only the owner should archive or restore a list

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
- passwordless email verification
- trusted bearer sessions
- code hashing with a slow hash such as Argon2
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
