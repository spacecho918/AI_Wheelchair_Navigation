// 웹 전용: 탭/창을 닫으면 세션이 사라지도록 sessionStorage 사용
import 'dart:html' as html;

final _storage = html.window.sessionStorage;

Future<void> initialize(String key) async {}

Future<bool> hasAccessToken(String key) async =>
    _storage.containsKey(key);

Future<String?> accessToken(String key) async =>
    _storage[key];

Future<void> removePersistedSession(String key) async =>
    _storage.remove(key);

Future<void> persistSession(String key, String value) async {
  _storage[key] = value;
}
