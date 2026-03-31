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

### `POST /lists/:listId/members`

Headers:

```http
Authorization: Bearer jwt-token
```

Request body:

```json
{
  "email": "second-user@example.com"
}
```

Response:

```json
{
  "member": {
    "id": "member_id",
    "listId": "list_id",
    "userId": "user_id",
    "role": "editor",
    "createdAt": "2026-03-29T10:00:00.000Z",
    "updatedAt": "2026-03-29T10:00:00.000Z",
    "user": {
      "id": "user_id",
      "email": "second-user@example.com",
      "displayName": "Second User"
    }
  }
}
```

Notes:
- only the list owner can add members
- the invited user must already exist
- duplicate membership returns `409 Conflict`

### `DELETE /lists/:listId/members/:userId`

Headers:

```http
Authorization: Bearer jwt-token
```

Notes:
- only the list owner can remove members
- the owner cannot remove themselves from the list

## Items

- `GET /lists/:listId/items`
- `POST /lists/:listId/items`
- `PATCH /lists/:listId/items/:itemId`
- `DELETE /lists/:listId/items/:itemId`
