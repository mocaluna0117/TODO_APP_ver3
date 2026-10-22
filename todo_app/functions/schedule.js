// 送信予定（entries）のうち、今回の実行で何を送り、何を残すかを決める。
// Firebase に依存しない純粋な関数にして、node --test で確かめられるようにする。

// これより古くなった予定は送らずに捨てる（1日）。
// 関数が止まっていた間（課金の停止など）にたまった予定を、再開した瞬間に
// 何日も遅れて鳴らさないため。Web へ送るときの保持期間（TTL）と同じ長さ。
const MAX_SEND_DELAY_MS = 24 * 60 * 60 * 1000;

function sendAtMillis(entry) {
  return entry.sendAt.toMillis();
}

// entries: [{ sendAt: Timestamp, body }]（sendAt は toMillis() を持つもの）
// 返り値:
//   toSend    … 今回送る1件。時刻が来た分が複数あっても最後の1件だけ。無ければ null
//   remaining … まだ時刻が来ていない分（送信時刻の昇順）
//   expired   … 時刻が来た分があったのに、古すぎて送らなかったら true
function planDelivery(entries, nowMillis, maxDelayMs = MAX_SEND_DELAY_MS) {
  const valid = (Array.isArray(entries) ? entries : []).filter(
    (entry) =>
      entry && entry.sendAt && typeof entry.sendAt.toMillis === 'function',
  );
  const due = valid
    .filter((entry) => sendAtMillis(entry) <= nowMillis)
    .sort((a, b) => sendAtMillis(a) - sendAtMillis(b));
  const remaining = valid
    .filter((entry) => sendAtMillis(entry) > nowMillis)
    .sort((a, b) => sendAtMillis(a) - sendAtMillis(b));

  // 同じタスクで複数件たまっていても、鳴らすのは最後の1件だけにする
  // （通知が一度に何度も出るのを避ける）
  const latest = due.length > 0 ? due[due.length - 1] : null;
  const isFresh =
    latest !== null && nowMillis - sendAtMillis(latest) <= maxDelayMs;

  return {
    toSend: isFresh ? latest : null,
    remaining,
    expired: latest !== null && !isFresh,
  };
}

module.exports = { planDelivery, MAX_SEND_DELAY_MS };
