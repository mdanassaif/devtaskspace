import { cookies } from 'next/headers';
import { NextResponse } from 'next/server';

export async function POST() {
  cookies().set('stacker_auth', '', {
    httpOnly: true,
    sameSite: 'lax',
    secure: process.env.NODE_ENV === 'production',
    path: '/',
    maxAge: 0,
  });

  return NextResponse.json({ success: true });
}

