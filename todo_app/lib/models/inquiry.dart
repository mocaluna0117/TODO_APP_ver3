part of '../main.dart';

// 問い合わせを閲覧できるアカウント。
// 実際の権限は Firestore のセキュリティルールで担保しており、ここは
// 画面に項目を出すかどうかの判定にだけ使う。
const List<String> kInquiryAdminEmails = [
  'daibon20020117@gmail.com',
  'daibon0117.bin@gmail.com',
];

// 添付できる拡張子（画像とPDF）
const List<String> kInquiryFileExtensions = ['png', 'jpg', 'jpeg', 'pdf'];

// 設定画面から送る問い合わせ。
// 添付ファイルの実体は Storage に置き、ここには URL と表示名だけを持つ。
class Inquiry {
  const Inquiry({
    required this.id,
    required this.email,
    required this.message,
    required this.files,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String message;
  final List<TaskFile> files;
  final DateTime? createdAt;

  static Inquiry fromDoc(String id, Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    return Inquiry(
      id: id,
      email: data['email']?.toString() ?? '',
      message: data['message']?.toString() ?? '',
      files: taskFilesFromJson(data['files']),
      // 送信直後はサーバー側の時刻がまだ入っていないことがある
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}
