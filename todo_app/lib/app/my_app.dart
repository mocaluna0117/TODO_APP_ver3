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

  @override
  Widget build(BuildContext context) {
    if (!_isSettingsLoaded) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: _settings.appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja')],
      locale: const Locale('ja'),
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F5FA),
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
      ),
      home: TodoHomePage(
        settings: _settings,
        onSettingsChanged: _onSettingsChanged,
      ),
    );
  }
}
