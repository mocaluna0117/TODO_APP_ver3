// 期限の通知を、同じアカウントの全端末へ送る（毎分の Cron Trigger から呼ぶ）。
// todo_app/functions/index.js の sendDueNotifications を Workers に移したもの。
//
// クライアントは users/{uid}/notifications/{taskId} に「送信予定」を書いておく。
//   { taskId, title, entries: [{ sendAt, body }], nextSendAt }
// ここでは毎分 nextSendAt を見て、時刻が来たものを users/{uid}/devices の
// 全トークンへ送り、送った分を entries から取り除く。
//
// 無料プランの制限に合わせて、Cloud Functions 版から変えた点:
// - 外部への fetch は1回の実行で50回まで。残り回数を数え、1件分を送り切れない
//   ところで打ち切る（打ち切った予定は触らずに残し、次の分で拾う）
// - 書き戻しは batchWrite の1回にまとめる。各ドキュメントには読んだときの
//   updateTime を前提条件に付け、その間にアプリが書き直していたら上書きしない
import { planDelivery } from './schedule.js';
import { getAccessToken, forgetAccessToken } from './google-auth.js';
import {
  queryDueNotifications,
  listDevices,
  batchWrite,
  decodeEntries,
  stringField,
  uidFromNotificationName,
} from './firestore.js';
import { sendToDevice } from './fcm.js';

// 1回の実行で読む送信予定の上限。取りこぼしても次の分で拾える。
const DEFAULT_MAX_DOCS_PER_RUN = 25;
// Workers Free の外部サブリクエストの上限（50）から、少し余裕を残す
const DEFAULT_SUBREQUEST_LIMIT = 48;

export class SubrequestBudget {
  constructor(limit) {
    this.limit = limit;
    this.used = 0;
  }
  get remaining() {
    return this.limit - this.used;
  }
  canSpend(count) {
    return this.used + count <= this.limit;
  }
  spend(count) {
    if (!this.canSpend(count)) {
      throw new Error('subrequest budget exceeded');
    }
    this.used += count;
  }
}

function positiveInt(value, fallback) {
  const n = Number.parseInt(value, 10);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

// 返り値は件数だけのまとめ（ログに出すため。タスクの中身やトークンは含めない）
export async function sendDueNotifications({ env, fetch, nowMillis = Date.now() }) {
  const budget = new SubrequestBudget(
    positiveInt(env.SUBREQUEST_LIMIT, DEFAULT_SUBREQUEST_LIMIT),
  );
  const maxDocs = positiveInt(env.MAX_DOCS_PER_RUN, DEFAULT_MAX_DOCS_PER_RUN);
  const ctx = { env, fetch, budget, nowMillis, accessToken: null };
  const summary = {
    due: 0,
    sent: 0,
    expired: 0,
    deferred: 0,
    staleTokens: 0,
    writeFailures: 0,
    error: null,
  };

  ctx.accessToken = await getAccessToken(ctx);
  const docs = await queryDueNotifications(ctx, nowMillis, maxDocs);
  summary.due = docs.length;
  if (docs.length === 0) return summary;

  // 同じ利用者の端末一覧は、1回の実行の中では使い回す
  const devicesByUid = new Map();
  const writes = [];
  const staleNames = new Set();
  // 最後の batchWrite の1回分は、常に残しておく
  const reserveForWrite = 1;

  try {
    for (let i = 0; i < docs.length; i++) {
      const doc = docs[i];
      const uid = uidFromNotificationName(doc.name);
      if (!uid) continue;
      const fields = doc.fields || {};

      // 送るのは時刻が来た分の最後の1件だけ。1日より古いものは送らない
      // （送信役が止まっていた間の予定を、再開時にまとめて鳴らさない）。
      const { toSend, remaining, expired } = planDelivery(
        decodeEntries(fields.entries),
        nowMillis,
      );

      if (toSend) {
        if (!devicesByUid.has(uid)) {
          if (!budget.canSpend(1 + reserveForWrite)) {
            summary.deferred = docs.length - i;
            break;
          }
          devicesByUid.set(uid, await listDevices(ctx, uid));
        }
        const devices = devicesByUid.get(uid).filter((d) => !staleNames.has(d.name));
        if (!budget.canSpend(devices.length + reserveForWrite)) {
          // 全端末へ送り切れないなら、この予定には触らず次の分に回す
          summary.deferred = docs.length - i;
          break;
        }
        const payload = {
          title: stringField(fields, 'title') || '期限が近づいています',
          body: toSend.body || '',
          taskId: stringField(fields, 'taskId'),
        };
        let fatal = null;
        for (const device of devices) {
          let result;
          try {
            result = await sendToDevice(ctx, device, payload);
          } catch (_) {
            // 通信の失敗はその端末だけの失敗として扱う（Cloud Functions 版の
            // sendEachForMulticast と同じく、他の端末への送信と書き戻しは続ける）
            continue;
          }
          if (result.ok) continue;
          if (result.stale) staleNames.add(device.name);
          if (result.fatal) {
            fatal = result.code;
            break;
          }
        }
        if (fatal) {
          // 認証・権限の誤りでは、どの端末にも届いていない。
          // この予定は書き換えずに残して次の分でやり直し、ここまでの分だけ書き戻す。
          summary.error = `fcm ${fatal}`;
          summary.deferred = docs.length - i;
          await forgetAccessToken(env);
          break;
        }
        summary.sent++;
      }
      if (expired) summary.expired++;

      // 送信済みの分を取り除く。残りが無ければドキュメントごと消す。
      const precondition = doc.updateTime
        ? { currentDocument: { updateTime: doc.updateTime } }
        : {};
      if (remaining.length === 0) {
        writes.push({ delete: doc.name, ...precondition });
      } else {
        writes.push({
          update: {
            name: doc.name,
            fields: {
              entries: { arrayValue: { values: remaining.map((e) => e.raw) } },
              nextSendAt: remaining[0].raw.mapValue.fields.sendAt,
            },
          },
          updateMask: { fieldPaths: ['entries', 'nextSendAt'] },
          ...precondition,
        });
      }
    }
  } catch (error) {
    // 途中で失敗しても、ここまでに送った分の書き戻しは必ず行う
    // （書き戻さないと、次の分で同じ通知をもう一度送ってしまう）
    summary.error = String((error && error.message) || error);
  }

  // 無効になったトークン（アプリ削除・再インストール等）は消しておく。
  for (const name of staleNames) writes.push({ delete: name });
  summary.staleTokens = staleNames.size;

  if (writes.length > 0) {
    summary.writeFailures = await batchWrite(ctx, writes);
  }
  return summary;
}
