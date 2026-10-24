// FCM HTTP v1 API で1台ずつ送る（v1 にはまとめて送る口が無い）。
// 送る中身は Cloud Functions 版（sendEachForMulticast）と同じ形にする。
import { callFetch } from './call-fetch.js';

const DEFAULT_BASE = 'https://fcm.googleapis.com';

// Web: data だけで送り、Service Worker（firebase-messaging-sw.js）が1回だけ表示する。
//      notification を付けると SDK の自動表示と重なり、二重に出ることがある。
// ネイティブ: notification を付けて、アプリを開いていなくても OS が表示する。
export function buildMessage(device, payload) {
  if (device.platform === 'web') {
    return {
      token: device.token,
      data: {
        title: payload.title,
        body: payload.body,
        taskId: payload.taskId,
      },
      // ブラウザを閉じていた間の分も、起動後に届くようにする（1日保持）
      webpush: { headers: { Urgency: 'high', TTL: '86400' } },
    };
  }
  return {
    token: device.token,
    notification: { title: payload.title, body: payload.body },
    data: { taskId: payload.taskId },
    android: { priority: 'HIGH' },
    apns: { payload: { aps: { sound: 'default' } } },
  };
}

// FCM のエラー応答を見て、トークンを消すべきか・実行ごと止めるべきかを決める。
//   stale … このトークンは二度と使えない（UNREGISTERED、または
//           INVALID_ARGUMENT で原因がトークンだと明示されているとき）
//   fatal … 認証・権限の問題で、どのトークンにも送れない
// INVALID_ARGUMENT は送る中身の誤りでも返るので、トークンが原因と
// 書かれていないときは消さない（中身の誤りで全端末の登録を消さないため）。
export function classifyFcmError(status, body) {
  const error = (body && body.error) || {};
  const details = Array.isArray(error.details) ? error.details : [];
  const fcmCode = details
    .map((detail) => detail && detail.errorCode)
    .find(Boolean);
  const code = fcmCode || error.status || '';
  const tokenViolation = details.some(
    (detail) =>
      Array.isArray(detail && detail.fieldViolations) &&
      detail.fieldViolations.some((v) => v && v.field === 'message.token'),
  );
  const tokenMessage = /registration token/i.test(error.message || '');

  if (code === 'UNREGISTERED' || (status === 404 && code === 'NOT_FOUND')) {
    return { code, stale: true, fatal: false };
  }
  if (code === 'INVALID_ARGUMENT') {
    return { code, stale: tokenViolation || tokenMessage, fatal: false };
  }
  if (code === 'SENDER_ID_MISMATCH') {
    return { code, stale: false, fatal: false };
  }
  if (status === 401 || status === 403) {
    return { code: code || String(status), stale: false, fatal: true };
  }
  return { code: code || String(status), stale: false, fatal: false };
}

// ctx: { env, fetch, budget, accessToken }
export async function sendToDevice(ctx, device, payload) {
  const base = (ctx.env.FCM_BASE_URL || DEFAULT_BASE).replace(/\/$/, '');
  ctx.budget.spend(1);
  const response = await callFetch(ctx, 
    `${base}/v1/projects/${ctx.env.FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${ctx.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ message: buildMessage(device, payload) }),
    },
  );
  if (response.ok) {
    await response.body?.cancel?.();
    return { ok: true, stale: false, fatal: false, code: '' };
  }
  let body = null;
  try {
    body = await response.json();
  } catch (_) {
    body = null;
  }
  return { ok: false, ...classifyFcmError(response.status, body) };
}
