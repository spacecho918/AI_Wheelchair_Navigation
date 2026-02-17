import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String _key = 'theme_mode';

  static Future<ThemeMode> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key);

    if (index != null) {
      return ThemeMode.values[index];
    }

    return ThemeMode.light;
  }

  static Future<void> saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, mode.index);
  }
}
