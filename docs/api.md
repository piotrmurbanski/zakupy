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

### `GET /lists`

Headers:

```http
Authorization: Bearer jwt-token
```

Response:

```json
{
  "items": [
    {
      "id": "list_id",
      "name": "Weekly groceries",
      "ownerUserId": "user_id",
      "createdAt": "2026-03-29T10:00:00.000Z",
      "updatedAt": "2026-03-29T10:00:00.000Z"
    }
  ]
}
```

### `POST /lists`

Request body:

```json
{
  "name": "Weekly groceries"
}
```

Response:

```json
{
  "list": {
    "id": "list_id",
    "name": "Weekly groceries",
    "ownerUserId": "user_id",
    "createdAt": "2026-03-29T10:00:00.000Z",
    "updatedAt": "2026-03-29T10:00:00.000Z"
  }
}
```

### `GET /lists/:listId`

Headers:

```http
Authorization: Bearer jwt-token
```

Response:

```json
{
  "list": {
    "id": "list_id",
    "name": "Weekly groceries",
    "ownerUserId": "user_id",
    "createdAt": "2026-03-29T10:00:00.000Z",
    "updatedAt": "2026-03-29T10:00:00.000Z"
  }
}
```

### `PATCH /lists/:listId`

Request body:

```json
{
  "name": "Updated groceries"
}
```

Response:

```json
{
  "list": {
    "id": "list_id",
    "name": "Updated groceries",
    "ownerUserId": "user_id",
    "createdAt": "2026-03-29T10:00:00.000Z",
    "updatedAt": "2026-03-29T10:00:00.000Z"
  }
}
```

### `DELETE /lists/:listId`

Headers:

```http
Authorization: Bearer jwt-token
```

## Members

- `POST /lists/:listId/members`
- `DELETE /lists/:listId/members/:userId`

## Items

- `GET /lists/:listId/items`
- `POST /lists/:listId/items`
- `PATCH /lists/:listId/items/:itemId`
- `DELETE /lists/:listId/items/:itemId`
