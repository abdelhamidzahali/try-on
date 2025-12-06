import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:envisionfit/models/model_image.dart';
import 'package:envisionfit/services/image_service.dart';

class ModelGalleryService {
  static const String _storageKey = 'model_images_v1';
  static const int _maxItems = 12;

  static Future<List<ModelImage>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return [];
      final list = (json.decode(raw) as List<dynamic>)
          .map((e) {
            try {
              return ModelImage.fromJson(e as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<ModelImage>()
          .toList();

      // Auto-trim if over capacity
      if (list.length > _maxItems) {
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final trimmed = list.take(_maxItems).toList();
        await _saveAll(trimmed);
        return trimmed;
      }
      return list;
    } catch (e) {
      debugPrint('ModelGalleryService.getAll error: $e');
      return [];
    }
  }

  static Future<ModelImage?> getDefault() async {
    final list = await getAll();
    try {
      return list.firstWhere((m) => m.isDefault);
    } catch (_) {
      return null;
    }
  }

  static Future<ModelImage?> addFromFile(File imageFile) async {
    try {
      // Persist a copy on mobile/desktop; keep as data URL on web
      final saved = await ImageService.saveImageToAppDirectory(
        imageFile,
        ImageService.generateFileName('model'),
      );
      final ref = saved ?? imageFile; // fallback to original reference
      final list = await getAll();
      final item = ModelImage(
        id: ModelImage.generateId(),
        path: ref.path,
        createdAt: DateTime.now(),
        // If this is the first image being added, mark it as default
        isDefault: list.isEmpty,
      );
      list.add(item);
      // Ensure newest first order on save
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await _saveAll(list.take(_maxItems).toList());
      return item;
    } catch (e) {
      debugPrint('ModelGalleryService.addFromFile error: $e');
      return null;
    }
  }

  static Future<bool> setDefault(String id) async {
    try {
      final list = await getAll();
      final updated = list
          .map((m) => m.copyWith(isDefault: m.id == id))
          .toList();
      await _saveAll(updated);
      return true;
    } catch (e) {
      debugPrint('ModelGalleryService.setDefault error: $e');
      return false;
    }
  }

  static Future<bool> delete(String id) async {
    try {
      final list = await getAll();
      final target = list.where((m) => m.id == id).firstOrNull;
      final updated = list.where((m) => m.id != id).toList();

      // If deleting default, unset default; if others remain, set first as default? No
      // We'll simply remove default flag; user can choose again.
      await _saveAll(updated.map((m) => m.copyWith(isDefault: m.isDefault && m.id != id)).toList());

      // Try to remove the local file on mobile/desktop
      if (target != null && !kIsWeb) {
        try {
          final f = File(target.path);
          if (await f.exists()) {
            await f.delete();
          }
        } catch (_) {}
      }
      return true;
    } catch (e) {
      debugPrint('ModelGalleryService.delete error: $e');
      return false;
    }
  }

  static Future<bool> _saveAll(List<ModelImage> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = items.map((e) => e.toJson()).toList();
      return await prefs.setString(_storageKey, json.encode(jsonList));
    } catch (e) {
      debugPrint('ModelGalleryService._saveAll error: $e');
      return false;
    }
  }
}
