import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gilbeot/app_route_observer.dart';
import 'package:gilbeot/screens/login_screen.dart';
import 'package:gilbeot/screens/map_screen.dart';
import 'package:gilbeot/services/auth_service.dart';
import 'package:gilbeot/services/recent_searches_service.dart';
import 'package:gilbeot/services/session_storage_local_storage.dart';
import 'package:gilbeot/services/theme_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

bool _isOurAuthScheme(Uri uri) =>
    uri.scheme == 'com.example.gilbeot' && uri.host == 'auth';

bool _isAuthCallbackUri(Uri uri) {
  if (uri.scheme != 'com.example.gilbeot' || uri.host != 'auth') return false;
  return uri.queryParameters.containsKey('code') ||
      uri.fragment.contains('access_token') ||
      uri.fragment.contains('error_description');
}

String? _lastProcessedAuthCodeOAuth;
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

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
      detectSessionInUri: false,
      pkceAsyncStorage: SharedPreferencesGotrueAsyncStorage(),
    ),
  );

  if (kIsWeb) {
    // 웹: 카카오/구글 로그인 후 리다이렉트된 URL에서 세션 복구 (detectSessionInUri: false라 수동 처리)
    try {
      final uri = Uri.base;
      if (uri.queryParameters.containsKey('code') ||
          uri.fragment.contains('access_token') ||
          uri.fragment.contains('error') ||
          uri.fragment.contains('error_description')) {
        debugPrint('>>> [OAuth] 웹 초기 URI: ${uri.origin}${uri.path} ...');
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
        debugPrint('>>> [OAuth] getSessionFromUrl(웹 초기) 성공');
      }
    } catch (e, st) {
      debugPrint('>>> [OAuth] getSessionFromUrl(웹 초기) 실패: $e\n$st');
    }
  } else {
    try {
      final initialUri = await AppLinks().getInitialLink();
      debugPrint('>>> [OAuth] getInitialLink: $initialUri');
      if (initialUri != null && _isOurAuthScheme(initialUri)) {
        await Supabase.instance.client.auth.getSessionFromUrl(initialUri);
        debugPrint('>>> [OAuth] getSessionFromUrl(초기) 성공');
      }
    } catch (e, st) {
      debugPrint('>>> [OAuth] getSessionFromUrl(초기) 실패: $e\n$st');
    }
  }

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
  StreamSubscription<dynamic>? _oauthEventSub;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    if (!kIsWeb) {
      _oauthEventSub = const EventChannel('com.example.gilbeot/oauth_events')
          .receiveBroadcastStream()
          .listen((dynamic data) => _onOAuthUriFromNative(data));
    }
  }

  @override
  void dispose() {
    _oauthEventSub?.cancel();
    super.dispose();
  }

  static Future<void> _onOAuthUriFromNative(dynamic data) async {
    if (data is! String || data.isEmpty) return;
    final uri = Uri.tryParse(data);
    if (uri == null || !_isOurAuthScheme(uri)) return;
    final code = uri.queryParameters['code'];
    if (code != null && code == _lastProcessedAuthCodeOAuth) {
      debugPrint('>>> [OAuth] (앱 루트) 이미 처리한 code 건너뜀');
      return;
    }
    if (code != null) _lastProcessedAuthCodeOAuth = code;
    debugPrint('>>> [OAuth] (앱 루트) EventChannel 수신: $uri');
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
      debugPrint('>>> [OAuth] getSessionFromUrl 성공');
      _rootNavigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(builder: (_) => const MapScreen()),
      );
    } catch (e, st) {
      debugPrint('>>> [OAuth] getSessionFromUrl 실패: $e\n$st');
      if (code != null) _lastProcessedAuthCodeOAuth = null;
    }
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
      navigatorKey: _rootNavigatorKey,
      navigatorObservers: [routeObserver],
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

class _LoginScreenWrapperState extends State<LoginScreenWrapper>
    with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<Uri?>? _deeplinkSub;
  static final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirectIfSession());
    _authSub = AuthService.onAuthStateChange.listen((data) {
      RecentSearchesService.reload();
      if (data.session != null) {
        _redirectIfSession();
      } else {
        _lastProcessedAuthCodeOAuth = null;
      }
    });
    if (!kIsWeb) {
      _deeplinkSub = _appLinks.uriLinkStream.listen((Uri? uri) {
        debugPrint('>>> [OAuth] uriLinkStream 수신: $uri');
        _handleAuthUri(uri);
      });
    }
  }

  Future<void> _handleAuthUri(Uri? uri) async {
    if (uri == null || !_isOurAuthScheme(uri)) return;
    final code = uri.queryParameters['code'];
    if (code != null && code == _lastProcessedAuthCodeOAuth) {
      debugPrint('>>> [OAuth] 이미 처리한 code 건너뜀 (이중 exchange 방지)');
      if (mounted) _redirectIfSession();
      return;
    }
    if (code != null) _lastProcessedAuthCodeOAuth = code;
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
      debugPrint('>>> [OAuth] getSessionFromUrl 성공');
      if (mounted) _redirectIfSession();
    } catch (e, st) {
      debugPrint('>>> [OAuth] getSessionFromUrl 실패: $e\n$st');
      if (code != null) _lastProcessedAuthCodeOAuth = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (kIsWeb || state != AppLifecycleState.resumed) return;
    void tryGetAuthUri({required int attempt}) {
      if (!mounted) return;
      const channel = MethodChannel('com.example.gilbeot/oauth');
      channel.invokeMethod<String>('getPendingAuthUri').then((String? uriStr) {
        if (!mounted) return;
        if (uriStr != null && uriStr.isNotEmpty) {
          final uri = Uri.parse(uriStr);
          if (_isOurAuthScheme(uri)) {
            debugPrint('>>> [OAuth] resumed (attempt $attempt) → getPendingAuthUri: $uri');
            _handleAuthUri(uri);
            return;
          }
        }
        _appLinks.getLatestLink().then((Uri? uri) {
          if (!mounted) return;
          if (uri == null || !_isOurAuthScheme(uri)) return;
          debugPrint('>>> [OAuth] resumed (attempt $attempt) → getLatestLink: $uri');
          _handleAuthUri(uri);
        });
      }).catchError((_) {
        if (!mounted) return;
        _appLinks.getLatestLink().then((Uri? uri) {
          if (uri == null || !_isOurAuthScheme(uri)) return;
          debugPrint('>>> [OAuth] resumed (attempt $attempt) → getLatestLink: $uri');
          _handleAuthUri(uri);
        });
      });
    }
    Future.delayed(const Duration(milliseconds: 300), () => tryGetAuthUri(attempt: 1));
    Future.delayed(const Duration(milliseconds: 600), () => tryGetAuthUri(attempt: 2));
    Future.delayed(const Duration(milliseconds: 500), () => tryGetAuthUri(attempt: 3));
    Future.delayed(const Duration(milliseconds: 1000), () => tryGetAuthUri(attempt: 4));
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
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _deeplinkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const LoginScreen();
}
