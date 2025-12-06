import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:envisionfit/supabase/supabase_config.dart';

class StorageService {
  /// Uploads images using signed upload URLs from the Edge Function.
  /// 
  /// Flow:
  /// 1. Call Edge Function to get signed upload URLs
  /// 2. PUT the image bytes to those signed URLs
  /// 3. Return the read URLs for downstream consumption
  /// 
  /// Returns null if upload fails. Callers should fallback to base64 flow.
  static Future<({String modelUrl, String clothUrl})?> uploadTryOnInputsAndGetUrls(
    Uint8List modelBytes,
    Uint8List clothBytes,
  ) async {
    try {
      final client = SupabaseConfig.client;
      final uid = client.auth.currentUser?.id ?? 'anon';
      final ts = DateTime.now().millisecondsSinceEpoch;

      // Request signed upload URLs from Edge Function
      debugPrint('[Storage] Requesting signed upload URLs from Edge Function');
      final sw = Stopwatch()..start();
      final urlRes = await client.functions.invoke(
        'tryon-upload-urls',
        body: {
          'user_id': uid,
          'timestamp': ts,
        },
      );
      final urlLatencyMs = sw.elapsedMilliseconds;
      debugPrint('[Storage] Got signed URLs in ${urlLatencyMs}ms (status ${urlRes.status})');

      if (urlRes.status != 200 || urlRes.data == null) {
        debugPrint('[Storage] Failed to get signed URLs: ${urlRes.status} ${urlRes.data}');
        return null;
      }

      final Map<String, dynamic> urls = urlRes.data as Map<String, dynamic>;
      final String modelUploadUrl = urls['model_upload_url'] ?? '';
      final String clothUploadUrl = urls['cloth_upload_url'] ?? '';
      final String modelReadUrl = urls['model_read_url'] ?? '';
      final String clothReadUrl = urls['cloth_read_url'] ?? '';

      if (modelUploadUrl.isEmpty || clothUploadUrl.isEmpty || 
          modelReadUrl.isEmpty || clothReadUrl.isEmpty) {
        debugPrint('[Storage] Missing signed URLs in response');
        return null;
      }

      // PUT the image bytes directly to the signed upload URLs (faster, no extra function)
      debugPrint('[Storage] Uploading model (${modelBytes.length} bytes) to signed URL');
      final upModelSw = Stopwatch()..start();
      final modelPut = await http.put(
        Uri.parse(modelUploadUrl),
        headers: {
          'Content-Type': 'image/jpeg',
        },
        body: modelBytes,
      );
      final modelPutMs = upModelSw.elapsedMilliseconds;
      debugPrint('[Storage] Model upload completed in ${modelPutMs}ms (status ${modelPut.statusCode})');

      if (modelPut.statusCode < 200 || modelPut.statusCode >= 300) {
        debugPrint('[Storage] Model upload failed: ${modelPut.statusCode} ${modelPut.reasonPhrase}');
        return null;
      }

      debugPrint('[Storage] Uploading cloth (${clothBytes.length} bytes) to signed URL');
      final upClothSw = Stopwatch()..start();
      final clothPut = await http.put(
        Uri.parse(clothUploadUrl),
        headers: {
          'Content-Type': 'image/jpeg',
        },
        body: clothBytes,
      );
      final clothPutMs = upClothSw.elapsedMilliseconds;
      debugPrint('[Storage] Cloth upload completed in ${clothPutMs}ms (status ${clothPut.statusCode})');

      if (clothPut.statusCode < 200 || clothPut.statusCode >= 300) {
        debugPrint('[Storage] Cloth upload failed: ${clothPut.statusCode} ${clothPut.reasonPhrase}');
        return null;
      }

      debugPrint('[Storage] Both images uploaded successfully via signed URLs');
      return (modelUrl: modelReadUrl, clothUrl: clothReadUrl);
    } catch (e, stack) {
      debugPrint('[Storage] Upload error: $e');
      debugPrint('[Storage] Stack: $stack');
      return null;
    }
  }
}
