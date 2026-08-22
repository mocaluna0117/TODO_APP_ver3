part of '../main.dart';

// ─────────────────────────────────────────────
// アプリ本体（StatefulWidget でテーマ変更対応）
// ─────────────────────────────────────────────
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppSettings _settings = AppSettings();
  bool _isSettingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settings.loadFromPrefs();
    setState(() {
      _isSettingsLoaded = true;
    });
  }

  void _onSettingsChanged() => setState(() {});

  // 明暗どちらのテーマも同じ形で組み立てる。
  // カード・シート・入力欄の色は各画面が AppSettings の配色ゲッターを見るので、
  // ここでは全体の下地と、Flutter標準のウィジェットが使う色だけを決める。
  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? AppSettings.darkSurface : Colors.white;
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: isDark
          ? AppSettings.darkBackground
          : AppSettings.lightBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: _settings.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Color(0xAAFFFFFF),
        indicatorColor: Colors.white,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _settings.accentColor,
        foregroundColor: Colors.white,
      ),
      // ダイアログ・シートは明示的に指定しないと明るいままになる
      dialogTheme: DialogThemeData(backgroundColor: surface),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface),
      cardColor: surface,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSettingsLoaded) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // 配色ゲッター（s.surfaceColor など）が参照する値を、描画前に確定させる。
    // system のときは端末の設定に従うので、ここで解決する。
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    _settings.isDarkMode = switch (_settings.themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformBrightness == Brightness.dark,
    };

    return MaterialApp(
      title: _settings.appTitle,
      debugShowCheckedModeBanner: false,
      themeMode: _settings.themeMode,
      darkTheme: _buildTheme(Brightness.dark),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja')],
      locale: const Locale('ja'),
      theme: _buildTheme(Brightness.light),
      // OSの文字サイズ設定が極端でもレイアウトが崩れないよう拡大率を制限
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.2,
            ),
          ),
          child: child!,
        );
      },
      home: AuthGate(
        settings: _settings,
        onSettingsChanged: _onSettingsChanged,
      ),
    );
  }
}
