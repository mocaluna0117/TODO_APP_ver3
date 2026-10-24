// 添付ファイル（タスクの画像・PDF、問い合わせの添付）の置き場。
// 実体は Workers KV に置き、この Worker が出し入れする。
//
//   POST   /upload/todos/{taskId}       … 1件アップロード（要 ID トークン）→ { url }
//   POST   /upload/inquiries            … 問い合わせの添付（要 ID トークン）→ { url }
//   GET    /f/{uid}/todos/{taskId}/{id} … 読み出し（URL を知っている人だけが読める）
//   GET    /f/{uid}/inquiries/{id}
//   DELETE /f/{uid}/...                 … 1件削除（要 ID トークン・本人のみ）
//   DELETE /folder/todos/{taskId}       … タスクの添付をまとめて削除（要 ID トークン）
//
// 読み出しは Firebase Storage のダウンロード URL と同じ考え方で、URL に
// 推測できない ID（128 ビット）を入れ、URL を知っていることを読む権限とする。
// こうすると Web の Image.network や外部ブラウザで PDF を開く経路（どちらも
// Authorization ヘッダーを付けられない）が、今までどおり URL だけで動く。
import { verifyIdToken } from './id-token.js';
import { randomId } from './bytes.js';

// アプリ側の kMaxAttachmentBytes（20MB）と同じ。KV の1件の上限は 25 MiB。
export const MAX_UPLOAD_BYTES = 20 * 1024 * 1024;
export const ALLOWED_CONTENT_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
  'application/pdf',
]);
// パスは毎回一意で中身は変わらないので、端末のキャッシュに長く置いてよい。
// URL が読む権限そのものなので、共有キャッシュには置かせない（private）。
export const FILE_CACHE_CONTROL = 'private, max-age=31536000, immutable';

const UID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;
const TASK_ID_PATTERN = /^[0-9]{1,20}$/;
const FILE_ID_PATTERN = /^[A-Za-z0-9_-]{16,64}$/;
// KV のメタデータは 1024 バイトまでなので、ファイル名は短く切る
const MAX_FILE_NAME_LENGTH = 120;

const CORS_HEADERS = {
  // Bearer トークンで認証し Cookie は使わないので、どのオリジンからでもよい
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, HEAD, POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type, X-File-Name',
  'Access-Control-Max-Age': '86400',
};

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

function empty(status) {
  return new Response(null, { status, headers: CORS_HEADERS });
}

// /f/ 以降のパスを KV のキーにする。形が正しくなければ null。
export function fileKeyFromPath(pathAfterF) {
  const parts = pathAfterF.split('/');
  if (parts.length === 4 && parts[1] === 'todos') {
    const [uid, , taskId, id] = parts;
    if (UID_PATTERN.test(uid) && TASK_ID_PATTERN.test(taskId) && FILE_ID_PATTERN.test(id)) {
      return { uid, key: `f/${uid}/todos/${taskId}/${id}` };
    }
  }
  if (parts.length === 3 && parts[1] === 'inquiries') {
    const [uid, , id] = parts;
    if (UID_PATTERN.test(uid) && FILE_ID_PATTERN.test(id)) {
      return { uid, key: `f/${uid}/inquiries/${id}` };
    }
  }
  return null;
}

// 旧 Firebase Storage のオブジェクト名とダウンロードトークンから、
// 移したあとの KV のキーを作る（scripts/legacy-to-kv-bulk.mjs と、アプリの
// legacyStorageUrlToFilesUrl が同じ規則を使う）。
//   users/{uid}/todos/{taskId}/{file} → f/{uid}/todos/{taskId}/{token}
//   users/{uid}/inquiries/{file}      → f/{uid}/inquiries/{token}
export function legacyKeyFromObject(objectName, token) {
  if (!FILE_ID_PATTERN.test(token || '')) return null;
  const parts = (objectName || '').split('/');
  if (parts.length === 5 && parts[0] === 'users' && parts[2] === 'todos') {
    const [, uid, , taskId] = parts;
    if (UID_PATTERN.test(uid) && TASK_ID_PATTERN.test(taskId)) {
      return `f/${uid}/todos/${taskId}/${token}`;
    }
  }
  if (parts.length === 4 && parts[0] === 'users' && parts[2] === 'inquiries') {
    const uid = parts[1];
    if (UID_PATTERN.test(uid)) return `f/${uid}/inquiries/${token}`;
  }
  return null;
}

async function authenticate(request, env, deps) {
  const header = request.headers.get('Authorization') || '';
  const match = /^Bearer (.+)$/.exec(header);
  if (!match) return null;
  try {
    return await verifyIdToken(match[1], env, deps);
  } catch (error) {
    console.log(JSON.stringify({ event: 'auth-error', message: String(error.message || error) }));
    return null;
  }
}

function sanitizeFileName(raw) {
  if (!raw) return '';
  let name;
  try {
    name = decodeURIComponent(raw);
  } catch (_) {
    return '';
  }
  // 改行・制御文字・引用符は落とす（Content-Disposition に入れるため）
  name = name.replace(/[\u0000-\u001f\u007f"\\]/g, '').trim();
  return name.slice(0, MAX_FILE_NAME_LENGTH);
}

function contentDisposition(fileName) {
  if (!fileName) return 'inline';
  // RFC 6266 / 5987。日本語のファイル名も元の名前で見えるようにする
  const ascii = fileName.replace(/[^\x20-\x7e]/g, '_');
  return `inline; filename="${ascii}"; filename*=UTF-8''${encodeURIComponent(fileName)}`;
}

async function handleUpload(request, env, deps, folderParts) {
  const uid = await authenticate(request, env, deps);
  if (!uid) return json(401, { error: 'unauthenticated' });

  let prefix;
  if (folderParts.length === 2 && folderParts[0] === 'todos' && TASK_ID_PATTERN.test(folderParts[1])) {
    prefix = `f/${uid}/todos/${folderParts[1]}`;
  } else if (folderParts.length === 1 && folderParts[0] === 'inquiries') {
    prefix = `f/${uid}/inquiries`;
  } else {
    return json(404, { error: 'not-found' });
  }

  const contentType = (request.headers.get('Content-Type') || '').split(';')[0].trim().toLowerCase();
  if (!ALLOWED_CONTENT_TYPES.has(contentType)) {
    return json(415, { error: 'unsupported-type' });
  }
  const length = Number(request.headers.get('Content-Length'));
  if (!Number.isFinite(length) || length <= 0) return json(411, { error: 'length-required' });
  if (length > MAX_UPLOAD_BYTES) return json(413, { error: 'too-large' });

  const fileName = sanitizeFileName(request.headers.get('X-File-Name'));
  const key = `${prefix}/${randomId()}`;
  try {
    // 本文はメモリに溜めずにそのまま KV へ流す（CPU 時間を使わないため）
    await env.FILES.put(key, request.body, {
      metadata: { contentType, fileName },
    });
  } catch (error) {
    // 無料枠（書き込み 1,000 回/日・容量 1GB）を超えたときなど
    console.log(JSON.stringify({ event: 'kv-put-failed', message: String(error.message || error) }));
    return json(503, { error: 'store-unavailable' });
  }
  const url = `${new URL(request.url).origin}/${key}`;
  return json(201, { url });
}

async function handleGet(request, env, pathAfterF) {
  const target = fileKeyFromPath(pathAfterF);
  if (!target) return empty(404);
  const { value, metadata } = await env.FILES.getWithMetadata(target.key, { type: 'stream' });
  if (value === null) {
    return new Response(null, {
      status: 404,
      headers: { 'Cache-Control': 'no-store', ...CORS_HEADERS },
    });
  }
  const meta = metadata || {};
  const headers = {
    'Content-Type': ALLOWED_CONTENT_TYPES.has(meta.contentType) ? meta.contentType : 'application/octet-stream',
    'Cache-Control': FILE_CACHE_CONTROL,
    'Content-Disposition': contentDisposition(meta.fileName),
    'X-Content-Type-Options': 'nosniff',
    ...CORS_HEADERS,
  };
  if (request.method === 'HEAD') {
    await value.cancel();
    return new Response(null, { status: 200, headers });
  }
  return new Response(value, { status: 200, headers });
}

async function handleDeleteFile(request, env, deps, pathAfterF) {
  const uid = await authenticate(request, env, deps);
  if (!uid) return json(401, { error: 'unauthenticated' });
  const target = fileKeyFromPath(pathAfterF);
  if (!target) return empty(404);
  if (target.uid !== uid) return json(403, { error: 'forbidden' });
  await env.FILES.delete(target.key);
  return empty(204);
}

async function handleDeleteFolder(request, env, deps, folderParts) {
  const uid = await authenticate(request, env, deps);
  if (!uid) return json(401, { error: 'unauthenticated' });
  if (!(folderParts.length === 2 && folderParts[0] === 'todos' && TASK_ID_PATTERN.test(folderParts[1]))) {
    return empty(404);
  }
  const prefix = `f/${uid}/todos/${folderParts[1]}/`;
  // 一覧を取り終えてから消す（消しながらページを送らない）
  const names = [];
  let cursor;
  do {
    const page = await env.FILES.list({ prefix, cursor });
    for (const { name } of page.keys) names.push(name);
    cursor = page.list_complete ? undefined : page.cursor;
  } while (cursor);
  for (const name of names) await env.FILES.delete(name);
  return json(200, { deleted: names.length });
}

export async function handleFileRequest(request, env, deps) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/^\/+/, '');
  const method = request.method;

  if (method === 'OPTIONS') return empty(204);
  if (path.startsWith('f/')) {
    const rest = path.slice(2);
    if (method === 'GET' || method === 'HEAD') return handleGet(request, env, rest);
    if (method === 'DELETE') return handleDeleteFile(request, env, deps, rest);
    return empty(405);
  }
  if (path.startsWith('upload/')) {
    if (method !== 'POST') return empty(405);
    return handleUpload(request, env, deps, path.slice('upload/'.length).split('/'));
  }
  if (path.startsWith('folder/')) {
    if (method !== 'DELETE') return empty(405);
    return handleDeleteFolder(request, env, deps, path.slice('folder/'.length).split('/'));
  }
  return empty(404);
}
