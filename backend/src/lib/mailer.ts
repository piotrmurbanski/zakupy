type SendAuthCodeParams = {
  email: string;
  code: string;
};

export type Mailer = {
  sendAuthCode(params: SendAuthCodeParams): Promise<void>;
};

export function createMailer(): Mailer {
  return {
    async sendAuthCode({ email, code }) {
      console.log(`[mailer] auth code for ${email}: ${code}`);
    },
  };
}

export const defaultMailer = createMailer();
