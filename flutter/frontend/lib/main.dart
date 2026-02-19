import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gilbeot/screens/login_screen.dart';
import 'package:gilbeot/screens/map_screen.dart';
import 'package:gilbeot/services/auth_service.dart';
import 'package:gilbeot/services/recent_searches_service.dart';
import 'package:gilbeot/services/session_storage_local_storage.dart';
import 'package:gilbeot/services/theme_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = '***REMOVED***';
  final persistKey =
      'sb-${Uri.parse(supabaseUrl).host.split('.').first}-auth-token';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey:
        '***REMOVED***',
    authOptions: FlutterAuthClientOptions(
      localStorage: SessionStorageLocalStorage(persistSessionKey: persistKey),
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();
  // This widget is the root of your application.
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get currentThemeMode => _themeMode;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final mode = await ThemeService.loadTheme();
    setState(() {
      _themeMode = mode;
    });
  }

  Future<void> changeTheme(ThemeMode mode) async {
    await ThemeService.saveTheme(mode);
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      themeMode: _themeMode,

      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a green toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.blue
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        cardColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00C853)),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),

        fontFamily: 'Pretendard',
      ),

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00C853),
          brightness: Brightness.dark,
        ),
        textTheme: const TextTheme(),
        fontFamily: 'Pretendard',
      ),

      home: const LoginScreenWrapper(),
    );
  }
}

/// 첫 화면은 항상 로그인. 세션이 있으면 한 프레임 후 지도로 이동.
class LoginScreenWrapper extends StatefulWidget {
  const LoginScreenWrapper({super.key});

  @override
  State<LoginScreenWrapper> createState() => _LoginScreenWrapperState();
}

class _LoginScreenWrapperState extends State<LoginScreenWrapper> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // 첫 프레임 이후에만 세션 확인 → 항상 로그인 화면이 먼저 보이도록
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirectIfSession());
    _authSub = AuthService.onAuthStateChange.listen((data) {
      // 로그인/로그아웃 시 최근 검색 목록을 현재 사용자 기준으로 갱신
      RecentSearchesService.reload();
      if (data.session != null) _redirectIfSession();
    });
  }

  void _redirectIfSession() {
    if (!mounted) return;
    if (AuthService.currentUser != null) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MapScreen()));
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const LoginScreen();
}
