// 웹 전용: sessionStorage 사용
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void setItem(String key, String value) =>
    html.window.sessionStorage[key] = value;

String? getItem(String key) => html.window.sessionStorage[key];

void removeItem(String key) => html.window.sessionStorage.remove(key);
