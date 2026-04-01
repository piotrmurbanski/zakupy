# Auth feature

The mobile app authenticates against the backend using:

- `POST /auth/login`
- `POST /auth/register`
- `GET /auth/me`

Session data is stored with `flutter_secure_storage` as a JSON payload containing:

- the backend `baseUrl`
- the access token
- the authenticated user profile

The launcher restores this session on startup and clears it if the token is no longer valid.
