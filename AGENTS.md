# Zakupy Project Guidelines

## Project goal
- Build a private shopping-list app for two users first.
- Support Android and iPhone from a single mobile codebase.
- Run the backend on a home VM, reachable through Tailscale.
- Prefer simple, maintainable solutions over premature scaling.

## Product scope for MVP
- User registration and login
- Create shopping lists
- Share lists with another user
- Add, edit, remove, and check off items
- Keep data synced through the backend
- Work well for two concurrent users

## Architecture decisions
- Mobile app: Flutter
- Backend API: Node.js with Fastify and TypeScript
- Database: PostgreSQL
- ORM: Prisma
- Deployment: Docker Compose on a VM
- Private networking: Tailscale
- Reverse proxy/TLS: Caddy

## Engineering principles
- Start with a modular monolith.
- Keep backend business rules on the server.
- Use REST for the first API version.
- Add realtime only after the basic sync flow works well.
- Optimize for reliability, backups, and debuggability.
- Avoid introducing extra infrastructure unless there is a clear need.

## Repository structure target
- `mobile/` Flutter application
- `backend/` Fastify API
- `docs/` architecture, API, and ops notes
- `infra/` deployment files such as Docker Compose and Caddy config

## Coding standards
- Use TypeScript in the backend with strict mode enabled.
- Keep functions small and explicit.
- Prefer clear names over clever abstractions.
- Add tests for business-critical backend logic.
- Keep comments short and only where code would otherwise be hard to follow.

## Data and sync rules
- PostgreSQL is the source of truth.
- Each table should include `id`, `created_at`, and `updated_at`.
- Use soft deletion only when it clearly helps sync or auditability.
- For MVP, use server-authoritative writes with simple refresh-based sync.
- Defer advanced conflict resolution until needed by real usage.

## Security basics
- Hash passwords with Argon2.
- Do not store secrets in the repository.
- Require authorization checks for every list and item operation.
- Expose services only through Tailscale unless explicitly changed later.
- Plan regular PostgreSQL backups from the beginning.

## Non-goals for MVP
- Public internet exposure
- Multi-tenant SaaS concerns
- Complex realtime collaboration
- Microservices
- Kubernetes
- Advanced recommendation features

## Documentation
- Keep architecture changes reflected in `docs/`.
- Update docs when decisions change materially.
