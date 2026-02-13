import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_storage_impl_web.dart'
    if (dart.library.io) 'session_storage_impl_stub.dart' as impl;

/// 웹: sessionStorage 사용 → 탭/창을 닫으면 자동 로그아웃.
/// 비웹: SharedPreferences 사용 → 기존처럼 앱 종료 후에도 세션 유지.
class SessionStorageLocalStorage extends LocalStorage {
  SessionStorageLocalStorage({required this.persistSessionKey});

  final String persistSessionKey;

  @override
  Future<void> initialize() => impl.initialize(persistSessionKey);

  @override
  Future<bool> hasAccessToken() =>
      impl.hasAccessToken(persistSessionKey);

  @override
  Future<String?> accessToken() =>
      impl.accessToken(persistSessionKey);

  @override
  Future<void> removePersistedSession() =>
      impl.removePersistedSession(persistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      impl.persistSession(persistSessionKey, persistSessionString);
}
