import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Conditional import for web
// ignore: uri_does_not_exist
import 'kakao_map_helper_stub.dart'
    if (dart.library.html) 'kakao_map_helper_web.dart'
    as platform;

class KakaoMapHelper {
  /// Send a command to the Kakao Map.
  /// On Web: Uses postMessage to the iframe.
  /// On Mobile: Uses runJavaScript.
  static void setCenter(
    WebViewController? controller,
    double lat,
    double lng, {
    String? mapId,
  }) {
    if (kIsWeb) {
      platform.sendMapCommand({
        'action': 'setCenter',
        'lat': lat,
        'lng': lng,
        if (mapId != null) 'mapId': mapId,
      });
    } else {
      controller?.runJavaScript('setCenter($lat, $lng)');
    }
  }

  static void panTo(
    WebViewController? controller,
    double lat,
    double lng, {
    String? mapId,
  }) {
    if (kIsWeb) {
      debugPrint('KakaoMapHelper.panTo -> mapId=$mapId');
      platform.sendMapCommand({
        'action': 'panTo',
        'lat': lat,
        'lng': lng,
        if (mapId != null) 'mapId': mapId,
      });
    } else {
      controller?.runJavaScript('panTo($lat, $lng)');
    }
  }

  static void setMarker(
    WebViewController? controller,
    double lat,
    double lng, {
    String? mapId,
  }) {
    if (kIsWeb) {
      platform.sendMapCommand({
        'action': 'setMarker',
        'lat': lat,
        'lng': lng,
        if (mapId != null) 'mapId': mapId,
      });
    } else {
      controller?.runJavaScript('setMarker($lat, $lng)');
    }
  }

  static void setCurrentLocation(
    WebViewController? controller,
    double lat,
    double lng, {
    String? mapId,
  }) {
    if (kIsWeb) {
      platform.sendMapCommand({
        'action': 'setCurrentLocation',
        'lat': lat,
        'lng': lng,
        if (mapId != null) 'mapId': mapId,
      });
    } else {
      controller?.runJavaScript('setCurrentLocation($lat, $lng)');
    }
  }

  static void setStaticMode(
    WebViewController? controller,
    bool isStatic, {
    String? mapId,
  }) {
    if (kIsWeb) {
      platform.sendMapCommand({
        'action': 'setStaticMode',
        'isStatic': isStatic,
        if (mapId != null) 'mapId': mapId,
      });
    } else {
      controller?.runJavaScript('setStaticMode($isStatic)');
    }
  }

  static void setStartEndMarkers(
    WebViewController? controller,
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng, {
    String? mapId,
  }) {
    if (kIsWeb) {
      platform.sendMapCommand({
        'action': 'setStartEndMarkers',
        'startLat': startLat,
        'startLng': startLng,
        'endLat': endLat,
        'endLng': endLng,
        if (mapId != null) 'mapId': mapId,
      });
    } else {
      final sLatStr = startLat != null ? startLat.toString() : 'null';
      final sLngStr = startLng != null ? startLng.toString() : 'null';
      final eLatStr = endLat != null ? endLat.toString() : 'null';
      final eLngStr = endLng != null ? endLng.toString() : 'null';
      controller?.runJavaScript(
        'setStartEndMarkers($sLatStr, $sLngStr, $eLatStr, $eLngStr)',
      );
    }
  }

  static void drawRoute(
    WebViewController? controller,
    List<List<double>> path, {
    String color = '#00C853',
    bool showFullRoute = true,
    String? mapId,
  }) {
    if (kIsWeb) {
      platform.sendMapCommand({
        'action': 'drawRoute',
        'path': path,
        'color': color,
        'shouldFit': showFullRoute,
        if (mapId != null) 'mapId': mapId,
      });
    } else {
      final jsonPath = path.toString();
      controller?.runJavaScript(
        "drawRoute($jsonPath, '$color', $showFullRoute)",
      );
    }
  }

  /// Draw all routes simultaneously with the selected one highlighted.
  /// [routes] is a list of maps: { 'path': List<List<double>>, 'color': String }
  /// [selectedIndex] is which route to highlight (0, 1, 2)
  static void drawAllRoutes(
    WebViewController? controller,
    List<Map<String, dynamic>> routes,
    int selectedIndex, {
    String? mapId,
  }) {
    if (kIsWeb) {
      platform.sendMapCommand({
        'action': 'drawAllRoutes',
        'routes': routes,
        'selectedIndex': selectedIndex,
        if (mapId != null) 'mapId': mapId,
      });
    } else {
      final routesJson = jsonEncode(routes);
      controller?.runJavaScript("drawAllRoutes($routesJson, $selectedIndex)");
    }
  }

  /// Sets the map bounds to neatly fit the entire geometry path.
  static void setBounds(
    WebViewController? controller,
    List<List<double>> path, {
    String? mapId,
  }) {
    if (kIsWeb) {
      platform.sendMapCommand({
        'action': 'setBounds',
        'path': path,
        if (mapId != null) 'mapId': mapId,
      });
    } else {
      final jsonPath = path.toString();
      controller?.runJavaScript("setBounds($jsonPath)");
    }
  }

  static void setLevel(
    WebViewController? controller,
    int level, {
    String? mapId,
  }) {
    if (kIsWeb) {
      platform.sendMapCommand({
        'action': 'setLevel',
        'level': level,
        if (mapId != null) 'mapId': mapId,
      });
    } else {
      controller?.runJavaScript("setLevel($level)");
    }
  }

  /// Listen for map events (like dragend, obstacleSelected, obstacleDeselected) on Web.
  /// On Mobile, use JavaScript channel instead.
  /// Returns a StreamSubscription that should be cancelled in dispose().
  static dynamic listenForMapEvents(
    void Function(String type, double lat, double lng) callback, {
    void Function(String type, Map<String, dynamic> data)? onExtended,
  }) {
    if (kIsWeb) {
      return platform.listenForMapEvents(callback, onExtended: onExtended);
    }
    // On mobile, JavaScript channel handles this
    return null;
  }

  /// Display obstacle markers on the map.
  /// [obstacles] is a list of maps: { 'lat': double, 'lng': double, 'type': String }
  static void setObstacleMarkers(
    WebViewController? controller,
    List<Map<String, dynamic>> obstacles, {
    String? mapId,
  }) {
    if (kIsWeb) {
      platform.sendMapCommand({
        'action': 'setObstacleMarkers',
        'obstacles': obstacles,
        if (mapId != null) 'mapId': mapId,
      });
    } else {
      // Mobile: JSON 인코딩하여 JS 함수 호출
      final jsonStr = obstacles
          .map((o) => '{"id":"${o['id'] ?? ''}","lat":${o['lat']},"lng":${o['lng']},"type":"${o['type']}"}')
          .join(',');
      controller?.runJavaScript('setObstacleMarkers([$jsonStr])');
    }
  }
}
