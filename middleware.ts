import { NextRequest, NextResponse } from 'next/server';
import { verifySessionTokenEdge } from '@/lib/auth-edge';

const PUBLIC_PATHS = ['/login'];

export async function middleware(req: NextRequest) {
  const { pathname, search } = req.nextUrl;

  if (
    pathname.startsWith('/_next') ||
    pathname.startsWith('/favicon.ico') ||
    pathname.startsWith('/public') ||
    pathname.startsWith('/api')
  ) {
    return NextResponse.next();
  }

  const isPublic = PUBLIC_PATHS.some(path => pathname === path || pathname.startsWith(`${path}/`));
  if (isPublic) {
    return NextResponse.next();
  }

  const token = req.cookies.get('stacker_auth')?.value;
  const session = await verifySessionTokenEdge(token, process.env.AUTH_SECRET);
  if (session) {
    return NextResponse.next();
  }

  const url = req.nextUrl.clone();
  url.pathname = '/login';
  url.searchParams.set('next', `${pathname}${search}`);
  const response = NextResponse.redirect(url);
  if (token) {
    response.cookies.set('stacker_auth', '', {
      httpOnly: true,
      sameSite: 'lax',
      secure: process.env.NODE_ENV === 'production',
      path: '/',
      maxAge: 0,
    });
  }
  return response;
}

export const config = {
  matcher: ['/((?!.*\\..*).*)'],
};
