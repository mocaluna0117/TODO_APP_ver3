part of '../main.dart';

// ─────────────────────────────────────────────
// 認証ゲート：ログイン状態に応じて画面を切り替える
// ─────────────────────────────────────────────
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  final AppSettings settings;
  final VoidCallback onSettingsChanged;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // 認証ストリームは一度だけ生成する。build 内で生成すると再描画のたびに
  // 再購読が起きて画面がちらつき、無限リビルドの原因になる。
  final Stream<User?> _authStream = FirebaseAuth.instance.authStateChanges();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        // 認証状態の確認中
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        // 未ログイン → サインイン画面
        if (user == null) {
          return const SignInPage();
        }

        // ログイン済み → アプリ本体
        return TodoHomePage(
          settings: widget.settings,
          onSettingsChanged: widget.onSettingsChanged,
          userEmail: user.email,
          onSignOut: () => FirebaseAuth.instance.signOut(),
        );
      },
    );
  }
}
