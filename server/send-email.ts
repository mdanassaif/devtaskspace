import type { NextApiRequest, NextApiResponse } from 'next';
import { Resend } from 'resend';

const resend = new Resend(process.env.RESEND_API_KEY);

interface EmailLog {
  id: string;
  to: string;
  subject: string;
  text: string;
  status: 'sent' | 'failed';
  sentAt: string;
  resendId?: string;
}

// In-memory log (replace with DB in production)
const emailLogs: EmailLog[] = [];

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method === 'GET') {
    // Return email logs
    return res.status(200).json({ logs: emailLogs });
  }

  if (req.method === 'POST') {
    const { subject, text, to, resendEmailId } = req.body;

    const recipient = to || process.env.ALERT_EMAIL || 'danish@example.com';

    // Resend: if resendEmailId is provided, use resend API
    if (resendEmailId) {
      try {
        // Note: Resend doesn't have a native "resend" API,
        // so we re-send with the original subject + body from logs
        const original = emailLogs.find(l => l.resendId === resendEmailId);
        if (!original) return res.status(404).json({ error: 'Original email not found' });

        const { data, error } = await resend.emails.send({
          from: process.env.FROM_EMAIL || 'Stacker <alerts@yourdomain.com>',
          to: [original.to],
          subject: `[Resent] ${original.subject}`,
          text: original.text,
        });

        if (error) throw error;

        const log: EmailLog = {
          id: Math.random().toString(36).slice(2),
          to: original.to,
          subject: `[Resent] ${original.subject}`,
          text: original.text,
          status: 'sent',
          sentAt: new Date().toISOString(),
          resendId: data?.id,
        };
        emailLogs.unshift(log);
        return res.status(200).json({ success: true, id: data?.id, log });
      } catch (err) {
        return res.status(500).json({ success: false, error: String(err) });
      }
    }

    // Normal send
    try {
      const { data, error } = await resend.emails.send({
        from: process.env.FROM_EMAIL || 'Stacker <alerts@yourdomain.com>',
        to: [recipient],
        subject: subject || 'Stacker Alert',
        html: `
          <div style="font-family: 'Poppins', sans-serif; max-width: 520px; margin: 0 auto; padding: 32px; background: #ffffff; border: 1px solid #E8E8E4; border-radius: 12px;">
            <div style="margin-bottom: 24px;">
              <div style="display: inline-flex; align-items: center; gap: 8px; background: #F7F7F5; border: 1px solid #E8E8E4; border-radius: 8px; padding: 8px 12px;">
                <span style="font-size: 14px; font-weight: 600; color: #1C1C1E;">Stacker</span>
              </div>
            </div>
            <h2 style="font-size: 16px; font-weight: 600; color: #1C1C1E; margin: 0 0 12px 0;">${subject}</h2>
            <div style="background: #F7F7F5; border-radius: 8px; padding: 16px; font-size: 13px; color: #3C3C3E; line-height: 1.7; white-space: pre-wrap;">${text}</div>
            <p style="font-size: 11px; color: #8C8C8C; margin-top: 24px;">Sent from your Stacker workspace.</p>
          </div>
        `,
        text: text,
      });

      if (error) throw error;

      const log: EmailLog = {
        id: Math.random().toString(36).slice(2),
        to: recipient,
        subject: subject || 'Stacker Alert',
        text: text || '',
        status: 'sent',
        sentAt: new Date().toISOString(),
        resendId: data?.id,
      };
      emailLogs.unshift(log);

      return res.status(200).json({ success: true, id: data?.id, log });
    } catch (err) {
      const log: EmailLog = {
        id: Math.random().toString(36).slice(2),
        to: recipient,
        subject: subject || 'Stacker Alert',
        text: text || '',
        status: 'failed',
        sentAt: new Date().toISOString(),
      };
      emailLogs.unshift(log);
      console.error('Resend error:', err);
      return res.status(500).json({ success: false, error: String(err) });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
