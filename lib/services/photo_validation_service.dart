import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:envisionfit/supabase/supabase_config.dart';

enum PhotoType { selfie, fullbody }

class PhotoValidationResult {
  final String gender; // "Man" | "Woman"
  final String status; // "OK" | "NOT OK"
  final String? reason; // nullable when OK

  const PhotoValidationResult({
    required this.gender,
    required this.status,
    required this.reason,
  });

  bool get isOk => status.toUpperCase() == 'OK';

  factory PhotoValidationResult.fromMap(Map<String, dynamic> map) {
    return PhotoValidationResult(
      gender: (map['gender'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      reason: map['reason'] == null ? null : map['reason'].toString(),
    );
  }
}

class PhotoValidationService {
  /// Calls the 'profile_photo_validation' edge function with the given image bytes.
  /// Returns [PhotoValidationResult] when parsing the expected JSON succeeds; null otherwise.
  static Future<PhotoValidationResult?> validateBytes({
    required Uint8List bytes,
    required PhotoType type,
  }) async {
    try {
      final b64 = base64Encode(bytes);
      final photoType = type.name; // 'selfie' | 'fullbody'
      debugPrint('[Validation] Invoking profile_photo_validation for $photoType (bytes=${bytes.length})');

      final res = await SupabaseConfig.client.functions.invoke(
        'profile_photo_validation',
        body: {
          'imageBase64': b64,
          'photoType': photoType,
        },
      );

      final status = res.status;
      final data = res.data;
      debugPrint('[Validation] Edge status=$status; type=${data.runtimeType}');

      if (status != 200 || data == null) {
        debugPrint('[Validation] Non-200 or null data: ${res.data}');
        return null;
      }

      // The function may return:
      // - a Map<String, dynamic> with keys gender/status/reason
      // - a JSON string containing those keys
      // - a wrapper like { result: {...} }
      Map<String, dynamic>? tryExtract(dynamic node) {
        if (node is Map<String, dynamic>) {
          if (node.containsKey('gender') && node.containsKey('status') && node.containsKey('reason')) {
            return node;
          }
          for (final k in ['result', 'data', 'output']) {
            final v = node[k];
            if (v is Map) {
              final nested = tryExtract(Map<String, dynamic>.from(v as Map));
              if (nested != null) return nested;
            }
            if (v is String) {
              try {
                final parsed = jsonDecode(v);
                if (parsed is Map<String, dynamic>) {
                  final nested = tryExtract(parsed);
                  if (nested != null) return nested;
                }
              } catch (_) {}
            }
          }
        } else if (node is String) {
          try {
            final parsed = jsonDecode(node);
            if (parsed is Map<String, dynamic>) {
              return tryExtract(parsed);
            }
          } catch (e) {
            debugPrint('[Validation] JSON decode failed: $e');
          }
        }
        return null;
      }

      final extracted = tryExtract(data) ?? (data is Map<String, dynamic> ? data : null);
      if (extracted == null) {
        debugPrint('[Validation] Could not extract validation map from response');
        return null;
      }

      try {
        final result = PhotoValidationResult.fromMap(extracted);
        debugPrint('[Validation] Parsed -> gender=${result.gender}, status=${result.status}, reason=${result.reason}');
        return result;
      } catch (e) {
        debugPrint('[Validation] Parsing to PhotoValidationResult failed: $e');
        return null;
      }
    } catch (e, st) {
      debugPrint('[Validation] Exception invoking edge: $e\n$st');
      return null;
    }
  }
}
