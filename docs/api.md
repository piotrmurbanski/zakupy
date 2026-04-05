# API Notes

## Auth

- `POST /auth/request-code`
- `POST /auth/verify-code`
- `POST /auth/logout`
- `GET /auth/me`

### Auth contract summary

- MVP auth uses `email + one-time code`
- authenticated requests use `Authorization: Bearer <sessionToken>`
- `sessionToken` is an opaque trusted-session token, not a password
- `POST /auth/request-code` should return a generic success payload even for unknown emails
- only the newest active code for an email is valid

### `POST /auth/request-code`

Request body:

```json
{
  "email": "test@example.com",
  "displayName": "Piotr"
}
```

Response:

```json
{
  "status": "code_sent"
}
```

Notes:
- `displayName` is optional and is used only when the email becomes a new user on first verification
- response should stay generic to avoid account enumeration
- dev delivery may log the code or send it to a local mailbox sink; deployed VM should use SMTP or another simple private email path

### `POST /auth/verify-code`

Request body:

```json
{
  "email": "test@example.com",
  "code": "123456",
  "displayName": "Piotr"
}
```

Response:

```json
{
  "sessionToken": "trusted-session-token",
  "user": {
    "id": "user_id",
    "email": "test@example.com",
    "displayName": "Piotr",
    "createdAt": "2026-03-29T10:00:00.000Z",
    "updatedAt": "2026-03-29T10:00:00.000Z"
  }
}
```

Notes:
- if the email does not exist yet, successful verification creates the user
- if pending invitations exist for the verified email, they should be claimed before the response is returned
- code verification should fail for expired, consumed, throttled, or over-attempted codes

### `POST /auth/logout`

Headers:

```http
Authorization: Bearer trusted-session-token
```

Response:

```json
{
  "status": "logged_out"
}
```

Notes:
- logout revokes only the current trusted session
- after logout, `GET /auth/me` with the same token should return `401`

### `GET /auth/me`

Headers:

```http
Authorization: Bearer trusted-session-token
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
Authorization: Bearer trusted-session-token
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
Authorization: Bearer trusted-session-token
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
Authorization: Bearer trusted-session-token
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
- if the invited email already belongs to an active user, the backend should create a real membership immediately
- if the invited email is not active yet, the backend should create a pending invitation instead
- duplicate active memberships or duplicate pending invitations should return `409 Conflict`

Alternative response for a pending invitation:

```json
{
  "invitation": {
    "id": "invite_id",
    "listId": "list_id",
    "email": "second-user@example.com",
    "role": "editor",
    "status": "pending",
    "createdAt": "2026-03-29T10:00:00.000Z",
    "updatedAt": "2026-03-29T10:00:00.000Z"
  }
}
```

### `DELETE /lists/:listId/members/:userId`

Headers:

```http
Authorization: Bearer trusted-session-token
```

Notes:
- only the list owner can remove members
- the owner cannot remove themselves from the list

## Items

### `GET /lists/:listId/items`

Headers:

```http
Authorization: Bearer trusted-session-token
```

Response:

```json
{
  "items": [
    {
      "id": "item_id",
      "listId": "list_id",
      "name": "Milk",
      "quantity": "2",
      "unit": "l",
      "isChecked": false,
      "sortOrder": 0,
      "createdByUserId": "user_id",
      "createdAt": "2026-03-29T10:00:00.000Z",
      "updatedAt": "2026-03-29T10:00:00.000Z"
    }
  ]
}
```

### `POST /lists/:listId/items`

Headers:

```http
Authorization: Bearer jwt-token
```

Request body:

```json
{
  "name": "Milk",
  "quantity": "2",
  "unit": "l"
}
```

Response:

```json
{
  "item": {
    "id": "item_id",
    "listId": "list_id",
    "name": "Milk",
    "quantity": "2",
    "unit": "l",
    "isChecked": false,
    "sortOrder": 0,
    "createdByUserId": "user_id",
    "createdAt": "2026-03-29T10:00:00.000Z",
    "updatedAt": "2026-03-29T10:00:00.000Z"
  }
}
```

Notes:
- the item is created with the next `sortOrder` value on the server
- `quantity` and `unit` are optional

### `PATCH /lists/:listId/items/:itemId`

Headers:

```http
Authorization: Bearer jwt-token
```

Request body:

```json
{
  "name": "Oat milk",
  "quantity": "2",
  "unit": "l",
  "isChecked": true
}
```

Response:

```json
{
  "item": {
    "id": "item_id",
    "listId": "list_id",
    "name": "Oat milk",
    "quantity": "2",
    "unit": "l",
    "isChecked": true,
    "sortOrder": 0,
    "createdByUserId": "user_id",
    "createdAt": "2026-03-29T10:00:00.000Z",
    "updatedAt": "2026-03-29T10:00:00.000Z"
  }
}
```

Notes:
- send only the fields you want to change
- empty update bodies return `400 Bad Request`

### `DELETE /lists/:listId/items/:itemId`

Headers:

```http
Authorization: Bearer jwt-token
```
