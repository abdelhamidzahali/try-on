import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:envisionfit/services/save_result.dart';

class TryOnFavoritesService {
  static const String _favoritesKey = 'favorite_tryon_ids';

  static Future<Set<String>> _getIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_favoritesKey);
      if (raw == null || raw.isEmpty) return <String>{};
      final decoded = json.decode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toSet();
      }
      return <String>{};
    } catch (e, st) {
      debugPrint('Failed to load favorites: $e');
      debugPrint('$st');
      return <String>{};
    }
  }

  static Future<bool> _saveIds(Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = ids.toList();
      return prefs.setString(_favoritesKey, json.encode(list));
    } catch (e, st) {
      debugPrint('Failed to save favorites: $e');
      debugPrint('$st');
      return false;
    }
  }

  static Future<bool> isFavorite(String sessionId) async {
    final ids = await _getIds();
    return ids.contains(sessionId);
    
  }

  static Future<SaveResult> addFavoriteSession(String sessionId) async {
    try {
      final ids = await _getIds();
      if (ids.contains(sessionId)) {
        return SaveResult.ok('Already in your favorites');
      }
      ids.add(sessionId);
      final ok = await _saveIds(ids);
      return ok
          ? const SaveResult(success: true, message: 'Added to your favorite try-ons')
          : SaveResult.fail('Could not add to favorites');
    } catch (e, st) {
      debugPrint('addFavoriteSession error: $e');
      debugPrint('$st');
      return SaveResult.fail('Failed to add to favorites');
    }
  }

  static Future<SaveResult> removeFavoriteSession(String sessionId) async {
    try {
      final ids = await _getIds();
      if (!ids.remove(sessionId)) {
        return SaveResult.ok('Removed');
      }
      final ok = await _saveIds(ids);
      return ok ? SaveResult.ok('Removed from favorites') : SaveResult.fail('Could not update favorites');
    } catch (e, st) {
      debugPrint('removeFavoriteSession error: $e');
      debugPrint('$st');
      return SaveResult.fail('Failed to update favorites');
    }
  }

  static Future<List<String>> getFavoriteSessionIds() async {
    final ids = await _getIds();
    return ids.toList();
  }
}
