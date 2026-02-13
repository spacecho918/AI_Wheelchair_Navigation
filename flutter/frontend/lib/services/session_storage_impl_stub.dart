// 비웹(모바일/데스크톱) 전용: 기존처럼 SharedPreferences로 세션 유지
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

SharedPreferences? _prefs;

Future<void> initialize(String key) async {
  WidgetsFlutterBinding.ensureInitialized();
  _prefs = await SharedPreferences.getInstance();
}

Future<bool> hasAccessToken(String key) async =>
    _prefs?.containsKey(key) ?? false;

Future<String?> accessToken(String key) async =>
    _prefs?.getString(key);

Future<void> removePersistedSession(String key) async =>
    _prefs?.remove(key);

Future<void> persistSession(String key, String value) async =>
    _prefs?.setString(key, value);
