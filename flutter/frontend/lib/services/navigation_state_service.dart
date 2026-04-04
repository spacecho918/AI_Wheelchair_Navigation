import 'dart:convert';
import 'package:flutter/foundation.dart';

// ignore: avoid_web_libraries_in_flutter
import 'navigation_state_service_web.dart'
    if (dart.library.io) 'navigation_state_service_stub.dart' as impl;

/// 경로 안내 상태를 저장/복원하는 서비스.
/// 웹에서는 sessionStorage를 사용하여 새로고침 후에도 안내 화면이 유지됩니다.
class NavigationStateService {
  static const _key = 'gilbeot_nav_state';

  /// 경로 안내 상태를 저장 (안내 시작 시 호출)
  static Future<void> save({
    required String routeType,
    required String estimatedTime,
    required String totalDistance,
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    required List<List<double>> routeGeometry,
    required List<Map<String, String>> instructions,
    required int avoidedObstacles,
    required String startLocationName,
    required String endLocationName,
  }) async {
    if (!kIsWeb) return; // 웹 전용
    final data = jsonEncode({
      'routeType': routeType,
      'estimatedTime': estimatedTime,
      'totalDistance': totalDistance,
      'startLat': startLat,
      'startLon': startLon,
      'endLat': endLat,
      'endLon': endLon,
      'routeGeometry': routeGeometry,
      'instructions': instructions,
      'avoidedObstacles': avoidedObstacles,
      'startLocationName': startLocationName,
      'endLocationName': endLocationName,
    });
    impl.setItem(_key, data);
  }

  /// 저장된 경로 안내 상태를 읽어 반환 (없으면 null)
  static Map<String, dynamic>? load() {
    if (!kIsWeb) return null;
    final raw = impl.getItem(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('NavigationStateService.load error: $e');
      return null;
    }
  }

  /// 저장된 상태 삭제 (안내 종료 시 호출)
  static void clear() {
    if (!kIsWeb) return;
    impl.removeItem(_key);
  }
}
