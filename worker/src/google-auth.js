// サービスアカウントの鍵から Google の OAuth 2.0 アクセストークンを作る。
// https://developers.google.com/identity/protocols/oauth2/service-account の
// 「HTTP/REST」の手順どおり、RS256 で署名した JWT を token エンドポイントへ送る。
// 署名は Workers の WebCrypto（RSASSA-PKCS1-v1_5 / SHA-256）で行う。
//
// 1つのトークンで Firestore と FCM の両方を呼べるよう、2つのスコープを要求する。
// トークンは1時間有効なので、KV に入れて使い回す（毎分の実行で毎回署名すると
// 無料プランの CPU 時間 10ms を無駄に使うため）。

import { base64UrlEncodeBytes } from './bytes.js';
import { callFetch } from './call-fetch.js';

export const SCOPES = [
  'https://www.googleapis.com/auth/datastore',
  'https://www.googleapis.com/auth/firebase.messaging',
];
const DEFAULT_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const CACHE_KEY = '_cache/google-access-token';
// 期限の5分前には作り直す
const REFRESH_MARGIN_MS = 5 * 60 * 1000;

// 同じ isolate の中で続けて呼ばれたときのための、メモリ上の控え
let memo = null;

export function clearMemoizedToken() {
  memo = null;
}

export function base64UrlEncode(input) {
  return base64UrlEncodeBytes(
    typeof input === 'string' ? new TextEncoder().encode(input) : new Uint8Array(input),
  );
}

function pemToDer(pem) {
  const body = pem
    .replace(/-----BEGIN [^-]+-----/, '')
    .replace(/-----END [^-]+-----/, '')
    .replace(/\s+/g, '');
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

export function parseServiceAccount(env) {
  const raw = env.GOOGLE_SERVICE_ACCOUNT;
  if (!raw) throw new Error('GOOGLE_SERVICE_ACCOUNT is not set');
  const account = JSON.parse(raw);
  if (!account.client_email || !account.private_key) {
    throw new Error('GOOGLE_SERVICE_ACCOUNT needs client_email and private_key');
  }
  return account;
}

export async function signServiceAccountJwt(account, audience, nowMillis) {
  const iat = Math.floor(nowMillis / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  if (account.private_key_id) header.kid = account.private_key_id;
  const claims = {
    iss: account.client_email,
    scope: SCOPES.join(' '),
    aud: audience,
    iat,
    exp: iat + 3600,
  };
  const unsigned = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(
    JSON.stringify(claims),
  )}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(account.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  return `${unsigned}.${base64UrlEncode(signature)}`;
}

// ctx: { env, fetch, budget, nowMillis }
export async function getAccessToken(ctx) {
  const { env, nowMillis } = ctx;
  if (memo && memo.expiresAt - REFRESH_MARGIN_MS > nowMillis) return memo.token;

  if (env.FILES) {
    const cached = await env.FILES.get(CACHE_KEY, { type: 'json' });
    if (cached && cached.token && cached.expiresAt - REFRESH_MARGIN_MS > nowMillis) {
      memo = cached;
      return cached.token;
    }
  }

  const account = parseServiceAccount(env);
  const tokenUrl = env.GOOGLE_TOKEN_URL || account.token_uri || DEFAULT_TOKEN_URL;
  const assertion = await signServiceAccountJwt(account, tokenUrl, nowMillis);
  ctx.budget.spend(1);
  const response = await callFetch(ctx, tokenUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }).toString(),
  });
  if (!response.ok) {
    throw new Error(`Google token request failed: ${response.status}`);
  }
  const data = await response.json();
  const expiresIn = Number(data.expires_in) || 3600;
  memo = { token: data.access_token, expiresAt: nowMillis + expiresIn * 1000 };
  if (env.FILES) {
    await env.FILES.put(CACHE_KEY, JSON.stringify(memo), {
      // KV の期限は60秒以上でなければならない
      expirationTtl: Math.max(60, expiresIn - REFRESH_MARGIN_MS / 1000),
    });
  }
  return memo.token;
}

// 認証エラーが返ったときに、使い回しているトークンを捨てる
export async function forgetAccessToken(env) {
  memo = null;
  if (env.FILES) await env.FILES.delete(CACHE_KEY);
}
