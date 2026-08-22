// 期限の通知を、同じアカウントの全端末へ送るための定期実行関数。
//
// クライアントは users/{uid}/notifications/{taskId} に「送信予定」を書いておく。
//   { taskId, title, entries: [{ sendAt, body }], nextSendAt }
// この関数は毎分 nextSendAt を見て、時刻が来たものを users/{uid}/devices の
// 全トークンへ送り、送った分を entries から取り除く。
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
const db = getFirestore();

// 1回の実行で扱う通知ドキュメントの上限。
// 取りこぼしても次の実行で拾えるので、実行時間を短く保つことを優先する。
const MAX_DOCS_PER_RUN = 200;

exports.sendDueNotifications = onSchedule(
  {
    schedule: 'every 1 minutes',
    timeZone: 'Asia/Tokyo',
    region: 'asia-northeast1',
    retryCount: 0,
  },
  async () => {
    const now = Timestamp.now();
    const due = await db
      .collectionGroup('notifications')
      .where('nextSendAt', '<=', now)
      .orderBy('nextSendAt')
      .limit(MAX_DOCS_PER_RUN)
      .get();

    if (due.empty) return;

    // 同じユーザーの端末一覧は使い回す（毎回引かない）
    const tokensByUid = new Map();

    for (const doc of due.docs) {
      const uid = doc.ref.parent.parent && doc.ref.parent.parent.id;
      if (!uid) continue;

      const data = doc.data();
      const entries = Array.isArray(data.entries) ? data.entries : [];
      const dueEntries = entries.filter(
        (entry) => entry.sendAt && entry.sendAt.toMillis() <= now.toMillis(),
      );
      const remaining = entries.filter(
        (entry) => entry.sendAt && entry.sendAt.toMillis() > now.toMillis(),
      );

      if (dueEntries.length > 0) {
        if (!tokensByUid.has(uid)) {
          tokensByUid.set(uid, await loadDeviceTokens(uid));
        }
        const tokens = tokensByUid.get(uid);
        // 同じタスクで複数件たまっていても、鳴らすのは最後の1件だけにする
        // （通知が一度に何度も出るのを避ける）
        const entry = dueEntries[dueEntries.length - 1];
        await sendToDevices(uid, tokens, {
          title: data.title || '期限が近づいています',
          body: entry.body || '',
          taskId: String(data.taskId || ''),
        });
      }

      // 送信済みの分を取り除く。残りが無ければドキュメントごと消す。
      if (remaining.length === 0) {
        await doc.ref.delete();
      } else {
        await doc.ref.update({
          entries: remaining,
          nextSendAt: remaining[0].sendAt,
        });
      }
    }
  },
);

async function loadDeviceTokens(uid) {
  const snapshot = await db.collection(`users/${uid}/devices`).get();
  return snapshot.docs.map((doc) => doc.id).filter(Boolean);
}

async function sendToDevices(uid, tokens, payload) {
  if (tokens.length === 0) return;

  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title: payload.title, body: payload.body },
    data: { taskId: payload.taskId },
    webpush: {
      notification: {
        title: payload.title,
        body: payload.body,
        icon: '/icons/Icon-192.png',
        tag: payload.taskId,
      },
    },
    android: { priority: 'high' },
    apns: {
      payload: { aps: { sound: 'default' } },
    },
  });

  // 無効になったトークン（アプリ削除・再インストール等）は消しておく。
  // 残しておくと毎回失敗して無駄になるため。
  const stale = [];
  response.responses.forEach((result, index) => {
    if (result.success) return;
    const code = result.error && result.error.code;
    if (
      code === 'messaging/registration-token-not-registered' ||
      code === 'messaging/invalid-registration-token' ||
      code === 'messaging/invalid-argument'
    ) {
      stale.push(tokens[index]);
    }
  });
  await Promise.all(
    stale.map((token) =>
      db.doc(`users/${uid}/devices/${token}`).delete().catch(() => {}),
    ),
  );
}
