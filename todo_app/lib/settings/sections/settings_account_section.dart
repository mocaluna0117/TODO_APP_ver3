part of '../../settings_page.dart';

extension _SettingsAccountSection on _SettingsPageState {
  List<Widget> _buildAccountSection() {
    // サインアウト手段が無い場合（未ログイン等）はセクションを表示しない
    if (widget.onSignOut == null) return const [];

    return [
      _buildSectionHeader('アカウント'),
      _buildCard(
        children: [
          ListTile(
            leading: Icon(Icons.account_circle, color: s.primaryColor),
            title: const Text('ログイン中'),
            subtitle: Text(
              widget.userEmail ?? '(メールアドレス不明)',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          _divider(),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red.shade400),
            title: Text(
              'ログアウト',
              style: TextStyle(color: Colors.red.shade400),
            ),
            onTap: _confirmSignOut,
          ),
        ],
      ),
    ];
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              'ログアウト',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final signOut = widget.onSignOut;
    if (signOut == null) return;
    try {
      await signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ログアウトに失敗しました: $e')));
      return;
    }
    if (!mounted) return;
    // 設定ページはホーム画面の上に push されているため、ここで閉じないと
    // ログアウト後もこの画面が残り続け、何も起きていないように見えてしまう。
    // ルートまで戻すと AuthGate がサインイン画面に切り替わる。
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
