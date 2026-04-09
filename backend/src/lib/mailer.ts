import nodemailer, { type Transporter } from 'nodemailer';

import { env } from '../config/env.js';

type SendAuthCodeParams = {
  email: string;
  code: string;
};

type SendListInvitationParams = {
  email: string;
  listName: string;
  invitedByDisplayName: string;
  invitedByEmail: string;
};

export type Mailer = {
  sendAuthCode(params: SendAuthCodeParams): Promise<void>;
  sendListInvitation(params: SendListInvitationParams): Promise<void>;
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
      async sendListInvitation({
        email,
        listName,
        invitedByDisplayName,
        invitedByEmail,
      }) {
        console.info(
          `[lists] Invitation for ${email} to join "${listName}" from ${invitedByDisplayName} <${invitedByEmail}>`,
        );
      },
    };
  }

  return {
    async sendAuthCode({ email, code }) {
      await transporter.sendMail({
        from,
        to: email,
        subject: 'Zakupy sign-in code',
        text: `Your Zakupy sign-in code is: ${code}`,
        html: buildHtmlParagraphs([
          'Your Zakupy sign-in code is:',
          `<strong>${code}</strong>`,
        ]),
      });
    },
    async sendListInvitation({
      email,
      listName,
      invitedByDisplayName,
      invitedByEmail,
    }) {
      await transporter.sendMail({
        from,
        to: email,
        subject: `${invitedByDisplayName} invited you to a Zakupy list`,
        text: [
          `${invitedByDisplayName} (${invitedByEmail}) invited you to share the list "${listName}".`,
          'Open the Zakupy app, sign in with this email address, then accept the invitation from the Invitations screen.',
        ].join('\n\n'),
        html: buildHtmlParagraphs([
          `${invitedByDisplayName} (${invitedByEmail}) invited you to share the list "${listName}".`,
          'Open the Zakupy app, sign in with this email address, then accept the invitation from the Invitations screen.',
        ]),
      });
    },
  };
}

export const defaultMailer = createMailer();
