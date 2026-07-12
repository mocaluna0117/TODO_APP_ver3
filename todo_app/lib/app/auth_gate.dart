part of '../main.dart';

// ─────────────────────────────────────────────
// 認証ゲート：ログイン状態に応じて画面を切り替える
// ─────────────────────────────────────────────
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  final AppSettings settings;
  final VoidCallback onSettingsChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
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
          settings: settings,
          onSettingsChanged: onSettingsChanged,
          userEmail: user.email,
          onSignOut: () => FirebaseAuth.instance.signOut(),
        );
      },
    );
  }
}
