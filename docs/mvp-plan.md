# Zakupy MVP Plan

## Goal

Build a first usable version for two people sharing shopping lists across Android and iPhone.

## Scope

### Included
- passwordless sign-in by email code
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
- both users can sign in with a verified email and trusted session
- one user can create a list
- the second user can see the shared list
- both users can add and check items
- state remains consistent after refresh
- the system survives backend restarts without losing data

## Status

Implemented in the current codebase:
- backend auth, list CRUD, sharing, and item CRUD
- mobile auth foundation with session persistence and session restore on launch
- list overview and detail flow on mobile
- list sharing by email from the mobile UI
- list renaming from the detail screen for owners
- item create, edit, delete, and check-off actions on mobile
- refresh-based sync after writes
- periodic background refresh in the item detail view

Still worth doing before calling the MVP done:
- end-to-end testing on real devices
- basic smoke testing of the share flow with two real accounts
- confirm passwordless code delivery on local dev and the home VM
- UX polish after hands-on use
