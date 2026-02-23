import 'package:flutter/foundation.dart';
import 'package:gilbeot/services/pkce_async_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// OAuth 후 앱으로 돌아올 URL (웹: 현재 origin, 모바일: 딥링크)
  static String get _oauthRedirectTo =>
      kIsWeb ? '${Uri.base.origin}/' : 'com.example.gilbeot://auth/callback';

  /// Google 로그인 (1번 방식: Supabase OAuth만 사용, 구글은 Supabase 콜백으로만 리디렉션)
  static Future<void> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _oauthRedirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Google SignIn Error: $e');
      rethrow;
    }
  }

  /// 카카오 로그인 (1번 방식: Supabase OAuth만 사용, 구글과 동일)
  /// 웹: 현재 origin으로 복귀(포트 변경해도 동작), 모바일: 딥링크로 앱 복귀.
  static Future<void> signInWithKakao() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.kakao,
        redirectTo: _oauthRedirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Kakao SignIn Error: $e');
      rethrow;
    }
  }

  /// 회원가입 (이메일/비밀번호)
  /// [metadata]에 사용자의 추가 정보 (이름, 닉네임, 휠체어 타입 등)를 저장합니다.
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );
      return response;
    } catch (e) {
      debugPrint('SignUp Error: $e');
      rethrow;
    }
  }

  /// 로그인 (이메일/비밀번호)
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      debugPrint('SignIn Error: $e');
      rethrow;
    }
  }

  /// 로그아웃 (OAuth PKCE code_verifier 키 삭제 → 재로그인 시 새 PKCE로 진행)
  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(supabasePkceCodeVerifierKey);
      debugPrint('>>> [OAuth] 로그아웃: PKCE code_verifier 키 삭제');
    } catch (e) {
      debugPrint('SignOut Error: $e');
      rethrow;
    }
  }

  /// 현재 로그인된 사용자 가져오기
  static User? get currentUser => _client.auth.currentUser;

  /// 로그인 상태 변경 감지 스트림
  static Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// 인증 메일 다시 보내기 (회원가입 인증 링크)
  static Future<void> resendVerificationEmail(String email) async {
    try {
      await _client.auth.resend(type: OtpType.signup, email: email);
    } catch (e) {
      debugPrint('Resend Verification Error: $e');
      rethrow;
    }
  }
}
