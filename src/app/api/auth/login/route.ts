import { cookies } from 'next/headers';
import { NextResponse } from 'next/server';
import { createSessionToken, getAuthCredentials } from '@/lib/auth';

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const username = String(body?.username || '').trim();
    const password = String(body?.password || '');
    const creds = getAuthCredentials();

    if (!creds.username || !creds.password) {
      return NextResponse.json(
        { error: 'Missing AUTH_USERNAME/AUTH_PASSWORD in env' },
        { status: 500 }
      );
    }

    if (username !== creds.username || password !== creds.password) {
      return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });
    }

    const token = createSessionToken(username);
    cookies().set('stacker_auth', token, {
      httpOnly: true,
      sameSite: 'lax',
      secure: process.env.NODE_ENV === 'production',
      path: '/',
      maxAge: 7 * 24 * 60 * 60,
    });

    return NextResponse.json({ success: true });
  } catch {
    return NextResponse.json({ error: 'Invalid request body' }, { status: 400 });
  }
}

