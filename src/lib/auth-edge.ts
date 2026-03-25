type SessionPayload = {
  username: string;
  exp: number;
};

function decodeBase64Url(input: string): string {
  const normalized = input.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=');
  return atob(padded);
}

function encodeBase64Url(bytes: ArrayBuffer): string {
  const view = new Uint8Array(bytes);
  let binary = '';
  for (let index = 0; index < view.length; index += 1) {
    binary += String.fromCharCode(view[index]);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

export async function verifySessionTokenEdge(
  token: string | undefined | null,
  secret: string | undefined
): Promise<SessionPayload | null> {
  if (!token || !secret || !globalThis.crypto?.subtle) {
    return null;
  }

  const [encodedPayload, signature] = token.split('.');
  if (!encodedPayload || !signature) {
    return null;
  }

  try {
    const key = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(secret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    );
    const expected = await crypto.subtle.sign(
      'HMAC',
      key,
      new TextEncoder().encode(encodedPayload)
    );

    if (encodeBase64Url(expected) !== signature) {
      return null;
    }

    const payload = JSON.parse(decodeBase64Url(encodedPayload)) as SessionPayload;
    if (!payload.username || !payload.exp || Date.now() > payload.exp) {
      return null;
    }

    return payload;
  } catch {
    return null;
  }
}
