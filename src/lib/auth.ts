import crypto from 'crypto';

const SESSION_TTL_MS = 7 * 24 * 60 * 60 * 1000;

type SessionPayload = {
  username: string;
  exp: number;
};

function toBase64Url(input: string): string {
  return Buffer.from(input).toString('base64url');
}

function fromBase64Url(input: string): string {
  return Buffer.from(input, 'base64url').toString('utf8');
}

function getAuthSecret(): string {
  const secret = process.env.AUTH_SECRET;
  if (!secret) {
    throw new Error('Missing AUTH_SECRET env var');
  }
  return secret;
}

export function getAuthCredentials() {
  return {
    username: process.env.AUTH_USERNAME || '',
    password: process.env.AUTH_PASSWORD || '',
  };
}

export function createSessionToken(username: string): string {
  const payload: SessionPayload = { username, exp: Date.now() + SESSION_TTL_MS };
  const encodedPayload = toBase64Url(JSON.stringify(payload));
  const signature = crypto
    .createHmac('sha256', getAuthSecret())
    .update(encodedPayload)
    .digest('base64url');
  return `${encodedPayload}.${signature}`;
}

export function verifySessionToken(token: string | undefined | null): SessionPayload | null {
  if (!token) return null;
  const [encodedPayload, signature] = token.split('.');
  if (!encodedPayload || !signature) return null;

  const expectedSig = crypto
    .createHmac('sha256', getAuthSecret())
    .update(encodedPayload)
    .digest('base64url');

  if (signature !== expectedSig) return null;

  try {
    const payload = JSON.parse(fromBase64Url(encodedPayload)) as SessionPayload;
    if (!payload.username || !payload.exp) return null;
    if (Date.now() > payload.exp) return null;
    return payload;
  } catch {
    return null;
  }
}

