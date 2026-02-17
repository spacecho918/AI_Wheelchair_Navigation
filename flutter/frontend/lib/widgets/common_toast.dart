import 'package:flutter/material.dart';

class CommonToast {
  static void show(BuildContext context, String message) {
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100.0,
        left: 0.0,
        right: 0.0,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }
}
