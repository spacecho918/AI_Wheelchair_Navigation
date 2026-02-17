import 'dart:convert';
import 'dart:html' as html;

typedef MapEventCallback = void Function(String type, double lat, double lng);

/// Listens for postMessage events from the Kakao Map iframe.
void listenForMapEvents(MapEventCallback callback) {
  html.window.onMessage.listen((event) {
    try {
      if (event.data is String) {
        final data = jsonDecode(event.data);
        if (data['type'] == 'dragend') {
          callback(
            data['type'],
            (data['lat'] as num).toDouble(),
            (data['lng'] as num).toDouble(),
          );
        }
      }
    } catch (e) {
      // Ignore non-JSON messages
    }
  });
}

/// Sends a command to the Kakao Map iframe via postMessage.
void sendMapCommand(Map<String, dynamic> command) {
  try {
    // Find the iframe containing the kakao map
    final iframes = html.document.querySelectorAll('iframe');
    print('Found ${iframes.length} iframes');

    bool sent = false;
    final targetMapId = command['mapId'] as String?;

    for (var iframe in iframes) {
      if (iframe is html.IFrameElement) {
        final src = iframe.src ?? '';

        // If mapId is specified, only send to matching iframe
        if (targetMapId != null) {
          if (src.contains('mapId=$targetMapId')) {
            print(
              'Sending to kakao_map iframe (id=$targetMapId): ${jsonEncode(command)}',
            );
            iframe.contentWindow?.postMessage(jsonEncode(command), '*');
            sent = true;
            return;
          }
        }
        // Default behavior: find first kakao_map iframe (if no mapId specified)
        else if (src.contains('kakao_map.html')) {
          print('Sending to kakao_map iframe: ${jsonEncode(command)}');
          iframe.contentWindow?.postMessage(jsonEncode(command), '*');
          sent = true;
          return;
        }
      }
    }

    // Fallback: Try all iframes (webview might not have explicit src)
    if (!sent && iframes.isNotEmpty) {
      print('Fallback: sending to all iframes');
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
