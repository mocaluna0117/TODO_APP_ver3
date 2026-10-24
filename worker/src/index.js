// TODO アプリの Worker。
// - scheduled: 毎分、時刻が来た通知を FCM で送る（notify.js）
// - fetch: 添付ファイル（画像・PDF）の置き場（files.js）
import { sendDueNotifications } from './notify.js';
import { handleFileRequest } from './files.js';

// fetch を他のオブジェクトに入れて渡すときは、グローバルに結び付けたものを渡す
// （そのまま渡してメソッドとして呼ぶと workerd が Illegal invocation を投げる）
const boundFetch = (input, init) => fetch(input, init);

export default {
  async scheduled(controller, env, ctx) {
    // 失敗しても再実行しない（送った後に失敗すると、再実行で二重に送るため）。
    // Cloud Functions 版の retryCount: 0 と同じ考え方。
    if (typeof controller.noRetry === 'function') controller.noRetry();
    const summary = await sendDueNotifications({ env, fetch: boundFetch });
    // 何かした回だけ件数を残す（タスクの中身やトークンは出さない）
    if (summary.due > 0 || summary.error) {
      console.log(JSON.stringify({ event: 'notifications', ...summary }));
    }
  },

  async fetch(request, env) {
    return handleFileRequest(request, env, { fetch: boundFetch });
  },
};
