import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;

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

  /// 로그아웃
  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('SignOut Error: $e');
      rethrow;
    }
  }

  /// 현재 로그인된 사용자 가져오기
  static User? get currentUser => _client.auth.currentUser;

  /// 로그인 상태 변경 감지 스트림
  static Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;
}
