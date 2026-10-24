// 添付ファイルの置き場（files.js）と ID トークンの検証（id-token.js）のテスト。
import test, { beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import worker from '../src/index.js';
import { handleFileRequest, legacyKeyFromObject, fileKeyFromPath, MAX_UPLOAD_BYTES } from '../src/files.js';
import { clearKeyCache, verifyIdToken } from '../src/id-token.js';
import { FakeKV, mockFetch, jsonResponse, makeIdTokenIssuer } from './helpers.js';

const PROJECT = 'todo-app-mokuson';
const ORIGIN = 'https://todo-app-worker.example.workers.dev';
const issuer = await makeIdTokenIssuer(PROJECT);
const nowSec = () => Math.floor(Date.now() / 1000);

beforeEach(() => clearKeyCache());

function setup() {
  const env = { FIREBASE_PROJECT_ID: PROJECT, FILES: new FakeKV() };
  const fetch = mockFetch([
    {
      match: (url) => url.startsWith('https://www.googleapis.com/service_accounts/v1/jwk/securetoken'),
      respond: () => jsonResponse(200, issuer.jwks, { 'Cache-Control': 'public, max-age=20000' }),
    },
  ]);
  const call = (path, init = {}) => handleFileRequest(new Request(`${ORIGIN}${path}`, init), env, { fetch });
  return { env, fetch, call };
}

async function tokenFor(uid, extra) {
  return issuer.sign(issuer.claimsFor(uid, nowSec(), extra));
}

async function upload(call, uid, folder, bytes, type, name) {
  const headers = { Authorization: `Bearer ${await tokenFor(uid)}`, 'Content-Type': type, 'Content-Length': String(bytes.length) };
  if (name) headers['X-File-Name'] = encodeURIComponent(name);
  return call(`/upload/${folder}`, { method: 'POST', headers, body: bytes });
}

const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4]);
const PDF = new TextEncoder().encode('%PDF-1.7 test');

test('アップロードして、返った URL で読み出せる（画像）', async () => {
  const { env, call } = setup();
  const res = await upload(call, 'uidA', 'todos/123', JPEG, 'image/jpeg');
  assert.equal(res.status, 201);
  const { url } = await res.json();
  assert.match(url, new RegExp(`^${ORIGIN}/f/uidA/todos/123/[A-Za-z0-9_-]{22}$`));
  const key = url.slice(ORIGIN.length + 1);
  assert.deepEqual(env.FILES.store.get(key).metadata, { contentType: 'image/jpeg', fileName: '' });

  const get = await call(new URL(url).pathname);
  assert.equal(get.status, 200);
  assert.deepEqual(new Uint8Array(await get.arrayBuffer()), JPEG);
  assert.equal(get.headers.get('Content-Type'), 'image/jpeg');
  assert.equal(get.headers.get('Cache-Control'), 'private, max-age=31536000, immutable');
  assert.equal(get.headers.get('Access-Control-Allow-Origin'), '*');
  assert.equal(get.headers.get('X-Content-Type-Options'), 'nosniff');
});

test('PDF は元のファイル名（日本語も）で開ける', async () => {
  const { call } = setup();
  const res = await upload(call, 'uidA', 'todos/5', PDF, 'application/pdf', '見積書 "最終".pdf');
  const { url } = await res.json();
  const get = await call(new URL(url).pathname);
  assert.equal(get.headers.get('Content-Type'), 'application/pdf');
  assert.equal(
    get.headers.get('Content-Disposition'),
    `inline; filename="___ __.pdf"; filename*=UTF-8''${encodeURIComponent('見積書 最終.pdf')}`,
  );
});

test('問い合わせの添付も同じ口で置ける', async () => {
  const { call } = setup();
  const res = await upload(call, 'uidB', 'inquiries', PDF, 'application/pdf', 'a.pdf');
  assert.equal(res.status, 201);
  const { url } = await res.json();
  assert.match(url, /\/f\/uidB\/inquiries\/[A-Za-z0-9_-]{22}$/);
  assert.equal((await call(new URL(url).pathname)).status, 200);
});

test('ID トークンが無い・壊れている・別プロジェクト・期限切れならアップロードできない', async () => {
  const { env, call } = setup();
  const post = (auth) =>
    call('/upload/todos/1', {
      method: 'POST',
      headers: { ...(auth ? { Authorization: auth } : {}), 'Content-Type': 'image/jpeg', 'Content-Length': String(JPEG.length) },
      body: JPEG,
    });
  assert.equal((await post(null)).status, 401);
  assert.equal((await post('Bearer abc.def.ghi')).status, 401);
  const otherProject = await issuer.sign(issuer.claimsFor('uidA', nowSec(), { aud: 'other', iss: 'https://securetoken.google.com/other' }));
  assert.equal((await post(`Bearer ${otherProject}`)).status, 401);
  const expired = await issuer.sign(issuer.claimsFor('uidA', nowSec(), { exp: nowSec() - 1 }));
  assert.equal((await post(`Bearer ${expired}`)).status, 401);
  const other = await issuer.generateOtherKey();
  const forged = await issuer.sign(issuer.claimsFor('uidA', nowSec()), { key: other.privateKey });
  assert.equal((await post(`Bearer ${forged}`)).status, 401);
  const none = await issuer.sign(issuer.claimsFor('uidA', nowSec()), { headerOverride: { alg: 'none' } });
  assert.equal((await post(`Bearer ${none}`)).status, 401);
  assert.equal(env.FILES.store.size, 0);
});

test('種類・大きさ・置き場所が正しくないものは受け付けない', async () => {
  const { env, call } = setup();
  const auth = `Bearer ${await tokenFor('uidA')}`;
  const html = new TextEncoder().encode('<script>');
  assert.equal((await upload(call, 'uidA', 'todos/1', html, 'text/html')).status, 415);
  const tooLarge = await call('/upload/todos/1', {
    method: 'POST',
    headers: { Authorization: auth, 'Content-Type': 'application/pdf', 'Content-Length': String(MAX_UPLOAD_BYTES + 1) },
  });
  assert.equal(tooLarge.status, 413);
  assert.equal((await upload(call, 'uidA', 'todos/abc', JPEG, 'image/jpeg')).status, 404);
  assert.equal((await upload(call, 'uidA', 'other', JPEG, 'image/jpeg')).status, 404);
  assert.equal(env.FILES.store.size, 0);
});

test('削除は本人のファイルだけ', async () => {
  const { env, call } = setup();
  const { url } = await (await upload(call, 'uidA', 'todos/9', JPEG, 'image/jpeg')).json();
  const path = new URL(url).pathname;
  const byOther = await call(path, { method: 'DELETE', headers: { Authorization: `Bearer ${await tokenFor('uidB')}` } });
  assert.equal(byOther.status, 403);
  assert.equal(env.FILES.store.size, 1);
  const noAuth = await call(path, { method: 'DELETE' });
  assert.equal(noAuth.status, 401);
  const byOwner = await call(path, { method: 'DELETE', headers: { Authorization: `Bearer ${await tokenFor('uidA')}` } });
  assert.equal(byOwner.status, 204);
  assert.equal(env.FILES.store.size, 0);
  const gone = await call(path);
  assert.equal(gone.status, 404);
  assert.equal(gone.headers.get('Cache-Control'), 'no-store');
});

test('タスクの添付はまとめて消せる（他のタスク・他の人の分は残る）', async () => {
  const { env, call } = setup();
  for (let i = 0; i < 3; i++) await upload(call, 'uidA', 'todos/10', JPEG, 'image/jpeg');
  await upload(call, 'uidA', 'todos/100', JPEG, 'image/jpeg');
  await upload(call, 'uidB', 'todos/10', JPEG, 'image/jpeg');
  const res = await call('/folder/todos/10', { method: 'DELETE', headers: { Authorization: `Bearer ${await tokenFor('uidA')}` } });
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { deleted: 3 });
  const left = [...env.FILES.store.keys()].sort();
  assert.equal(left.length, 2);
  assert.ok(left.some((k) => k.startsWith('f/uidA/todos/100/')));
  assert.ok(left.some((k) => k.startsWith('f/uidB/todos/10/')));
});

test('形のおかしいパスや知らない口は 404 / 405、OPTIONS は CORS を返す', async () => {
  const { call } = setup();
  assert.equal((await call('/f/uidA/todos/1/short')).status, 404);
  assert.equal((await call('/f/../x')).status, 404);
  assert.equal((await call('/nothing')).status, 404);
  assert.equal((await call('/upload/todos/1')).status, 405);
  const pre = await call('/upload/todos/1', { method: 'OPTIONS' });
  assert.equal(pre.status, 204);
  assert.match(pre.headers.get('Access-Control-Allow-Headers'), /Authorization/);
});

test('公開鍵はキャッシュし、知らない kid のときだけ取り直す', async () => {
  const { fetch, call } = setup();
  await upload(call, 'uidA', 'todos/1', JPEG, 'image/jpeg');
  await upload(call, 'uidA', 'todos/1', JPEG, 'image/jpeg');
  assert.equal(fetch.calls.length, 1);
  const unknownKid = await issuer.sign(issuer.claimsFor('uidA', nowSec()), { headerOverride: { kid: 'rotated' } });
  const env = { FIREBASE_PROJECT_ID: PROJECT };
  assert.equal(await verifyIdToken(unknownKid, env, { fetch }), null);
  assert.equal(fetch.calls.length, 2);
});

test('旧 Storage のオブジェクトは、ダウンロードトークンを ID にしたキーへ移す', () => {
  const token = '3f2c1d4e-5a6b-4c7d-8e9f-0a1b2c3d4e5f';
  assert.equal(legacyKeyFromObject('users/uidA/todos/123/1720000000000000_0.jpg', token), `f/uidA/todos/123/${token}`);
  assert.equal(legacyKeyFromObject('users/uidA/inquiries/1720000000000000_0.pdf', token), `f/uidA/inquiries/${token}`);
  assert.equal(legacyKeyFromObject('users/uidA/todos/abc/x.jpg', token), null);
  assert.equal(legacyKeyFromObject('other/uidA/todos/1/x.jpg', token), null);
  assert.equal(legacyKeyFromObject('users/uidA/todos/1/x.jpg', 'short'), null);
  // 移したキーは、そのまま読み出しの URL で引ける
  assert.deepEqual(fileKeyFromPath(`uidA/todos/123/${token}`), { uid: 'uidA', key: `f/uidA/todos/123/${token}` });
});

test('Worker の fetch ハンドラーから添付の口につながる', async () => {
  const env = { FIREBASE_PROJECT_ID: PROJECT, FILES: new FakeKV() };
  const res = await worker.fetch(new Request(`${ORIGIN}/f/uidA/todos/1/AAAAAAAAAAAAAAAAAAAAAA`), env);
  assert.equal(res.status, 404);
});
