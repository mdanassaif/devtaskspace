import { Resend } from 'resend';
import { cookies } from 'next/headers';
import { NextResponse } from 'next/server';
import { verifySessionToken } from '@/lib/auth';
import { addEmailLog, findEmailLogByResendId, listEmailLogs } from '@/lib/email-log-store';
import { getUserIntegrationSettings } from '@/lib/user-integrations';

type SendEmailBody = {
  to?: string;
  subject?: string;
  text?: string;
  resendEmailId?: string;
};

function getResendClient(key?: string) {
  if (!key) return null;
  return new Resend(key);
}

export async function GET() {
  const token = cookies().get('stacker_auth')?.value;
  if (!verifySessionToken(token)) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }
  return NextResponse.json({ logs: listEmailLogs() });
}

export async function POST(req: Request) {
  const token = cookies().get('stacker_auth')?.value;
  const session = verifySessionToken(token);
  if (!session) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  let body: SendEmailBody;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid request body' }, { status: 400 });
  }

  const userSettings = await getUserIntegrationSettings(session.username);
  const resend = getResendClient(userSettings.resendApiKey || process.env.RESEND_API_KEY);
  if (!resend) {
    return NextResponse.json({ error: 'Missing Resend key' }, { status: 500 });
  }

  const defaultTo = userSettings.alertEmail || process.env.ALERT_EMAIL;
  const from = userSettings.fromEmail || process.env.FROM_EMAIL;
  if (!defaultTo || !from) {
    return NextResponse.json({ error: 'Missing alert or from email (Settings/.env)' }, { status: 500 });
  }

  let to = body.to || defaultTo;
  let subject = body.subject || 'Stacker Alert';
  let text = body.text || 'No message body provided.';

  if (body.resendEmailId) {
    const oldLog = findEmailLogByResendId(body.resendEmailId);
    if (!oldLog) {
      return NextResponse.json({ error: 'Email to resend not found' }, { status: 404 });
    }
    to = oldLog.to;
    subject = oldLog.subject;
    text = oldLog.text;
  }

  try {
    const result = await resend.emails.send({
      from,
      to,
      subject,
      text,
    });

    addEmailLog({
      id: crypto.randomUUID(),
      to,
      subject,
      text,
      status: 'sent',
      sentAt: new Date().toISOString(),
      resendId: result.data?.id || undefined,
    });

    return NextResponse.json({ success: true, id: result.data?.id });
  } catch (error: unknown) {
    addEmailLog({
      id: crypto.randomUUID(),
      to,
      subject,
      text,
      status: 'failed',
      sentAt: new Date().toISOString(),
    });
    const message = error instanceof Error ? error.message : 'Email send failed';
    return NextResponse.json({ success: false, error: message }, { status: 500 });
  }
}

