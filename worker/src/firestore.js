// Firestore の REST API（v1）を呼ぶための最小限の部品。
// Admin SDK は Workers では動かないので、必要な3つの呼び出し
// （runQuery・devices の一覧・batchWrite）だけを fetch で書く。
import { callFetch } from './call-fetch.js';

const DEFAULT_BASE = 'https://firestore.googleapis.com';

export function firestoreBase(env) {
  return (env.FIRESTORE_BASE_URL || DEFAULT_BASE).replace(/\/$/, '');
}

export function databasePath(env) {
  return `projects/${env.FIREBASE_PROJECT_ID}/databases/(default)`;
}

// REST の timestampValue（RFC 3339。小数部は 0〜9 桁）をミリ秒にする。
// Date.parse は小数部が4桁以上のときの扱いが実装依存なので、3桁にそろえてから読む。
export function timestampToMillis(value) {
  if (typeof value !== 'string') return NaN;
  const normalized = value.replace(
    /\.(\d+)(?=(Z|[+-]\d\d:\d\d)$)/,
    (_, fraction) => `.${fraction.slice(0, 3).padEnd(3, '0')}`,
  );
  return Date.parse(normalized);
}

// 送信予定の entries（REST の arrayValue）を planDelivery に渡せる形にする。
// 書き戻すときに値を作り直さなくて済むよう、元の REST の値を raw に残す。
export function decodeEntries(entriesValue) {
  const values =
    (entriesValue && entriesValue.arrayValue && entriesValue.arrayValue.values) ||
    [];
  return values.map((raw) => {
    const fields = (raw && raw.mapValue && raw.mapValue.fields) || {};
    const sendAt = fields.sendAt && fields.sendAt.timestampValue;
    const millis = timestampToMillis(sendAt);
    return {
      sendAt: Number.isFinite(millis) ? { toMillis: () => millis } : null,
      body: (fields.body && fields.body.stringValue) || '',
      raw,
    };
  });
}

export function stringField(fields, name) {
  const value = fields && fields[name];
  if (!value) return '';
  if (typeof value.stringValue === 'string') return value.stringValue;
  if (value.integerValue !== undefined) return String(value.integerValue);
  if (value.doubleValue !== undefined) return String(value.doubleValue);
  return '';
}

// users/{uid}/notifications/{taskId} の uid を取り出す。
// それ以外の場所にある notifications は扱わない（ルールでは本人の配下に
// 何でも書けるため、深い階層に置いた予定で他人の uid を名乗れないようにする）。
export function uidFromNotificationName(name) {
  const match = /\/documents\/users\/([^/]+)\/notifications\/[^/]+$/.exec(
    name || '',
  );
  return match ? match[1] : null;
}

async function firestoreFetch(ctx, path, init) {
  ctx.budget.spend(1);
  const response = await callFetch(ctx, `${firestoreBase(ctx.env)}/v1/${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${ctx.accessToken}`,
      'Content-Type': 'application/json',
    },
  });
  if (!response.ok) {
    const error = new Error(
      `Firestore ${init.method || 'GET'} ${path.split('?')[0]} failed: ${response.status}`,
    );
    error.status = response.status;
    throw error;
  }
  return response.json();
}

// nextSendAt が now 以前の送信予定を、全利用者の notifications から古い順に取る。
// collectionGroup のクエリ。firestore.indexes.json の COLLECTION_GROUP の
// 単一フィールドインデックス（nextSendAt）がこれに使われる。
export async function queryDueNotifications(ctx, nowMillis, limit) {
  const rows = await firestoreFetch(
    ctx,
    `${databasePath(ctx.env)}/documents:runQuery`,
    {
      method: 'POST',
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: 'notifications', allDescendants: true }],
          where: {
            fieldFilter: {
              field: { fieldPath: 'nextSendAt' },
              op: 'LESS_THAN_OR_EQUAL',
              value: { timestampValue: new Date(nowMillis).toISOString() },
            },
          },
          orderBy: [{ field: { fieldPath: 'nextSendAt' }, direction: 'ASCENDING' }],
          limit,
        },
      }),
    },
  );
  return (Array.isArray(rows) ? rows : [])
    .map((row) => row.document)
    .filter(Boolean);
}

// users/{uid}/devices の一覧（ドキュメント ID が FCM のトークン）。
export async function listDevices(ctx, uid) {
  const query = 'pageSize=300&mask.fieldPaths=platform';
  const data = await firestoreFetch(
    ctx,
    `${databasePath(ctx.env)}/documents/users/${encodeURIComponent(uid)}/devices?${query}`,
    { method: 'GET' },
  );
  return (data.documents || []).map((doc) => ({
    name: doc.name,
    token: doc.name.split('/').pop(),
    platform: stringField(doc.fields, 'platform'),
  }));
}

// 書き込みをまとめて送る。batchWrite は1件ずつ独立に成否が決まる
// （commit と違い、1件の失敗で全部が取り消されない）。
export async function batchWrite(ctx, writes) {
  const data = await firestoreFetch(
    ctx,
    `${databasePath(ctx.env)}/documents:batchWrite`,
    { method: 'POST', body: JSON.stringify({ writes }) },
  );
  const statuses = data.status || [];
  return statuses.filter((status) => status && status.code).length;
}
