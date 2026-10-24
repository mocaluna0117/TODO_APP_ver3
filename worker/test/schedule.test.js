// planDelivery（送信予定のうち何を送り何を残すか）のテスト。
// todo_app/functions/test/schedule.test.js の7件を、Worker 側の写しに対して動かす。
import test from 'node:test';
import assert from 'node:assert/strict';
import { planDelivery, MAX_SEND_DELAY_MS } from '../src/schedule.js';

// Firestore の Timestamp の代わり（toMillis だけあればよい）
const at = (iso) => ({ toMillis: () => Date.parse(iso) });
const entry = (iso, body) => ({ sendAt: at(iso), body });
const NOW = Date.parse('2026-10-14T09:00:00Z');

test('時刻が来た分は最後の1件だけ送り、残りは昇順で残す', () => {
  const result = planDelivery(
    [
      entry('2026-10-14T08:00:00Z', '1時間前'),
      entry('2026-10-14T08:50:00Z', '10分前'),
      entry('2026-10-14T09:00:00Z', '期限の時間'),
      entry('2026-10-15T09:00:00Z', '翌日'),
    ],
    NOW,
  );
  assert.equal(result.toSend.body, '期限の時間');
  assert.deepEqual(
    result.remaining.map((e) => e.body),
    ['翌日'],
  );
  assert.equal(result.expired, false);
});

test('時刻が来た分が無ければ何も送らない', () => {
  const result = planDelivery([entry('2026-10-14T10:00:00Z', '後で')], NOW);
  assert.equal(result.toSend, null);
  assert.equal(result.remaining.length, 1);
  assert.equal(result.expired, false);
});

test('1日を過ぎた予定は送らずに捨てる（止まっていた間の分）', () => {
  const result = planDelivery(
    [
      entry('2026-10-12T08:00:00Z', '2日前の予定'),
      entry('2026-10-13T08:59:59Z', '1日と1秒前の予定'),
      entry('2026-10-20T09:00:00Z', 'まだ先'),
    ],
    NOW,
  );
  assert.equal(result.toSend, null);
  assert.equal(result.expired, true);
  assert.deepEqual(
    result.remaining.map((e) => e.body),
    ['まだ先'],
  );
});

test('ちょうど1日遅れまでは送る', () => {
  const sendAt = new Date(NOW - MAX_SEND_DELAY_MS).toISOString();
  const result = planDelivery([entry(sendAt, 'ぎりぎり')], NOW);
  assert.equal(result.toSend.body, 'ぎりぎり');
  assert.equal(result.expired, false);
});

test('古い分と新しい分が混ざっていれば、新しい1件を送る', () => {
  const result = planDelivery(
    [
      entry('2026-10-10T09:00:00Z', '古い'),
      entry('2026-10-14T08:59:00Z', '1分前'),
    ],
    NOW,
  );
  assert.equal(result.toSend.body, '1分前');
  assert.equal(result.expired, false);
});

test('並び順が崩れていても、送る1件と次回の時刻は時刻順で決める', () => {
  const result = planDelivery(
    [
      entry('2026-10-14T08:59:00Z', '1分前'),
      entry('2026-10-14T08:00:00Z', '1時間前'),
      entry('2026-10-16T09:00:00Z', '2日後'),
      entry('2026-10-15T09:00:00Z', '1日後'),
    ],
    NOW,
  );
  assert.equal(result.toSend.body, '1分前');
  assert.deepEqual(
    result.remaining.map((e) => e.body),
    ['1日後', '2日後'],
  );
});

test('壊れた entries は無視する', () => {
  assert.deepEqual(planDelivery(undefined, NOW), {
    toSend: null,
    remaining: [],
    expired: false,
  });
  const result = planDelivery(
    [null, {}, { sendAt: '2026-10-14T08:00:00Z' }, entry('2026-10-14T08:30:00Z', '正しい')],
    NOW,
  );
  assert.equal(result.toSend.body, '正しい');
  assert.equal(result.remaining.length, 0);
});
