import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// Service to manage recent searches.
/// Logged-in: syncs with Supabase (recent_searches table). Logged-out: local only (SharedPreferences).
class RecentSearchesService {
  static const String _storageKey = 'recent_searches';
  static List<Map<String, dynamic>> _recentSearches = [];
  static bool _isLoaded = false;

  static SupabaseClient get _supabase => Supabase.instance.client;

  /// Get the current list of recent searches
  static List<Map<String, dynamic>> get recentSearches =>
      List.unmodifiable(_recentSearches);

  /// Load recent searches: from Supabase if logged in, else from local storage.
  static Future<void> load() async {
    try {
      final user = AuthService.currentUser;
      if (user != null) {
        final data = await _supabase
            .from('recent_searches')
            .select('place_id, place_name, address, lat, lon, icon_type')
            .eq('user_id', user.id)
            .order('searched_at', ascending: false)
            .limit(20);
        _recentSearches = (data as List)
            .map((row) => {
                  'name': row['place_name'] as String? ?? '',
                  'address': row['address'] as String? ?? '',
                  'lat': (row['lat'] as num?)?.toDouble(),
                  'lng': (row['lon'] as num?)?.toDouble(),
                  'place_id': row['place_id'] as String? ?? '',
                  'category': row['icon_type'] as String?,
                  'type': 'recent',
                })
            .toList();
      } else {
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
      }
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
      _recentSearches = [];
    }
    _isLoaded = true;
  }

  /// Add a search to recent searches (at the top, max 20 items).
  /// Syncs to Supabase when logged in.
  static Future<void> addSearch(Map<String, dynamic> search) async {
    final name = search['name'] as String? ?? '';
    final address = search['address'] as String? ?? '';
    final lat = (search['lat'] as num?)?.toDouble();
    final lng = (search['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    final placeId = search['place_id']?.toString().isNotEmpty == true
        ? search['place_id'].toString()
        : 'local_${lat}_$lng';
    final iconType = search['category'] as String?;

    _recentSearches.removeWhere(
      (item) =>
          item['name'] == name &&
          (item['address'] == address ||
              (item['lat'] == lat && item['lng'] == lng)),
    );
    _recentSearches.insert(0, {...search, 'type': 'recent'});
    if (_recentSearches.length > 20) {
      _recentSearches = _recentSearches.sublist(0, 20);
    }

    final user = AuthService.currentUser;
    if (user != null) {
      try {
        await _supabase.from('recent_searches').delete().eq('user_id', user.id).eq('place_id', placeId);
        await _supabase.from('recent_searches').insert({
          'user_id': user.id,
          'place_id': placeId,
          'place_name': name,
          'address': address,
          'lat': lat,
          'lon': lng,
          'icon_type': iconType,
        });
      } catch (e) {
        debugPrint('Error saving recent search to Supabase: $e');
      }
    }
    await _saveToLocal();
  }

  /// Remove a search from recent searches. Syncs to Supabase when logged in.
  static Future<void> removeSearch(Map<String, dynamic> search) async {
    final name = search['name'] as String? ?? '';
    final address = search['address'] as String? ?? '';
    final placeId = search['place_id'] as String?;

    _recentSearches.removeWhere(
      (item) =>
          item['name'] == name &&
          item['address'] == address,
    );

    final user = AuthService.currentUser;
    if (user != null) {
      try {
        if (placeId != null && placeId.isNotEmpty) {
          await _supabase
              .from('recent_searches')
              .delete()
              .eq('user_id', user.id)
              .eq('place_id', placeId);
        } else {
          await _supabase
              .from('recent_searches')
              .delete()
              .eq('user_id', user.id)
              .eq('place_name', name)
              .eq('address', address);
        }
      } catch (e) {
        debugPrint('Error removing recent search from Supabase: $e');
      }
    }
    await _saveToLocal();
  }

  /// Clear all recent searches. Syncs to Supabase when logged in.
  static Future<void> clearAll() async {
    _recentSearches.clear();
    final user = AuthService.currentUser;
    if (user != null) {
      try {
        await _supabase
            .from('recent_searches')
            .delete()
            .eq('user_id', user.id);
      } catch (e) {
        debugPrint('Error clearing recent searches from Supabase: $e');
      }
    }
    await _saveToLocal();
  }

  /// Save current list to local storage (cache / offline).
  static Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(_recentSearches);
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      debugPrint('Error saving recent searches to local: $e');
    }
  }

  /// Check if loaded
  static bool get isLoaded => _isLoaded;

  /// Force reload from server (if logged in) or local.
  static Future<void> reload() async {
    _isLoaded = false;
    await load();
  }
}
