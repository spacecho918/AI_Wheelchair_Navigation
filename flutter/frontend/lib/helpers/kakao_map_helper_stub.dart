// Stub for non-web platforms
import 'dart:async';

typedef MapEventCallback = void Function(String type, double lat, double lng);
typedef MapEventCallbackEx = void Function(String type, Map<String, dynamic> data);

void sendMapCommand(Map<String, dynamic> command) {
  // No-op on non-web platforms
}

StreamSubscription? listenForMapEvents(MapEventCallback callback, {MapEventCallbackEx? onExtended}) {
  // No-op on non-web platforms (uses JavaScript channel instead)
  return null;
}
