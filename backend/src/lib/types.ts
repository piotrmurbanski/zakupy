export type UserRecord = {
  id: string;
  email: string;
  passwordHash: string;
  displayName: string;
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
        passwordHash: string;
        displayName: string;
      };
    }): Promise<UserRecord>;
  };
};
