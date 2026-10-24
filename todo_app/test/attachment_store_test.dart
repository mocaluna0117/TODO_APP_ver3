// 添付ファイルの置き場（Cloudflare Worker）とのやり取りのテスト。
// 通信は MockClient に差し替え、本物の Worker にはつながない。
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todo_app/attachment_store.dart';
import 'package:todo_app/main.dart';

const base = 'https://todo-app-worker.example.workers.dev';
const token = '3f2c1d4e-5a6b-4c7d-8e9f-0a1b2c3d4e5f';

String legacyUrl(String objectPath, {String tokenValue = token}) =>
    'https://firebasestorage.googleapis.com/v0/b/todo-app-mokuson.firebasestorage.app/o/'
    '${Uri.encodeComponent(objectPath)}?alt=media&token=$tokenValue';

void main() {
  group('旧 Firebase Storage の URL の読み替え', () {
    test('タスクの添付は、ダウンロードトークンを ID にした Worker の URL になる', () {
      // worker/test/files.test.js の legacyKeyFromObject と同じ例
      expect(
        legacyStorageUrlToFilesUrl(
          legacyUrl('users/uidA/todos/123/1720000000000000_0.jpg'),
          base,
        ),
        '$base/f/uidA/todos/123/$token',
      );
    });

    test('問い合わせの添付も読み替える', () {
      expect(
        legacyStorageUrlToFilesUrl(
          legacyUrl('users/uidA/inquiries/1720000000000000_0.pdf'),
          base,
        ),
        '$base/f/uidA/inquiries/$token',
      );
    });

    test('旧 Storage の URL でなければ読み替えない', () {
      expect(
        legacyStorageUrlToFilesUrl('https://example.com/a.jpg', base),
        isNull,
      );
      expect(
        legacyStorageUrlToFilesUrl('$base/f/uidA/todos/1/$token', base),
        isNull,
      );
      expect(
        legacyStorageUrlToFilesUrl(
          legacyUrl('users/uidA/todos/abc/x.jpg'),
          base,
        ),
        isNull,
      );
      expect(
        legacyStorageUrlToFilesUrl(
          legacyUrl('users/uidA/todos/1/x.jpg', tokenValue: 'short'),
          base,
        ),
        isNull,
      );
      // 置き場の URL が未設定なら何もしない
      expect(
        legacyStorageUrlToFilesUrl(legacyUrl('users/uidA/todos/1/x.jpg'), ''),
        isNull,
      );
    });

    test('TodoItem.fromJson で画像と PDF の旧 URL を読み替え、base64 はそのまま', () {
      final saved = attachmentApiBase;
      addTearDown(() => attachmentApiBase = saved);
      attachmentApiBase = base;
      final item = TodoItem.fromJson({
        'id': 123,
        'title': 't',
        'imageBase64List': [
          legacyUrl('users/uidA/todos/123/1_0.jpg'),
          'AAAA',
          '$base/f/uidA/todos/123/BBBBBBBBBBBBBBBBBBBBBB',
        ],
        'attachments': [
          {'url': legacyUrl('users/uidA/todos/123/2_0.pdf'), 'name': '見積書.pdf'},
        ],
      });
      expect(item.imageBase64List, [
        '$base/f/uidA/todos/123/$token',
        'AAAA',
        '$base/f/uidA/todos/123/BBBBBBBBBBBBBBBBBBBBBB',
      ]);
      expect(item.attachments.single.url, '$base/f/uidA/todos/123/$token');
      expect(item.attachments.single.name, '見積書.pdf');
    });

    test('置き場の URL が未設定なら、読み込んだ URL を変えない', () {
      final saved = attachmentApiBase;
      addTearDown(() => attachmentApiBase = saved);
      attachmentApiBase = '';
      final url = legacyUrl('users/uidA/todos/123/1_0.jpg');
      final item = TodoItem.fromJson({
        'id': 123,
        'title': 't',
        'imageBase64List': [url],
      });
      expect(item.imageBase64List, [url]);
    });
  });

  group('AttachmentStore', () {
    AttachmentStore storeWith(
      MockClient client, {
      String? idToken = 'id-token',
      String baseUrl = base,
    }) => AttachmentStore(
      baseUrl: baseUrl,
      idToken: () async => idToken,
      client: client,
    );

    test('アップロードは ID トークン・種類・ファイル名を付けて送り、URL を返す', () async {
      late http.Request sent;
      final store = storeWith(
        MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({'url': '$base/f/uidA/todos/7/CCCCCCCCCCCCCCCCCCCCCC'}),
            201,
          );
        }),
      );
      final bytes = Uint8List.fromList([1, 2, 3]);
      final url = await store.upload(
        folder: 'todos/7',
        bytes: bytes,
        contentType: 'application/pdf',
        fileName: '見積書 "最終".pdf',
      );
      expect(url, '$base/f/uidA/todos/7/CCCCCCCCCCCCCCCCCCCCCC');
      expect(sent.method, 'POST');
      expect(sent.url.toString(), '$base/upload/todos/7');
      expect(sent.headers['Authorization'], 'Bearer id-token');
      expect(sent.headers['Content-Type'], 'application/pdf');
      expect(Uri.decodeComponent(sent.headers['X-File-Name']!), '見積書 "最終".pdf');
      expect(sent.bodyBytes, bytes);
    });

    test('アップロードに失敗したら例外にする（呼び出し側が次の保存で送り直す）', () async {
      final store = storeWith(
        MockClient(
          (_) async => http.Response('{"error":"store-unavailable"}', 503),
        ),
      );
      expect(
        () => store.upload(
          folder: 'todos/7',
          bytes: Uint8List(1),
          contentType: 'image/jpeg',
        ),
        throwsA(
          isA<AttachmentStoreException>().having(
            (e) => e.statusCode,
            'statusCode',
            503,
          ),
        ),
      );
    });

    test('他所の URL が返ってきたら受け取らない', () async {
      final store = storeWith(
        MockClient(
          (_) async =>
              http.Response(jsonEncode({'url': 'https://evil.example/x'}), 201),
        ),
      );
      expect(
        () => store.upload(
          folder: 'todos/7',
          bytes: Uint8List(1),
          contentType: 'image/jpeg',
        ),
        throwsA(isA<AttachmentStoreException>()),
      );
    });

    test('未ログイン・置き場が未設定なら通信せずに失敗する', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('', 500);
      });
      expect(
        () => storeWith(client, idToken: null).upload(
          folder: 'todos/1',
          bytes: Uint8List(1),
          contentType: 'image/jpeg',
        ),
        throwsA(isA<AttachmentStoreException>()),
      );
      expect(
        () => storeWith(client, baseUrl: '').upload(
          folder: 'todos/1',
          bytes: Uint8List(1),
          contentType: 'image/jpeg',
        ),
        throwsA(isA<AttachmentStoreException>()),
      );
      expect(storeWith(client, baseUrl: '').isConfigured, isFalse);
      expect(calls, 0);
    });

    test('読み込みは中身を返し、無い・大きすぎるときは例外にする', () async {
      final store = storeWith(
        MockClient((request) async {
          if (request.url.path.endsWith('missing0000000000000000')) {
            return http.Response('', 404);
          }
          return http.Response.bytes([9, 8, 7], 200);
        }),
      );
      expect(
        await store.download(
          '$base/f/u/todos/1/AAAAAAAAAAAAAAAAAAAAAA',
          maxBytes: 10,
        ),
        [9, 8, 7],
      );
      expect(
        () => store.download(
          '$base/f/u/todos/1/missing0000000000000000',
          maxBytes: 10,
        ),
        throwsA(isA<AttachmentStoreException>()),
      );
      expect(
        () => store.download(
          '$base/f/u/todos/1/AAAAAAAAAAAAAAAAAAAAAA',
          maxBytes: 2,
        ),
        throwsA(isA<AttachmentStoreException>()),
      );
    });

    test('削除は置き場の URL だけを、ID トークン付きで消す', () async {
      final requests = <http.Request>[];
      final store = storeWith(
        MockClient((request) async {
          requests.add(request);
          return http.Response(
            '',
            request.url.path.contains('gone') ? 404 : 204,
          );
        }),
      );
      await store.deleteUrl(legacyUrl('users/u/todos/1/x.jpg'));
      await store.deleteUrl('https://example.com/a.jpg');
      expect(requests, isEmpty);

      await store.deleteUrl('$base/f/u/todos/1/AAAAAAAAAAAAAAAAAAAAAA');
      // 既に無いものは消えているのと同じ扱い
      await store.deleteUrl('$base/f/u/todos/1/goneAAAAAAAAAAAAAAAAAA');
      expect(requests.map((r) => r.method), ['DELETE', 'DELETE']);
      expect(requests.first.headers['Authorization'], 'Bearer id-token');
    });

    test('タスクの添付はフォルダごと消す', () async {
      late http.Request sent;
      final store = storeWith(
        MockClient((request) async {
          sent = request;
          return http.Response('{"deleted":2}', 200);
        }),
      );
      await store.deleteTaskFolder(42);
      expect(sent.method, 'DELETE');
      expect(sent.url.toString(), '$base/folder/todos/42');
      expect(sent.headers['Authorization'], 'Bearer id-token');
    });
  });
}
