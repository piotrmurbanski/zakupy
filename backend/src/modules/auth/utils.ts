import type { UserRecord } from '../../lib/types.js';

export function toUserResponse(user: UserRecord) {
  return {
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    phoneNumber: user.phoneNumber,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt
  };
}
