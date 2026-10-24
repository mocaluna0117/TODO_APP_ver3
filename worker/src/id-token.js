// Firebase Authentication の ID トークンを検証する。
// https://firebase.google.com/docs/auth/admin/verify-id-tokens の
// 「Verify ID tokens using a third-party JWT library」の条件どおりに確かめる。
// 公開鍵は同じ鍵を JWK 形式で配っている securetoken の JWK エンドポイントから取る
// （WebCrypto は X.509 証明書を直接読み込めないため）。
import { base64UrlDecodeToBytes } from './bytes.js';

const DEFAULT_JWK_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
// 時計のずれの許容
const CLOCK_SKEW_SECONDS = 300;

let keyCache = { url: null, keys: new Map(), expiresAt: 0 };

export function clearKeyCache() {
  keyCache = { url: null, keys: new Map(), expiresAt: 0 };
}

function maxAgeSeconds(cacheControl) {
  const match = /max-age=(\d+)/.exec(cacheControl || '');
  return match ? Number(match[1]) : 3600;
}

async function loadKeys(env, fetchImpl, nowMillis) {
  const url = env.SECURETOKEN_JWK_URL || DEFAULT_JWK_URL;
  const response = await fetchImpl(url);
  if (!response.ok) throw new Error(`JWK fetch failed: ${response.status}`);
  const data = await response.json();
  const keys = new Map();
  for (const jwk of data.keys || []) {
    if (!jwk.kid) continue;
    keys.set(
      jwk.kid,
      await crypto.subtle.importKey(
        'jwk',
        { kty: jwk.kty, n: jwk.n, e: jwk.e, alg: 'RS256', ext: true },
        { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
        false,
        ['verify'],
      ),
    );
  }
  keyCache = {
    url,
    keys,
    expiresAt: nowMillis + maxAgeSeconds(response.headers.get('Cache-Control')) * 1000,
  };
}

async function keyFor(kid, env, fetchImpl, nowMillis) {
  const url = env.SECURETOKEN_JWK_URL || DEFAULT_JWK_URL;
  const fresh = keyCache.url === url && keyCache.expiresAt > nowMillis;
  if (!fresh || !keyCache.keys.has(kid)) {
    await loadKeys(env, fetchImpl, nowMillis);
  }
  return keyCache.keys.get(kid) || null;
}

function decodeJson(part) {
  return JSON.parse(new TextDecoder().decode(base64UrlDecodeToBytes(part)));
}

// 正しければ uid（sub）を返す。正しくなければ null。
export async function verifyIdToken(token, env, { fetch: fetchImpl, nowMillis = Date.now() }) {
  if (typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  let header;
  let payload;
  try {
    header = decodeJson(parts[0]);
    payload = decodeJson(parts[1]);
  } catch (_) {
    return null;
  }
  const projectId = env.FIREBASE_PROJECT_ID;
  const now = Math.floor(nowMillis / 1000);
  if (header.alg !== 'RS256' || typeof header.kid !== 'string') return null;
  if (payload.aud !== projectId) return null;
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) return null;
  if (typeof payload.sub !== 'string' || payload.sub.length === 0 || payload.sub.length > 128) {
    return null;
  }
  if (typeof payload.exp !== 'number' || payload.exp <= now) return null;
  if (typeof payload.iat !== 'number' || payload.iat > now + CLOCK_SKEW_SECONDS) return null;
  if (typeof payload.auth_time !== 'number' || payload.auth_time > now + CLOCK_SKEW_SECONDS) {
    return null;
  }
  const key = await keyFor(header.kid, env, fetchImpl, nowMillis);
  if (!key) return null;
  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    base64UrlDecodeToBytes(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  return valid ? payload.sub : null;
}
