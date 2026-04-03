# Auth feature

Implemented flow:
- login and registration against the Fastify API
- JWT session persistence in `flutter_secure_storage`
- auto-restore of a saved session on app launch through `/auth/me`
- API base URL selection per device, so each phone can point at the right home backend
