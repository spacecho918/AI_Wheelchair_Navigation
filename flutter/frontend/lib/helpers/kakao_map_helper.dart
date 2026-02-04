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
  static void setCenter(WebViewController? controller, double lat, double lng) {
    if (kIsWeb) {
      platform.sendMapCommand({'action': 'setCenter', 'lat': lat, 'lng': lng});
    } else {
      controller?.runJavaScript('setCenter($lat, $lng)');
    }
  }

  static void panTo(WebViewController? controller, double lat, double lng) {
    if (kIsWeb) {
      platform.sendMapCommand({'action': 'panTo', 'lat': lat, 'lng': lng});
    } else {
      controller?.runJavaScript('panTo($lat, $lng)');
    }
  }

  static void setMarker(WebViewController? controller, double lat, double lng) {
    if (kIsWeb) {
      platform.sendMapCommand({'action': 'setMarker', 'lat': lat, 'lng': lng});
    } else {
      controller?.runJavaScript('setMarker($lat, $lng)');
    }
  }

  static void setStaticMode(WebViewController? controller, bool isStatic) {
    if (kIsWeb) {
      platform.sendMapCommand({
        'action': 'setStaticMode',
        'isStatic': isStatic,
      });
    } else {
      controller?.runJavaScript('setStaticMode($isStatic)');
    }
  }

  static void drawRoute(WebViewController? controller, List<List<double>> path) {
    if (kIsWeb) {
      platform.sendMapCommand({
        'action': 'drawRoute',
        'path': path,
      });
    } else {
      final jsonPath = path.toString(); // List<List<double>> to string might need better formatting for JS
      // Better to use jsonEncode if possible, but for simple list of list of doubles, string interpolation might be tricky in JS key.
      // Actually `path.toString()` in Dart for `[[1.1, 2.2], [3.3, 4.4]]` produces `[[1.1, 2.2], [3.3, 4.4]]` which is valid JS array syntax.
      controller?.runJavaScript('drawRoute($jsonPath)');
    }
  }

  /// Listen for map events (like dragend) on Web.
  /// On Mobile, use JavaScript channel instead.
  static void listenForMapEvents(
    void Function(String type, double lat, double lng) callback,
  ) {
    if (kIsWeb) {
      platform.listenForMapEvents(callback);
    }
    // On mobile, JavaScript channel handles this
  }
}
