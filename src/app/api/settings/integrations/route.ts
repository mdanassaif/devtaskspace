import { cookies } from 'next/headers';
import { NextResponse } from 'next/server';
import { verifySessionToken } from '@/lib/auth';
import {
  getUserIntegrationSettings,
  saveUserIntegrationSettings,
  type IntegrationSettings,
} from '@/lib/user-integrations';

function getSessionUsername() {
  const token = cookies().get('stacker_auth')?.value;
  const session = verifySessionToken(token);
  return session?.username || null;
}

export async function GET() {
  const username = getSessionUsername();
  if (!username) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    const settings = await getUserIntegrationSettings(username);
    return NextResponse.json({
      settings: {
        resendApiKey: settings.resendApiKey ? '********' : '',
        alertEmail: settings.alertEmail,
        fromEmail: settings.fromEmail,
      },
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Failed to load settings';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

export async function PUT(req: Request) {
  const username = getSessionUsername();
  if (!username) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  let body: Partial<IntegrationSettings>;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid request body' }, { status: 400 });
  }

  const clean: IntegrationSettings = {
    resendApiKey: String(body.resendApiKey || '').trim(),
    alertEmail: String(body.alertEmail || '').trim(),
    fromEmail: String(body.fromEmail || '').trim(),
  };

  try {
    const prev = await getUserIntegrationSettings(username);
    await saveUserIntegrationSettings(username, {
      resendApiKey: clean.resendApiKey || prev.resendApiKey,
      alertEmail: clean.alertEmail || prev.alertEmail,
      fromEmail: clean.fromEmail || prev.fromEmail,
    });
    return NextResponse.json({ success: true });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Failed to save settings';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

