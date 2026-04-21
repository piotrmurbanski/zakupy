# API Notes

## Auth

- `POST /auth/request-code`
- `POST /auth/verify-code`
- `POST /auth/logout`
- `GET /auth/me`
- `PATCH /auth/me`

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
- dev delivery may log the code or send it to a local mailbox sink; deployed VM can send through configured SMTP

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
    "phoneNumber": null,
    "createdAt": "2026-03-29T10:00:00.000Z",
    "updatedAt": "2026-03-29T10:00:00.000Z"
  }
}
```

Notes:
- if the email does not exist yet, successful verification creates the user
- pending email shares are auto-claimed at sign-in for the matching email address
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
    "phoneNumber": null,
    "createdAt": "2026-03-29T10:00:00.000Z",
    "updatedAt": "2026-03-29T10:00:00.000Z"
  }
}
```

### `PATCH /auth/me`

Headers:

```http
Authorization: Bearer trusted-session-token
```

Request body:

```json
{
  "phoneNumber": "+48123123123"
}
```

Response:

```json
{
  "user": {
    "id": "user_id",
    "email": "test@example.com",
    "displayName": "Piotr",
    "phoneNumber": "+48123123123",
    "createdAt": "2026-03-29T10:00:00.000Z",
    "updatedAt": "2026-03-29T10:00:00.000Z"
  }
}
```

Notes:
- send `null` as `phoneNumber` to clear the saved number
- the backend normalizes accepted values to `+<countrycode><number>` form
- invalid phone numbers should return `400`

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
      "plannedFor": "2026-04-15T00:00:00.000Z",
      "ownerUserId": "user_id",
      "isArchived": false,
      "archivedAt": null,
      "createdAt": "2026-03-29T10:00:00.000Z",
      "updatedAt": "2026-03-29T10:00:00.000Z"
    }
  ]
}
```

Notes:
- by default this returns active lists only
- pass `?includeArchived=true` to include archived lists in the response

### `POST /lists`

Request body:

```json
{
  "name": "Weekly groceries",
  "plannedFor": "2026-04-15T00:00:00.000Z"
}
```

Response:

```json
{
  "list": {
    "id": "list_id",
    "name": "Weekly groceries",
    "plannedFor": "2026-04-15T00:00:00.000Z",
    "ownerUserId": "user_id",
    "isArchived": false,
    "archivedAt": null,
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
    "plannedFor": "2026-04-15T00:00:00.000Z",
    "ownerUserId": "user_id",
    "isArchived": false,
    "archivedAt": null,
    "createdAt": "2026-03-29T10:00:00.000Z",
    "updatedAt": "2026-03-29T10:00:00.000Z"
  },
  "sharing": {
    "memberContacts": [
      {
        "id": "member_id",
        "listId": "list_id",
        "userId": "user_id",
        "role": "editor",
        "createdAt": "2026-03-29T10:00:00.000Z",
        "updatedAt": "2026-03-29T10:00:00.000Z",
        "user": {
          "id": "user_id",
          "email": "second-user@example.com",
          "displayName": "Second User",
          "phoneNumber": "+48123123123",
          "whatsappEligible": true
        }
      }
    ],
    "pendingInvitations": [
      {
        "id": "invite_id",
        "listId": "list_id",
        "email": "pending@example.com",
        "role": "editor",
        "status": "pending",
        "createdAt": "2026-03-29T10:00:00.000Z",
        "updatedAt": "2026-03-29T10:00:00.000Z"
      }
    ]
  }
}
```

Notes:
- the owner receives a `sharing` block with active member contact metadata and pending invitations
- non-owner members still receive only the `list` object
- `user.phoneNumber` is only exposed inside the owner-facing sharing metadata
- `user.whatsappEligible` is `true` when the active member has a saved linked phone number

### `PATCH /lists/:listId`

Request body:

```json
{
  "name": "Updated groceries",
  "plannedFor": null
}
```

Response:

```json
{
  "list": {
    "id": "list_id",
    "name": "Updated groceries",
    "plannedFor": null,
    "ownerUserId": "user_id",
    "isArchived": false,
    "archivedAt": null,
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

### `POST /lists/:listId/archive`

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
    "isArchived": true,
    "archivedAt": "2026-04-09T10:00:00.000Z",
    "createdAt": "2026-03-29T10:00:00.000Z",
    "updatedAt": "2026-04-09T10:00:00.000Z"
  }
}
```

### `POST /lists/:listId/restore`

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
    "isArchived": false,
    "archivedAt": null,
    "createdAt": "2026-03-29T10:00:00.000Z",
    "updatedAt": "2026-04-09T10:05:00.000Z"
  }
}
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
      "displayName": "Second User",
      "phoneNumber": "+48123123123",
      "whatsappEligible": true
    }
  }
}
```

Notes:
- if the email already belongs to an active user, the backend creates the membership immediately
- otherwise the backend creates a pending email share that will be auto-claimed the next time that email signs in
- duplicate active memberships or duplicate pending email shares should return `409 Conflict`
- immediate member responses now include `phoneNumber` and `whatsappEligible` for owner-facing WhatsApp handoff flows

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
      "quantity": 2,
      "comment": "2%",
      "isChecked": false,
      "iconKey": "default",
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
  "quantity": 2,
  "comment": "2%",
  "iconKey": "eggs"
}
```

Response:

```json
{
  "item": {
    "id": "item_id",
    "listId": "list_id",
    "name": "Milk",
    "quantity": 2,
    "comment": "2%",
    "isChecked": false,
    "iconKey": "default",
    "sortOrder": 0,
    "createdByUserId": "user_id",
    "createdAt": "2026-03-29T10:00:00.000Z",
    "updatedAt": "2026-03-29T10:00:00.000Z"
  }
}
```

Notes:
- the item is created with the next `sortOrder` value on the server
- `quantity` defaults to `1`
- `comment` is optional

### `PATCH /lists/:listId/items/:itemId`

Headers:

```http
Authorization: Bearer jwt-token
```

Request body:

```json
{
  "name": "Oat milk",
  "quantity": 3,
  "comment": "Barista",
  "isChecked": true,
  "iconKey": "bread"
}
```

Response:

```json
{
  "item": {
    "id": "item_id",
    "listId": "list_id",
    "name": "Oat milk",
    "quantity": 3,
    "comment": "Barista",
    "isChecked": true,
    "iconKey": "bread",
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

### `GET /items/suggestions`

Headers:

```http
Authorization: Bearer jwt-token
```

Response:

```json
{
  "items": [
    {
      "id": "suggestion_id",
      "name": "Milk",
      "comment": "2%",
      "iconKey": "eggs",
      "usageCount": 12,
      "lastUsedAt": "2026-04-11T12:00:00.000Z"
    }
  ]
}
```

Notes:
- suggestions are ranked by `usageCount`, then by most recent use
- usage is updated when a user creates an item or increases its quantity
- the last chosen icon is stored with each suggestion and reused the next time the same product is selected

### `DELETE /lists/:listId/items/:itemId`

Headers:

```http
Authorization: Bearer jwt-token
```
