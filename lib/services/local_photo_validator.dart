import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:envisionfit/services/photo_validation_service.dart';

class LocalValidationResult {
  final bool ok;
  final String? reason;
  const LocalValidationResult({required this.ok, this.reason});
}

/// Lightweight, on-device photo checks used when remote validation is
/// unavailable (e.g., guest users or network issues).
class LocalPhotoValidator {
  static Future<LocalValidationResult> basicChecks(Uint8List bytes, PhotoType type) async {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return const LocalValidationResult(ok: false, reason: "Unsupported image format.");
      }
      final w = decoded.width;
      final h = decoded.height;

      // Resolution checks
      if (type == PhotoType.selfie) {
        if (w < 400 || h < 400) {
          return const LocalValidationResult(
            ok: false,
            reason: 'Photo resolution is too low. Please upload a clearer selfie (>= 400x400).',
          );
        }
      } else {
        // fullbody
        if (h < 700 || w < 400) {
          return const LocalValidationResult(
            ok: false,
            reason: 'Photo resolution is too low for full-body (>= 700px tall).',
          );
        }
        if (h < w) {
          return const LocalValidationResult(
            ok: false,
            reason: 'Please upload a portrait-oriented full-body photo (taller than it is wide).',
          );
        }
      }

      // Brightness check (sampled)
      final sampleStep = (w * h) > (2000 * 2000) ? 40 : 20; // lighter sampling on huge images
      double sum = 0;
      int count = 0;
      for (int y = 0; y < h; y += sampleStep) {
        for (int x = 0; x < w; x += sampleStep) {
          final p = decoded.getPixel(x, y);
          final r = p.r.toDouble();
          final g = p.g.toDouble();
          final b = p.b.toDouble();
          // ITU-R BT.709 luminance
          final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b; // 0..255
          sum += lum;
          count++;
        }
      }
      if (count > 0) {
        final avg = sum / count; // 0..255
        final threshold = type == PhotoType.selfie ? 45.0 : 38.0; // conservative
        if (avg < threshold) {
          return const LocalValidationResult(
            ok: false,
            reason: 'The photo seems too dark. Please retake in better lighting.',
          );
        }
      }

      return const LocalValidationResult(ok: true);
    } catch (e) {
      debugPrint('LocalPhotoValidator error: $e');
      return const LocalValidationResult(ok: false, reason: 'Could not analyze the image locally.');
    }
  }
}
