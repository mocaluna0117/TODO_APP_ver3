// 旧 Storage から KV へ移すときの対応づけ（scripts/legacy-to-kv.mjs）のテスト。
import test from 'node:test';
import assert from 'node:assert/strict';
import { planLegacyUploads, fileNameFromDisposition } from '../scripts/legacy-to-kv.mjs';

const TOKEN = '3f2c1d4e-5a6b-4c7d-8e9f-0a1b2c3d4e5f';

test('gcloud の --raw の形と、--raw なしの形のどちらでも読める', () => {
  const objects = [
    {
      name: 'users/uidA/todos/123/1720000000000000_0.jpg',
      contentType: 'image/png',
      size: '1000',
      contentDisposition: 'inline',
      metadata: { firebaseStorageDownloadTokens: TOKEN },
    },
    {
      name: 'users/uidA/todos/124/1720000000000001_0.pdf',
      content_type: 'application/pdf',
      size: 2000,
      content_disposition: 'inline; filename="mitsumori.pdf"',
      custom_fields: { firebaseStorageDownloadTokens: `${TOKEN.replace('3f', '4f')}` },
    },
  ];
  const { uploads, skipped } = planLegacyUploads(objects, 'rescue', () => true);
  assert.deepEqual(skipped, []);
  assert.deepEqual(uploads.map((u) => u.key), [
    `f/uidA/todos/123/${TOKEN}`,
    `f/uidA/todos/124/${TOKEN.replace('3f', '4f')}`,
  ]);
  assert.equal(uploads[0].file, 'rescue/users/uidA/todos/123/1720000000000000_0.jpg');
  assert.deepEqual(uploads[1].metadata, { contentType: 'application/pdf', fileName: 'mitsumori.pdf' });
});

test('トークンが無い・種類が違う・未ダウンロード・形の違うものは飛ばす', () => {
  const base = { contentType: 'image/jpeg', size: 1, metadata: { firebaseStorageDownloadTokens: TOKEN } };
  const { uploads, skipped } = planLegacyUploads(
    [
      { ...base, name: 'users/u/todos/1/a.jpg', metadata: {} },
      { ...base, name: 'users/u/todos/1/b.html', contentType: 'text/html' },
      { ...base, name: 'users/u/todos/1/c.jpg' },
      { ...base, name: 'users/u/other/1/d.jpg' },
    ],
    'rescue',
    (file) => !file.endsWith('c.jpg'),
  );
  assert.equal(uploads.length, 0);
  assert.deepEqual(skipped.map((s) => s.reason), ['no-token', 'content-type', 'not-downloaded', 'path']);
});

test('Content-Disposition から元のファイル名を取り出す', () => {
  assert.equal(fileNameFromDisposition('inline; filename="a b.pdf"'), 'a b.pdf');
  assert.equal(fileNameFromDisposition("inline; filename*=UTF-8''%E8%A6%8B.pdf"), '見.pdf');
  assert.equal(fileNameFromDisposition('inline'), '');
  assert.equal(fileNameFromDisposition(undefined), '');
});
