import crypto from 'crypto';

function getSecretKey() {
  const secret = process.env.AUTH_SECRET;
  if (!secret) {
    throw new Error('Missing AUTH_SECRET env var');
  }
  return crypto.createHash('sha256').update(secret).digest();
}

export function encryptSecret(value: string) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', getSecretKey(), iv);
  const encrypted = Buffer.concat([cipher.update(value, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${iv.toString('base64url')}.${tag.toString('base64url')}.${encrypted.toString('base64url')}`;
}

export function decryptSecret(payload: string | null | undefined) {
  if (!payload) return '';
  const [ivPart, tagPart, encPart] = payload.split('.');
  if (!ivPart || !tagPart || !encPart) return '';
  try {
    const iv = Buffer.from(ivPart, 'base64url');
    const tag = Buffer.from(tagPart, 'base64url');
    const encrypted = Buffer.from(encPart, 'base64url');
    const decipher = crypto.createDecipheriv('aes-256-gcm', getSecretKey(), iv);
    decipher.setAuthTag(tag);
    const decrypted = Buffer.concat([decipher.update(encrypted), decipher.final()]);
    return decrypted.toString('utf8');
  } catch {
    return '';
  }
}

