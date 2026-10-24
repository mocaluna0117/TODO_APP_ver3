// 旧 Firebase Storage（todo-app-mokuson.firebasestorage.app）の添付を、
// Worker の KV へ移すためのスクリプト。課金を一時的に戻してバケットから
// ダウンロードしたあとで、手元のファイルを KV に入れる（README の手順）。
//
//   node scripts/legacy-to-kv.mjs --objects rescue/objects.json --dir rescue          … 件数だけ確認
//   node scripts/legacy-to-kv.mjs --objects rescue/objects.json --dir rescue --apply  … KV に書く
//
// objects.json は `gcloud storage objects list "gs://<bucket>/users/**" --raw --format=json`
// の出力。各ファイルは、ダウンロードトークンを ID にしたキー（src/files.js の
// legacyKeyFromObject）に入れる。アプリは旧 URL をこの同じ規則で読み替えるので、
// Firestore の URL は書き換えなくてよい。
//
// KV の書き込みは1件1回（Workers Free は1日1,000回まで）。--apply では
// `npx wrangler kv key put` を1件ずつ呼ぶ（wrangler login 済みであること）。
// ファイルの中身・トークン・利用者 ID は画面に出さない。
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { legacyKeyFromObject, ALLOWED_CONTENT_TYPES, MAX_UPLOAD_BYTES } from '../src/files.js';

// Content-Disposition の filename="..." から元のファイル名を取り出す
export function fileNameFromDisposition(value) {
  if (typeof value !== 'string') return '';
  const star = /filename\*=UTF-8''([^;]+)/i.exec(value);
  if (star) {
    try {
      return decodeURIComponent(star[1]);
    } catch (_) {
      // 下の filename= に任せる
    }
  }
  const plain = /filename="([^"]*)"/i.exec(value);
  return plain ? plain[1] : '';
}

// objects: gcloud の --raw の JSON（API と同じ形）か、--raw なしの形のどちらでもよい
export function planLegacyUploads(objects, dir, exists = fs.existsSync) {
  const uploads = [];
  const skipped = [];
  for (const object of objects) {
    const name = object.name || '';
    const custom = object.metadata || object.custom_fields || {};
    const tokens = String(custom.firebaseStorageDownloadTokens || '')
      .split(',')
      .map((t) => t.trim())
      .filter(Boolean);
    const contentType = object.contentType || object.content_type || '';
    const size = Number(object.size || 0);
    const file = path.join(dir, ...name.split('/'));
    if (tokens.length === 0) {
      skipped.push({ reason: 'no-token' });
      continue;
    }
    if (!ALLOWED_CONTENT_TYPES.has(contentType)) {
      skipped.push({ reason: 'content-type' });
      continue;
    }
    if (size > MAX_UPLOAD_BYTES) {
      skipped.push({ reason: 'too-large' });
      continue;
    }
    if (!exists(file)) {
      skipped.push({ reason: 'not-downloaded' });
      continue;
    }
    const fileName = fileNameFromDisposition(object.contentDisposition || object.content_disposition);
    // トークンが複数あれば、どの URL からでも読めるよう全部に入れる
    for (const token of tokens) {
      const key = legacyKeyFromObject(name, token);
      if (!key) {
        skipped.push({ reason: 'path' });
        continue;
      }
      uploads.push({ key, file, size, metadata: { contentType, fileName } });
    }
  }
  return { uploads, skipped };
}

function parseArgs(argv) {
  const args = { apply: false };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--apply') args.apply = true;
    else if (argv[i] === '--objects') args.objects = argv[++i];
    else if (argv[i] === '--dir') args.dir = argv[++i];
  }
  return args;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.objects || !args.dir) {
    console.error('usage: node scripts/legacy-to-kv.mjs --objects <objects.json> --dir <download dir> [--apply]');
    process.exit(2);
  }
  const objects = JSON.parse(fs.readFileSync(args.objects, 'utf8'));
  const { uploads, skipped } = planLegacyUploads(objects, args.dir);
  const bytes = uploads.reduce((sum, u) => sum + u.size, 0);
  const reasons = skipped.reduce((acc, s) => ({ ...acc, [s.reason]: (acc[s.reason] || 0) + 1 }), {});
  console.log(JSON.stringify({ objects: objects.length, uploads: uploads.length, bytes, skipped: reasons }));
  if (!args.apply) return;
  let done = 0;
  for (const upload of uploads) {
    execFileSync(
      'npx',
      ['wrangler', 'kv', 'key', 'put', upload.key, '--path', upload.file,
        '--metadata', JSON.stringify(upload.metadata), '--binding', 'FILES', '--remote'],
      { stdio: ['ignore', 'ignore', 'inherit'] },
    );
    done++;
    if (done % 10 === 0 || done === uploads.length) console.log(`${done}/${uploads.length}`);
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  main();
}
