# Zakupy MVP Plan

## Goal

Build a first usable version for two people sharing shopping lists across Android and iPhone.

## Scope

### Included
- account registration
- login
- create list
- share list with second user
- add item
- edit item
- delete item
- mark item as bought
- see changes after refresh

### Excluded for now
- push notifications
- advanced offline mode
- barcode scanning
- product suggestions
- public internet access

## Suggested implementation order

1. Create repository structure
2. Bootstrap backend with Fastify, Prisma, and PostgreSQL
3. Create initial database schema
4. Implement auth
5. Implement lists
6. Implement list sharing
7. Implement items
8. Add Docker Compose and Caddy
9. Bootstrap Flutter app
10. Connect mobile app to API
11. Test end-to-end on both phones

## Acceptance criteria

The MVP is successful when:
- both users can log in
- one user can create a list
- the second user can see the shared list
- both users can add and check items
- state remains consistent after refresh
- the system survives backend restarts without losing data

## Status

Completed in this branch:
- backend auth, lists, sharing, and item CRUD
- item list/detail flow on mobile with create, edit, delete, and check-off actions
- refresh-based sync after writes

Remaining for the MVP:
- mobile auth flow
- list sharing UI on mobile
- end-to-end testing on real devices
