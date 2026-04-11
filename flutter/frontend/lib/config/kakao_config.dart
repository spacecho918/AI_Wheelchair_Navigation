import 'package:flutter_dotenv/flutter_dotenv.dart';

class KakaoConfig {
  /// 네이티브 앱 키 (Android/iOS 지도 표시용)
  /// AndroidManifest.xml과 Info.plist에도 동일한 키 입력 필요
  static String get nativeAppKey => dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? '';

  /// REST API 키 (장소 검색 API용)
  static String get restApiKey => dotenv.env['KAKAO_REST_API_KEY'] ?? '';

  /// JavaScript 키 (웹 지도 표시용)
  static String get jsAppKey => dotenv.env['KAKAO_JAVASCRIPT_KEY'] ?? '';
}
