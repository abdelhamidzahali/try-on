import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RetailSearchService {
  /// Builds a SHEIN US search URL using the given query.
  static Uri buildSheinSearchUrl(String query) {
    final sanitized = _sanitizeQuery(query);
    // Always use us.shein.com
    final path = '/pdsearch/$sanitized';
    return Uri.https('us.shein.com', path);
  }

  static Future<bool> openSheinSearch(String query) async {
    try {
      final url = buildSheinSearchUrl(query);
      debugPrint('[RetailSearch] Opening SHEIN: $url');
      final mode = kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;
      final ok = await launchUrl(url, mode: mode);
      if (!ok) {
        debugPrint('[RetailSearch] launchUrl returned false');
      }
      return ok;
    } catch (e) {
      debugPrint('[RetailSearch] Failed to open SHEIN search: $e');
      return false;
    }
  }

  static String _sanitizeQuery(String raw) {
    // Keep letters, digits and basic separators, remove extra punctuation
    final cleaned = raw
        .replaceAll(RegExp(r'[_#*~`"\[\]{}()<>|^]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return Uri.encodeComponent(cleaned);
  }
}
