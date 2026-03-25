import { cookies } from 'next/headers';
import { NextResponse } from 'next/server';
import { verifySessionToken } from '@/lib/auth';

export async function GET() {
  const token = cookies().get('stacker_auth')?.value;
  const session = verifySessionToken(token);
  if (!session) {
    return NextResponse.json({ authenticated: false }, { status: 401 });
  }
  return NextResponse.json({ authenticated: true, username: session.username });
}

