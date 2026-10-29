// 添付ファイル（タスクの画像・PDF、問い合わせの添付）の置き場とのやり取り。
//
// 実体は Cloudflare Workers KV に置き、Worker（リポジトリの worker/）が出し入れする。
// Firebase は無料の Spark プランで使うため、Cloud Storage は使わない
// （Spark ではバケットにアクセスできない）。
//
//   アップロード: POST {base}/upload/todos/{taskId}（ID トークンが必要）→ { url }
//   読み出し    : GET  {url}（URL に推測できない ID が入っていて、URL を知っていれば読める。
//                 Firebase Storage のダウンロード URL と同じ考え方）
//   削除        : DELETE {url} / DELETE {base}/folder/todos/{taskId}（ID トークンが必要）
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Worker の URL（末尾の / なし）。
///
/// Worker を公開したら `https://todo-app-worker.<アカウントのサブドメイン>.workers.dev`
/// をここに書く。ビルド時に `--dart-define=ATTACHMENT_API_BASE=...` でも上書きできる。
/// 空のままだと、添付のアップロードは「保存先が設定されていない」として失敗する。
const String kDefaultAttachmentApiBase = '';

/// 実行中に使う Worker の URL（テストで差し替えられるよう変数にしてある）。
String attachmentApiBase = const String.fromEnvironment(
  'ATTACHMENT_API_BASE',
  defaultValue: kDefaultAttachmentApiBase,
);

class AttachmentStoreException implements Exception {
  const AttachmentStoreException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'AttachmentStoreException($statusCode): $message';
}

class AttachmentStore {
  AttachmentStore({
    required this.baseUrl,
    required this.idToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Worker の URL（末尾の / なし）。空なら未設定。
  final String baseUrl;

  /// ログイン中の利用者の Firebase ID トークンを返す（未ログインなら null）。
  final Future<String?> Function() idToken;

  final http.Client _client;

  bool get isConfigured => baseUrl.isNotEmpty;

  /// この置き場の URL か（旧 Firebase Storage の URL や外部の URL ではないか）。
  bool ownsUrl(String url) => isConfigured && url.startsWith('$baseUrl/f/');

  Future<Map<String, String>> _authHeaders() async {
    final token = await idToken();
    if (token == null || token.isEmpty) {
      throw const AttachmentStoreException('not signed in');
    }
    return {'Authorization': 'Bearer $token'};
  }

  void _requireConfigured() {
    if (!isConfigured) {
      throw const AttachmentStoreException(
        'attachment store is not configured',
      );
    }
  }

  /// 1件アップロードして、読み出し用の URL を返す。
  /// [folder] は `todos/{taskId}` か `inquiries`。
  Future<String> upload({
    required String folder,
    required Uint8List bytes,
    required String contentType,
    String? fileName,
  }) async {
    _requireConfigured();
    final headers = {
      ...await _authHeaders(),
      'Content-Type': contentType,
      if (fileName != null && fileName.isNotEmpty)
        'X-File-Name': Uri.encodeComponent(fileName),
    };
    final response = await _client.post(
      Uri.parse('$baseUrl/upload/$folder'),
      headers: headers,
      body: bytes,
    );
    if (response.statusCode != 201) {
      throw AttachmentStoreException(
        'upload failed',
        statusCode: response.statusCode,
      );
    }
    final url = (jsonDecode(response.body) as Map<String, dynamic>)['url'];
    if (url is! String || !ownsUrl(url)) {
      throw const AttachmentStoreException('unexpected upload response');
    }
    return url;
  }

  /// URL の中身を読み込む（タスクの複製で実体をコピーするときに使う）。
  Future<Uint8List> download(String url, {required int maxBytes}) async {
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw AttachmentStoreException(
        'download failed',
        statusCode: response.statusCode,
      );
    }
    final bytes = response.bodyBytes;
    if (bytes.length > maxBytes) {
      throw const AttachmentStoreException('file too large');
    }
    return bytes;
  }

  /// 1件削除する。この置き場の URL でなければ何もしない。
  Future<void> deleteUrl(String url) async {
    if (!ownsUrl(url)) return;
    final response = await _client.delete(
      Uri.parse(url),
      headers: await _authHeaders(),
    );
    // 既に無い（404）なら消えているのと同じ
    if (response.statusCode != 204 && response.statusCode != 404) {
      throw AttachmentStoreException(
        'delete failed',
        statusCode: response.statusCode,
      );
    }
  }

  /// タスクの添付をまとめて削除する。
  Future<void> deleteTaskFolder(int taskId) async {
    _requireConfigured();
    final response = await _client.delete(
      Uri.parse('$baseUrl/folder/todos/$taskId'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw AttachmentStoreException(
        'folder delete failed',
        statusCode: response.statusCode,
      );
    }
  }
}

final RegExp _uidPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
final RegExp _taskIdPattern = RegExp(r'^[0-9]{1,20}$');
final RegExp _fileIdPattern = RegExp(r'^[A-Za-z0-9_-]{16,64}$');

/// 旧 Firebase Storage のダウンロード URL を、移した先（Worker）の URL に読み替える。
///
/// 旧 URL: `https://firebasestorage.googleapis.com/v0/b/{bucket}/o/users%2F{uid}%2Ftodos%2F{taskId}%2F{file}?alt=media&token={token}`
/// 新 URL: `{base}/f/{uid}/todos/{taskId}/{token}`
///
/// ダウンロードトークン（推測できない UUID）を、そのまま新しい URL の ID にする。
/// worker/src/files.js の legacyKeyFromObject と同じ規則なので、
/// worker/scripts/legacy-to-kv.mjs で移したファイルがこの URL で読める。
/// 旧 URL でなければ null。
String? legacyStorageUrlToFilesUrl(String url, String baseUrl) {
  if (baseUrl.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host != 'firebasestorage.googleapis.com') return null;
  final segments = uri.pathSegments;
  if (segments.length != 5 ||
      segments[0] != 'v0' ||
      segments[1] != 'b' ||
      segments[3] != 'o') {
    return null;
  }
  final token = uri.queryParameters['token'];
  if (token == null || !_fileIdPattern.hasMatch(token)) return null;
  final objectPath = segments[4].split('/');
  if (objectPath.length == 5 &&
      objectPath[0] == 'users' &&
      objectPath[2] == 'todos' &&
      _uidPattern.hasMatch(objectPath[1]) &&
      _taskIdPattern.hasMatch(objectPath[3])) {
    return '$baseUrl/f/${objectPath[1]}/todos/${objectPath[3]}/$token';
  }
  if (objectPath.length == 4 &&
      objectPath[0] == 'users' &&
      objectPath[2] == 'inquiries' &&
      _uidPattern.hasMatch(objectPath[1])) {
    return '$baseUrl/f/${objectPath[1]}/inquiries/$token';
  }
  return null;
}

/// 読み込んだ添付の URL を今の置き場の形にそろえる（旧 Storage の URL なら読み替える）。
String migrateLegacyAttachmentUrl(String url) =>
    legacyStorageUrlToFilesUrl(url, attachmentApiBase) ?? url;
