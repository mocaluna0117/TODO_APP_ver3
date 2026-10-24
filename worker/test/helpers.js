// テスト用の部品: KV の代わり、fetch の差し替え、鍵の生成。
// 本物の Google / Cloudflare には一切つながない。
import { base64UrlEncodeBytes } from '../src/bytes.js';

export class FakeKV {
  constructor() {
    this.store = new Map();
    this.ops = { get: 0, put: 0, delete: 0, list: 0 };
  }
  async put(key, value, options = {}) {
    this.ops.put++;
    let bytes;
    if (typeof value === 'string') bytes = new TextEncoder().encode(value);
    else if (value instanceof ArrayBuffer) bytes = new Uint8Array(value);
    else if (ArrayBuffer.isView(value)) bytes = new Uint8Array(value.buffer, value.byteOffset, value.byteLength);
    else bytes = new Uint8Array(await new Response(value).arrayBuffer());
    this.store.set(key, { bytes, metadata: options.metadata ?? null, options });
  }
  async get(key, options = {}) {
    this.ops.get++;
    const item = this.store.get(key);
    if (!item) return null;
    const type = typeof options === 'string' ? options : options.type || 'text';
    const text = () => new TextDecoder().decode(item.bytes);
    if (type === 'json') return JSON.parse(text());
    if (type === 'arrayBuffer') return item.bytes.slice().buffer;
    if (type === 'stream') return new Response(item.bytes).body;
    return text();
  }
  async getWithMetadata(key, options = {}) {
    const item = this.store.get(key);
    const value = await this.get(key, options);
    return { value, metadata: item ? item.metadata : null };
  }
  async delete(key) {
    this.ops.delete++;
    this.store.delete(key);
  }
  async list({ prefix = '', cursor } = {}) {
    this.ops.list++;
    // 本物と同じく、カーソルは「最後に返したキーの次から」を表す
    const names = [...this.store.keys()]
      .filter((k) => k.startsWith(prefix) && (!cursor || k > cursor))
      .sort();
    const page = names.slice(0, 2); // ページ送りも試せるよう小さく切る
    const complete = page.length === names.length;
    return {
      keys: page.map((name) => ({ name })),
      list_complete: complete,
      cursor: complete ? undefined : page[page.length - 1],
    };
  }
}

// routes: [{ match: (url, init) => bool, respond: (url, init, body) => Response }]
export function mockFetch(routes) {
  const calls = [];
  // workerd と同じく、メソッドとして（this 付きで）呼ばれたら失敗させる
  const fn = async function (input, init = {}) {
    if (this !== undefined && this !== globalThis) {
      throw new TypeError('Illegal invocation: function called with incorrect `this` reference.');
    }
    const url = typeof input === 'string' ? input : input.url;
    const body = init.body === undefined ? undefined : String(init.body);
    calls.push({ url, method: init.method || 'GET', headers: init.headers || {}, body });
    for (const route of routes) {
      if (route.match(url, init)) return route.respond(url, init, body);
    }
    throw new Error(`unexpected fetch: ${init.method || 'GET'} ${url}`);
  };
  fn.calls = calls;
  return fn;
}

export function jsonResponse(status, body, headers = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...headers },
  });
}

async function generateRsa() {
  return crypto.subtle.generateKey(
    {
      name: 'RSASSA-PKCS1-v1_5',
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: 'SHA-256',
    },
    true,
    ['sign', 'verify'],
  );
}

function toPem(der, label) {
  const b64 = Buffer.from(der).toString('base64').replace(/(.{64})/g, '$1\n');
  return `-----BEGIN ${label}-----\n${b64}\n-----END ${label}-----\n`;
}

// テスト専用のサービスアカウント（その場で作る使い捨ての鍵）
export async function makeServiceAccount() {
  const pair = await generateRsa();
  const pkcs8 = await crypto.subtle.exportKey('pkcs8', pair.privateKey);
  const json = JSON.stringify({
    type: 'service_account',
    project_id: 'test-project',
    private_key_id: 'test-key-id',
    private_key: toPem(pkcs8, 'PRIVATE KEY'),
    client_email: 'notifier@test-project.iam.gserviceaccount.com',
  });
  return { json, publicKey: pair.publicKey };
}

export async function verifyJwt(jwt, publicKey) {
  const [h, p, s] = jwt.split('.');
  const decode = (part) =>
    Buffer.from(part.replace(/-/g, '+').replace(/_/g, '/'), 'base64');
  const ok = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    publicKey,
    decode(s),
    new TextEncoder().encode(`${h}.${p}`),
  );
  return { ok, header: JSON.parse(decode(h)), claims: JSON.parse(decode(p)) };
}

// Firebase の ID トークンの代わり（securetoken の鍵の代わりに使い捨ての鍵で署名）
export async function makeIdTokenIssuer(projectId) {
  const pair = await generateRsa();
  const jwk = await crypto.subtle.exportKey('jwk', pair.publicKey);
  const kid = 'test-kid';
  const jwks = { keys: [{ ...jwk, kid, alg: 'RS256', use: 'sig' }] };
  const enc = (obj) => base64UrlEncodeBytes(new TextEncoder().encode(JSON.stringify(obj)));
  async function sign(claims, { headerOverride = {}, key = pair.privateKey } = {}) {
    const header = { alg: 'RS256', kid, typ: 'JWT', ...headerOverride };
    const unsigned = `${enc(header)}.${enc(claims)}`;
    const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned));
    return `${unsigned}.${base64UrlEncodeBytes(new Uint8Array(sig))}`;
  }
  function claimsFor(uid, nowSec, extra = {}) {
    return {
      iss: `https://securetoken.google.com/${projectId}`,
      aud: projectId,
      auth_time: nowSec - 60,
      sub: uid,
      iat: nowSec - 30,
      exp: nowSec + 3600,
      ...extra,
    };
  }
  return { jwks, sign, claimsFor, generateOtherKey: generateRsa };
}
