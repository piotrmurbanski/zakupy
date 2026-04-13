import nodemailer, { type Transporter } from 'nodemailer';

import { env } from '../config/env.js';

type SendAuthCodeParams = {
  email: string;
  code: string;
};

export type Mailer = {
  sendAuthCode(params: SendAuthCodeParams): Promise<void>;
};

function buildTransporter(): Transporter | null {
  if (!env.SMTP_HOST || !env.SMTP_FROM) {
    return null;
  }

  return nodemailer.createTransport({
    host: env.SMTP_HOST,
    port: env.SMTP_PORT,
    secure: env.SMTP_SECURE,
    auth:
      env.SMTP_USER && env.SMTP_PASSWORD
          ? {
              user: env.SMTP_USER,
              pass: env.SMTP_PASSWORD,
            }
          : undefined,
  });
}

function buildHtmlParagraphs(lines: string[]) {
  return lines.map((line) => `<p>${line}</p>`).join('');
}

export function createMailer(): Mailer {
  const transporter = buildTransporter();
  const from = env.SMTP_FROM;

  if (!transporter || !from) {
    return {
      async sendAuthCode({ email, code }) {
        console.info(`[auth] Sign-in code for ${email}: ${code}`);
      },
    };
  }

  return {
    async sendAuthCode({ email, code }) {
      await transporter.sendMail({
        from,
        to: email,
        subject: 'Listek sign-in code',
        text: `Your Listek sign-in code is: ${code}`,
        html: buildHtmlParagraphs([
          'Your Listek sign-in code is:',
          `<strong>${code}</strong>`,
        ]),
      });
    },
  };
}

export const defaultMailer = createMailer();
