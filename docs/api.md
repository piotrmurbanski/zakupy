# API Notes

## Auth

- `POST /auth/register`
- `POST /auth/login`
- `GET /auth/me`

### `POST /auth/register`

Request body:

```json
{
  "email": "test@example.com",
  "password": "supersecret123",
  "displayName": "Piotr"
}
```

Response:

```json
{
  "accessToken": "jwt-token",
  "user": {
    "id": "user_id",
    "email": "test@example.com",
    "displayName": "Piotr",
    "createdAt": "2026-03-29T10:00:00.000Z",
    "updatedAt": "2026-03-29T10:00:00.000Z"
  }
}
```

### `POST /auth/login`

Request body:

```json
{
  "email": "test@example.com",
  "password": "supersecret123"
}
```

Response:

```json
{
  "accessToken": "jwt-token",
  "user": {
    "id": "user_id",
    "email": "test@example.com",
    "displayName": "Piotr",
    "createdAt": "2026-03-29T10:00:00.000Z",
    "updatedAt": "2026-03-29T10:00:00.000Z"
  }
}
```

### `GET /auth/me`

Headers:

```http
Authorization: Bearer jwt-token
```

Response:

```json
{
  "user": {
    "id": "user_id",
    "email": "test@example.com",
    "displayName": "Piotr",
    "createdAt": "2026-03-29T10:00:00.000Z",
    "updatedAt": "2026-03-29T10:00:00.000Z"
  }
}
```

## Lists

- `GET /lists`
- `POST /lists`
- `GET /lists/:listId`
- `PATCH /lists/:listId`
- `DELETE /lists/:listId`

## Members

- `POST /lists/:listId/members`
- `DELETE /lists/:listId/members/:userId`

## Items

- `GET /lists/:listId/items`
- `POST /lists/:listId/items`
- `PATCH /lists/:listId/items/:itemId`
- `DELETE /lists/:listId/items/:itemId`
