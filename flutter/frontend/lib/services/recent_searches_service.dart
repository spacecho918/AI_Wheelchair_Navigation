import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage recent searches, stored locally using SharedPreferences.
class RecentSearchesService {
  static const String _storageKey = 'recent_searches';
  static List<Map<String, dynamic>> _recentSearches = [];
  static bool _isLoaded = false;

  /// Get the current list of recent searches
  static List<Map<String, dynamic>> get recentSearches =>
      List.unmodifiable(_recentSearches);

  /// Load recent searches from local storage
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString != null) {
        final List<dynamic> decoded = json.decode(jsonString);
        _recentSearches = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        _recentSearches = [];
      }
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
      _recentSearches = [];
    }
    _isLoaded = true;
  }

  /// Add a search to recent searches (at the top, max 20 items)
  static Future<void> addSearch(Map<String, dynamic> search) async {
    // Remove if already exists (to move to top)
    _recentSearches.removeWhere(
      (item) =>
          item['name'] == search['name'] &&
          item['address'] == search['address'],
    );

    // Add to top
    _recentSearches.insert(0, {...search, 'type': 'recent'});

    // Keep max 20 items
    if (_recentSearches.length > 20) {
      _recentSearches = _recentSearches.sublist(0, 20);
    }

    await _saveToLocal();
  }

  /// Remove a search from recent searches
  static Future<void> removeSearch(Map<String, dynamic> search) async {
    _recentSearches.removeWhere(
      (item) =>
          item['name'] == search['name'] &&
          item['address'] == search['address'],
    );
    await _saveToLocal();
  }

  /// Clear all recent searches
  static Future<void> clearAll() async {
    _recentSearches.clear();
    await _saveToLocal();
  }

  /// Save to local storage
  static Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(_recentSearches);
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      debugPrint('Error saving recent searches: $e');
    }
  }

  /// Check if loaded
  static bool get isLoaded => _isLoaded;

  /// Force reload
  static Future<void> reload() async {
    _isLoaded = false;
    await load();
  }
}
