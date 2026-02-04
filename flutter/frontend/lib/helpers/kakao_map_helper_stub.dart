// Stub for non-web platforms

typedef MapEventCallback = void Function(String type, double lat, double lng);

void sendMapCommand(Map<String, dynamic> command) {
  // No-op on non-web platforms
}

void listenForMapEvents(MapEventCallback callback) {
  // No-op on non-web platforms (uses JavaScript channel instead)
}
