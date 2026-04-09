export type UserRecord = {
  id: string;
  email: string;
  displayName: string;
  createdAt: Date;
  updatedAt: Date;
};

export type AuthCodeRecord = {
  id: string;
  email: string;
  codeHash: string;
  expiresAt: Date;
  consumedAt: Date | null;
  attemptCount: number;
  createdAt: Date;
  updatedAt: Date;
};

export type AuthSessionRecord = {
  id: string;
  userId: string;
  tokenHash: string;
  deviceLabel: string | null;
  lastUsedAt: Date;
  expiresAt: Date;
  revokedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
};

export type InvitationRecord = {
  id: string;
  listId: string;
  email: string;
  role: 'owner' | 'editor';
  invitedByUserId: string;
  claimedByUserId: string | null;
  claimedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
};

export type ShoppingListRecord = {
  id: string;
  name: string;
  ownerUserId: string;
  archivedAt: Date | null;
  archivedByUserId: string | null;
  createdAt: Date;
  updatedAt: Date;
};

export type AuthPrisma = {
  user: {
    findUnique(args: {
      where: {
        id?: string;
        email?: string;
      };
    }): Promise<UserRecord | null>;
    create(args: {
      data: {
        email: string;
        displayName: string;
      };
    }): Promise<UserRecord>;
  };
  authCode: {
    findFirst(args: {
      where: {
        email?: string;
        consumedAt?: null;
      };
      orderBy?: {
        createdAt: 'asc' | 'desc';
      };
    }): Promise<AuthCodeRecord | null>;
    create(args: {
      data: {
        email: string;
        codeHash: string;
        expiresAt: Date;
      };
    }): Promise<AuthCodeRecord>;
    update(args: {
      where: {
        id: string;
      };
      data: {
        consumedAt?: Date;
        attemptCount?: number;
      };
    }): Promise<AuthCodeRecord>;
  };
  authSession: {
    findFirst(args: {
      where: {
        tokenHash?: string;
        userId?: string;
        revokedAt?: null;
      };
      include?: {
        user?: boolean;
      };
    }): Promise<(AuthSessionRecord & { user?: UserRecord }) | null>;
    create(args: {
      data: {
        userId: string;
        tokenHash: string;
        deviceLabel?: string | null;
        expiresAt: Date;
      };
    }): Promise<AuthSessionRecord>;
    update(args: {
      where: {
        id: string;
      };
      data: {
        revokedAt?: Date;
        lastUsedAt?: Date;
      };
    }): Promise<AuthSessionRecord>;
  };
  listInvitation: {
    findMany(args: {
      where: {
        email?: string;
        claimedAt?: null;
      };
    }): Promise<InvitationRecord[]>;
    findUnique(args: {
      where: {
        listId_email: {
          listId: string;
          email: string;
        };
      };
    }): Promise<InvitationRecord | null>;
    create(args: {
      data: {
        listId: string;
        email: string;
        role: 'owner' | 'editor';
        invitedByUserId: string;
      };
    }): Promise<InvitationRecord>;
    update(args: {
      where: {
        id: string;
      };
      data: {
        claimedAt?: Date;
        claimedByUserId?: string;
      };
    }): Promise<InvitationRecord>;
  };
  listMember: {
    findUnique(args: {
      where: {
        listId_userId: {
          listId: string;
          userId: string;
        };
      };
    }): Promise<unknown | null>;
    create(args: {
      data: {
        listId: string;
        userId: string;
        role: 'owner' | 'editor';
      };
    }): Promise<unknown>;
  };
};
