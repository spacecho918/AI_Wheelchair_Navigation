import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

typedef MapEventCallback = void Function(String type, double lat, double lng);
typedef MapEventCallbackEx = void Function(String type, Map<String, dynamic> data);

/// Listens for postMessage events from the Kakao Map iframe.
StreamSubscription? listenForMapEvents(MapEventCallback callback, {MapEventCallbackEx? onExtended}) {
  return html.window.onMessage.listen((event) {
    try {
      if (event.data is String) {
        final data = jsonDecode(event.data);
        if (data['type'] == 'dragend') {
          callback(
            data['type'],
            (data['lat'] as num).toDouble(),
            (data['lng'] as num).toDouble(),
          );
        } else if (data['type'] == 'obstacleSelected' || data['type'] == 'obstacleDeselected') {
          if (onExtended != null) {
            onExtended(data['type'], Map<String, dynamic>.from(data));
          }
        }
      }
    } catch (e) {
      // Ignore non-JSON messages
    }
  });
}

/// Sends a command to the Kakao Map iframe via postMessage.
void sendMapCommand(Map<String, dynamic> command) {
  _sendMapCommandInternal(command, retryCount: 0);
}

void _sendMapCommandInternal(Map<String, dynamic> command, {int retryCount = 0}) {
  try {
    // Find the iframe containing the kakao map
    final iframes = html.document.querySelectorAll('iframe');
    final targetMapId = command['mapId'] as String?;

    for (var iframe in iframes) {
      if (iframe is html.IFrameElement) {
        final src = iframe.src ?? '';

        // If mapId is specified, only send to matching iframe
        if (targetMapId != null) {
          if (src.contains('mapId=$targetMapId')) {
            iframe.contentWindow?.postMessage(jsonEncode(command), '*');
            return;
          }
        }
        // Default behavior: find first kakao_map iframe (if no mapId specified)
        else if (src.contains('kakao_map.html')) {
          iframe.contentWindow?.postMessage(jsonEncode(command), '*');
          return;
        }
      }
    }

    // mapId가 지정되었지만 매칭되는 iframe을 찾지 못한 경우 → 재시도 (iframe 로드 대기)
    if (targetMapId != null && retryCount < 5) {
      Future.delayed(Duration(milliseconds: 200 * (retryCount + 1)), () {
        _sendMapCommandInternal(command, retryCount: retryCount + 1);
      });
    } else if (iframes.isNotEmpty && targetMapId == null) {
      // mapId 없이 호출했는데 kakao_map iframe을 못 찾은 경우 → fallback
      for (var iframe in iframes) {
        if (iframe is html.IFrameElement) {
          iframe.contentWindow?.postMessage(jsonEncode(command), '*');
        }
      }
    }
  } catch (e) {
    print('sendMapCommand error: $e');
  }
}
