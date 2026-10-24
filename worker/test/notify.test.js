// 毎分の送信処理（sendDueNotifications）のテスト。
// Google の token・Firestore・FCM への fetch をすべて差し替えて、送る中身と
// Firestore へ書き戻す内容が Cloud Functions 版と同じになることを確かめる。
import test, { beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { sendDueNotifications, SubrequestBudget } from '../src/notify.js';
import { clearMemoizedToken, SCOPES } from '../src/google-auth.js';
import { timestampToMillis, uidFromNotificationName } from '../src/firestore.js';
import { classifyFcmError } from '../src/fcm.js';
import { FakeKV, mockFetch, jsonResponse, makeServiceAccount, verifyJwt } from './helpers.js';

const PROJECT = 'todo-app-mokuson';
const DB = `projects/${PROJECT}/databases/(default)/documents`;
const NOW = Date.parse('2026-10-25T09:00:00Z');
const sa = await makeServiceAccount();

beforeEach(() => clearMemoizedToken());

function env(extra = {}) {
  return {
    FIREBASE_PROJECT_ID: PROJECT,
    GOOGLE_SERVICE_ACCOUNT: sa.json,
    FILES: new FakeKV(),
    ...extra,
  };
}

const ts = (iso) => ({ timestampValue: iso });
function planDoc(uid, taskId, entries, { title = '期限が近づいています', path } = {}) {
  const values = entries.map(([iso, body]) => ({
    mapValue: { fields: { sendAt: ts(iso), body: { stringValue: body } } },
  }));
  return {
    name: path || `${DB}/users/${uid}/notifications/${taskId}`,
    fields: {
      taskId: { integerValue: String(taskId) },
      title: { stringValue: title },
      entries: { arrayValue: { values } },
      nextSendAt: values[0] ? values[0].mapValue.fields.sendAt : ts(entries[0][0]),
    },
    createTime: '2026-10-20T00:00:00.000000Z',
    updateTime: `2026-10-24T00:00:00.${String(taskId).padStart(6, '0')}Z`,
  };
}
function deviceDoc(uid, token, platform) {
  return { name: `${DB}/users/${uid}/devices/${token}`, fields: { platform: { stringValue: platform } } };
}

// Google 側のふるまいをまとめて差し替える
function google({ docs = [], devices = {}, fcm = () => jsonResponse(200, { name: 'projects/x/messages/1' }), devicesStatus = 200 }) {
  const state = { tokenRequests: 0, sends: [], writes: null, runQuery: null };
  const fetch = mockFetch([
    {
      match: (url) => url === 'https://oauth2.googleapis.com/token',
      respond: (url, init, body) => {
        state.tokenRequests++;
        state.tokenBody = body;
        return jsonResponse(200, { access_token: `access-${state.tokenRequests}`, expires_in: 3599, token_type: 'Bearer' });
      },
    },
    {
      match: (url) => url === `https://firestore.googleapis.com/v1/${DB}:runQuery`,
      respond: (url, init, body) => {
        state.runQuery = JSON.parse(body);
        return jsonResponse(200, docs.length ? docs.map((document) => ({ document, readTime: 'x' })) : [{ readTime: 'x' }]);
      },
    },
    {
      match: (url) => url.startsWith(`https://firestore.googleapis.com/v1/${DB}/users/`) && url.includes('/devices?'),
      respond: (url) => {
        const uid = decodeURIComponent(url.split('/users/')[1].split('/')[0]);
        if (devicesStatus !== 200) return jsonResponse(devicesStatus, { error: { status: 'INTERNAL' } });
        return jsonResponse(200, devices[uid] ? { documents: devices[uid] } : {});
      },
    },
    {
      match: (url) => url === `https://fcm.googleapis.com/v1/projects/${PROJECT}/messages:send`,
      respond: (url, init, body) => {
        const message = JSON.parse(body).message;
        state.sends.push({ message, auth: init.headers.Authorization });
        return fcm(message);
      },
    },
    {
      match: (url) => url === `https://firestore.googleapis.com/v1/${DB}:batchWrite`,
      respond: (url, init, body) => {
        state.writes = JSON.parse(body).writes;
        return jsonResponse(200, { writeResults: state.writes.map(() => ({})), status: state.writes.map(() => ({})) });
      },
    },
  ]);
  return { fetch, state };
}

test('予定が無ければ、トークンの取得とクエリだけで終わる（書き込みなし）', async () => {
  const { fetch, state } = google({});
  const e = env();
  const summary = await sendDueNotifications({ env: e, fetch, nowMillis: NOW });
  assert.equal(summary.due, 0);
  assert.equal(fetch.calls.length, 2);
  assert.equal(state.writes, null);
  // collectionGroup のクエリを nextSendAt <= now、古い順で投げている
  const q = state.runQuery.structuredQuery;
  assert.deepEqual(q.from, [{ collectionId: 'notifications', allDescendants: true }]);
  assert.equal(q.where.fieldFilter.op, 'LESS_THAN_OR_EQUAL');
  assert.equal(q.where.fieldFilter.value.timestampValue, '2026-10-25T09:00:00.000Z');
  assert.deepEqual(q.orderBy, [{ field: { fieldPath: 'nextSendAt' }, direction: 'ASCENDING' }]);
  assert.equal(q.limit, 25);
});

test('サービスアカウントの JWT は RS256 で署名され、Firestore と FCM の両方のスコープを持つ', async () => {
  const { fetch, state } = google({});
  await sendDueNotifications({ env: env(), fetch, nowMillis: NOW });
  const params = new URLSearchParams(state.tokenBody);
  assert.equal(params.get('grant_type'), 'urn:ietf:params:oauth:grant-type:jwt-bearer');
  const { ok, header, claims } = await verifyJwt(params.get('assertion'), sa.publicKey);
  assert.equal(ok, true);
  assert.equal(header.alg, 'RS256');
  assert.equal(claims.iss, 'notifier@test-project.iam.gserviceaccount.com');
  assert.equal(claims.aud, 'https://oauth2.googleapis.com/token');
  assert.deepEqual(claims.scope.split(' '), SCOPES);
  assert.equal(claims.exp - claims.iat, 3600);
});

test('アクセストークンは KV に控え、次の実行では作り直さない', async () => {
  const e = env();
  const first = google({});
  await sendDueNotifications({ env: e, fetch: first.fetch, nowMillis: NOW });
  assert.equal(first.state.tokenRequests, 1);
  clearMemoizedToken(); // 別の isolate で動いた場合
  const second = google({});
  await sendDueNotifications({ env: e, fetch: second.fetch, nowMillis: NOW + 60_000 });
  assert.equal(second.state.tokenRequests, 0);
  assert.equal(second.fetch.calls.length, 1);
  // 期限の5分前を過ぎたら作り直す
  clearMemoizedToken();
  const third = google({});
  await sendDueNotifications({ env: e, fetch: third.fetch, nowMillis: NOW + 56 * 60_000 });
  assert.equal(third.state.tokenRequests, 1);
});

test('Web には data だけ、ネイティブには notification 付きで送り、送った分を書き戻す', async () => {
  const docs = [
    // 時刻が来た分が2件たまっている → 最後の1件だけ送り、残り1件で更新
    planDoc('userA', 101, [
      ['2026-10-25T08:30:00Z', '30分前です'],
      ['2026-10-25T08:59:00Z', '1分前です'],
      ['2026-10-26T09:00:00.123456Z', '明日です'],
    ]),
    // 残りが無い → ドキュメントごと消す
    planDoc('userA', 102, [['2026-10-25T09:00:00Z', '期限です']]),
  ];
  const devices = {
    userA: [deviceDoc('userA', 'web-token', 'web'), deviceDoc('userA', 'ios-token', 'iOS')],
  };
  const { fetch, state } = google({ docs, devices });
  const summary = await sendDueNotifications({ env: env(), fetch, nowMillis: NOW });

  assert.equal(summary.sent, 2);
  // 端末一覧は利用者ごとに1回だけ読む
  assert.equal(fetch.calls.filter((c) => c.url.includes('/devices?')).length, 1);
  assert.equal(state.sends.length, 4);
  assert.deepEqual(state.sends[0].message, {
    token: 'web-token',
    data: { title: '期限が近づいています', body: '1分前です', taskId: '101' },
    webpush: { headers: { Urgency: 'high', TTL: '86400' } },
  });
  assert.deepEqual(state.sends[1].message, {
    token: 'ios-token',
    notification: { title: '期限が近づいています', body: '1分前です' },
    data: { taskId: '101' },
    android: { priority: 'HIGH' },
    apns: { payload: { aps: { sound: 'default' } } },
  });
  assert.equal(state.sends[0].auth, 'Bearer access-1');

  assert.deepEqual(state.writes, [
    {
      update: {
        name: docs[0].name,
        fields: {
          entries: { arrayValue: { values: [docs[0].fields.entries.arrayValue.values[2]] } },
          // nextSendAt は Timestamp のまま（文字列にしない）
          nextSendAt: { timestampValue: '2026-10-26T09:00:00.123456Z' },
        },
      },
      updateMask: { fieldPaths: ['entries', 'nextSendAt'] },
      currentDocument: { updateTime: docs[0].updateTime },
    },
    { delete: docs[1].name, currentDocument: { updateTime: docs[1].updateTime } },
  ]);
});

test('1日より古い予定は送らずに片付ける', async () => {
  const docs = [
    planDoc('userA', 201, [
      ['2026-10-20T09:00:00Z', '5日前'],
      ['2026-10-30T09:00:00Z', '先の予定'],
    ]),
  ];
  const { fetch, state } = google({ docs, devices: { userA: [deviceDoc('userA', 't', 'web')] } });
  const summary = await sendDueNotifications({ env: env(), fetch, nowMillis: NOW });
  assert.equal(summary.expired, 1);
  assert.equal(summary.sent, 0);
  assert.equal(state.sends.length, 0);
  // 送らないので端末一覧も読まない
  assert.equal(fetch.calls.filter((c) => c.url.includes('/devices?')).length, 0);
  assert.equal(state.writes.length, 1);
  assert.deepEqual(state.writes[0].update.fields.nextSendAt, { timestampValue: '2026-10-30T09:00:00Z' });
});

test('無効になったトークンは消す。中身の誤りに見える INVALID_ARGUMENT では消さない', async () => {
  const docs = [planDoc('userA', 301, [['2026-10-25T08:59:00Z', '1分前']])];
  const devices = {
    userA: [
      deviceDoc('userA', 'gone', 'android'),
      deviceDoc('userA', 'bad-format', 'web'),
      deviceDoc('userA', 'payload-error', 'iOS'),
      deviceDoc('userA', 'ok', 'web'),
    ],
  };
  const fcm = (message) => {
    if (message.token === 'gone') {
      return jsonResponse(404, { error: { code: 404, status: 'NOT_FOUND', message: 'Requested entity was not found.', details: [{ '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError', errorCode: 'UNREGISTERED' }] } });
    }
    if (message.token === 'bad-format') {
      return jsonResponse(400, { error: { code: 400, status: 'INVALID_ARGUMENT', message: 'The registration token is not a valid FCM registration token', details: [{ '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError', errorCode: 'INVALID_ARGUMENT' }] } });
    }
    if (message.token === 'payload-error') {
      return jsonResponse(400, { error: { code: 400, status: 'INVALID_ARGUMENT', message: 'Invalid JSON payload received.', details: [{ '@type': 'type.googleapis.com/google.rpc.BadRequest', fieldViolations: [{ field: 'message.apns.payload', description: 'bad' }] }] } });
    }
    return jsonResponse(200, { name: 'ok' });
  };
  const { fetch, state } = google({ docs, devices, fcm });
  const summary = await sendDueNotifications({ env: env(), fetch, nowMillis: NOW });
  assert.equal(summary.staleTokens, 2);
  const deletes = state.writes.filter((w) => w.delete && w.delete.includes('/devices/')).map((w) => w.delete.split('/').pop());
  assert.deepEqual(deletes.sort(), ['bad-format', 'gone']);
  // 送信予定のほうは通常どおり片付ける
  assert.ok(state.writes.some((w) => w.delete === docs[0].name));
});

test('fetch の上限に届く前に打ち切り、送れなかった予定には触らない', async () => {
  // 1件あたり端末3台 → 送信3回。上限 10 = token 1 + query 1 + devices 1 + 3 + 3 + 書き戻し 1 で2件まで
  const docs = [1, 2, 3, 4].map((n) => planDoc('userA', 400 + n, [['2026-10-25T08:59:00Z', `${n}`]]));
  const devices = { userA: ['a', 'b', 'c'].map((t) => deviceDoc('userA', t, 'web')) };
  const { fetch, state } = google({ docs, devices });
  const summary = await sendDueNotifications({ env: env({ SUBREQUEST_LIMIT: '10' }), fetch, nowMillis: NOW });
  assert.equal(summary.sent, 2);
  assert.equal(summary.deferred, 2);
  assert.equal(state.sends.length, 6);
  assert.equal(fetch.calls.length, 10);
  assert.deepEqual(state.writes.map((w) => w.delete), [docs[0].name, docs[1].name]);
});

test('FCM の認証エラーでは、その予定を残して止め、それまでの分は書き戻す', async () => {
  const docs = [
    planDoc('userA', 501, [['2026-10-25T08:59:00Z', 'a']]),
    planDoc('userB', 502, [['2026-10-25T08:59:00Z', 'b']]),
  ];
  const devices = { userA: [deviceDoc('userA', 'ta', 'web')], userB: [deviceDoc('userB', 'tb', 'web')] };
  const fcm = (message) =>
    message.token === 'tb'
      ? jsonResponse(401, { error: { code: 401, status: 'UNAUTHENTICATED', message: 'Request had invalid authentication credentials.' } })
      : jsonResponse(200, {});
  const e = env();
  const { fetch, state } = google({ docs, devices, fcm });
  const summary = await sendDueNotifications({ env: e, fetch, nowMillis: NOW });
  assert.match(summary.error, /UNAUTHENTICATED/);
  assert.deepEqual(state.writes, [{ delete: docs[0].name, currentDocument: { updateTime: docs[0].updateTime } }]);
  // 控えていたトークンは捨て、次の実行で作り直す
  assert.equal(await e.FILES.get('_cache/google-access-token'), null);
});

test('端末一覧の読み込みに失敗しても、それまでに送った分は書き戻す', async () => {
  const docs = [planDoc('userA', 601, [['2026-10-25T08:59:00Z', 'a']])];
  const { fetch, state } = google({ docs, devicesStatus: 500 });
  const summary = await sendDueNotifications({ env: env(), fetch, nowMillis: NOW });
  assert.match(summary.error, /500/);
  assert.equal(state.writes, null);
  assert.equal(state.sends.length, 0);
});

test('users/{uid}/notifications 以外の場所の予定は扱わない', async () => {
  const deep = planDoc('victim', 701, [['2026-10-25T08:59:00Z', 'x']], {
    path: `${DB}/users/attacker/x/victim/notifications/701`,
  });
  const { fetch, state } = google({ docs: [deep], devices: { victim: [deviceDoc('victim', 'v', 'web')] } });
  await sendDueNotifications({ env: env(), fetch, nowMillis: NOW });
  assert.equal(state.sends.length, 0);
  assert.equal(state.writes, null);
  assert.equal(uidFromNotificationName(`${DB}/users/u1/notifications/1`), 'u1');
});

test('端末が無い利用者でも予定は片付ける', async () => {
  const docs = [planDoc('lonely', 801, [['2026-10-25T08:59:00Z', 'x']])];
  const { fetch, state } = google({ docs });
  await sendDueNotifications({ env: env(), fetch, nowMillis: NOW });
  assert.equal(state.sends.length, 0);
  assert.deepEqual(state.writes.map((w) => w.delete), [docs[0].name]);
});

test('timestampValue はナノ秒の桁があっても読める', () => {
  assert.equal(timestampToMillis('2026-10-25T09:00:00Z'), NOW);
  assert.equal(timestampToMillis('2026-10-25T09:00:00.123456789Z'), NOW + 123);
  assert.equal(timestampToMillis('2026-10-25T18:00:00.5+09:00'), NOW + 500);
  assert.ok(Number.isNaN(timestampToMillis(undefined)));
});

test('FCM のエラーの見分け方', () => {
  assert.deepEqual(classifyFcmError(403, { error: { status: 'PERMISSION_DENIED', details: [{ errorCode: 'SENDER_ID_MISMATCH' }] } }), { code: 'SENDER_ID_MISMATCH', stale: false, fatal: false });
  assert.equal(classifyFcmError(403, { error: { status: 'PERMISSION_DENIED' } }).fatal, true);
  assert.equal(classifyFcmError(429, { error: { status: 'RESOURCE_EXHAUSTED', details: [{ errorCode: 'QUOTA_EXCEEDED' }] } }).stale, false);
  assert.equal(classifyFcmError(400, { error: { status: 'INVALID_ARGUMENT', details: [{ fieldViolations: [{ field: 'message.token' }] }] } }).stale, true);
  assert.equal(classifyFcmError(500, null).fatal, false);
});

test('SubrequestBudget は上限を超えて使わせない', () => {
  const budget = new SubrequestBudget(2);
  budget.spend(2);
  assert.equal(budget.canSpend(1), false);
  assert.throws(() => budget.spend(1));
});
