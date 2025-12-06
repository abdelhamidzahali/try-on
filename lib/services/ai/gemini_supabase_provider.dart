import 'dart:convert';
import 'dart:typed_data';
import 'package:envisionfit/services/ai/tryon_ai_provider.dart';
import 'package:envisionfit/services/ai/tryon_generation.dart';
import 'package:envisionfit/supabase/supabase_config.dart';
import 'package:envisionfit/supabase/storage_service.dart';
import 'package:flutter/foundation.dart';

/// Gemini 2.5 Flash Image try-on provider via Supabase Edge Function
class GeminiSupabaseTryOnProvider extends TryOnAiProvider {
  @override
  Future<String?> analyzeStyle(
    Uint8List userImage,
    Uint8List clothingImage,
  ) async {
    // Optional: use Gemini to analyze style before generation
    // For now, we return null and let the UI skip this step
    return null;
  }

  @override
  Future<TryOnGeneration?> generateComposite(
    Uint8List userImage,
    Uint8List clothingImage, {
    String? styleAnalysis,
    String? clothingCategory,
    String? clothingName,
    String? clothingGender,
  }) async {
    try {
      debugPrint('[Gemini] Preparing try-on request (URL-first)...');
      final totalSw = Stopwatch()..start();

      // 1) Fast path: upload to Storage and send short-lived signed URLs
      final uploadSw = Stopwatch()..start();
      final urls = await StorageService.uploadTryOnInputsAndGetUrls(
        userImage,
        clothingImage,
      );
      final uploadMs = uploadSw.elapsedMilliseconds;
      debugPrint('[Gemini] Input upload stage took ${uploadMs}ms');

      dynamic data;
      int status = -1;

      if (urls != null) {
        debugPrint('[Gemini] Invoking Edge Function with signed URLs');
        final invokeSw = Stopwatch()..start();
        final resUrl = await SupabaseConfig.client.functions.invoke(
          'tryon',
          body: {
            // Primary keys
            'model_image_url': urls.modelUrl,
            'cloth_image_url': urls.clothUrl,
            // Compatibility aliases used by some functions
            'user_image_url': urls.modelUrl,
            'garment_image_url': urls.clothUrl,
            'clothing_image_url': urls.clothUrl,
            // Pre-computed clothing metadata
            if (clothingCategory != null) 'clothing_category': clothingCategory,
            if (clothingName != null) 'clothing_name': clothingName,
            if (clothingGender != null) 'clothing_gender': clothingGender,
            // Hints
            'mode': 'virtual_tryon',
            'return_original': false,
            'prompt': styleAnalysis ?? 'Generate a realistic virtual try-on image',
          },
        );
        status = resUrl.status;
        debugPrint('[Gemini] URL invoke completed in ${invokeSw.elapsedMilliseconds}ms (status $status)');
        if (status == 200) {
          data = resUrl.data;
        } else {
          debugPrint('[Gemini] URL path failed (${resUrl.status}). Falling back to base64. Body: ${resUrl.data}');
        }
      } else {
        debugPrint('[Gemini] Skipping URL path; upload failed. Using base64 fallback.');
      }

      // 2) Fallback: send base64 payload if URL call didn't succeed
      if (data == null) {
        final b64Sw = Stopwatch()..start();
        final userBase64 = base64Encode(userImage);
        final clothingBase64 = base64Encode(clothingImage);
        debugPrint('[Gemini] Base64 sizes -> model: ${userBase64.length} chars, cloth: ${clothingBase64.length} chars');

        final resB64 = await SupabaseConfig.client.functions.invoke(
          'tryon',
          body: {
            // Primary keys
            'model_image_base64': userBase64,
            'cloth_image_base64': clothingBase64,
            // Compatibility aliases
            'user_image_base64': userBase64,
            'garment_image_base64': clothingBase64,
            'clothing_image_base64': clothingBase64,
            // Pre-computed clothing metadata
            if (clothingCategory != null) 'clothing_category': clothingCategory,
            if (clothingName != null) 'clothing_name': clothingName,
            if (clothingGender != null) 'clothing_gender': clothingGender,
            // Hints
            'mode': 'virtual_tryon',
            'return_original': false,
            'prompt': styleAnalysis ?? 'Generate a realistic virtual try-on image',
          },
        );
        status = resB64.status;
        debugPrint('[Gemini] Base64 invoke completed in ${b64Sw.elapsedMilliseconds}ms (status $status)');
        if (status == 200) {
          data = resB64.data;
        } else {
          debugPrint('[Gemini] Base64 path failed (${resB64.status}). Body: ${resB64.data}');
          return null;
        }
      }
      debugPrint('[Gemini] Edge Function response status: $status');

      final dataDynamic = data;
      if (dataDynamic == null) {
        debugPrint('[Gemini] No data returned from Edge Function');
        return null;
      }

      // Attempts to extract the exact prompt used by the Edge Function from the response
      String? _extractUsedPrompt(dynamic node) {
        String? found;
        void scan(dynamic n) {
          if (found != null) return;
          if (n is Map) {
            // Common keys the Edge Function might return for the final prompt
            const keys = [
              'used_prompt',
              'prompt_used',
              'final_prompt',
              'applied_prompt',
              'composed_prompt',
              'prompt',
              'style_prompt',
            ];
            for (final k in keys) {
              final v = n[k];
              if (v is String && v.trim().isNotEmpty) {
                found = v.trim();
                return;
              }
            }
            // Recurse nested objects
            for (final e in n.entries) {
              scan(e.value);
              if (found != null) return;
            }
          } else if (n is List) {
            for (final item in n) {
              scan(item);
              if (found != null) return;
            }
          }
        }
        scan(node);
        return found;
      }

      final extractedPrompt = _extractUsedPrompt(dataDynamic);

      // Helper to strip any data URL prefix
      String _stripDataUrlPrefix(String s) {
        final idx = s.indexOf(',');
        if (idx > 0 && s.substring(0, idx).contains('base64')) {
          return s.substring(idx + 1);
        }
        return s;
      }

      // Helper to attempt decode with logs
      Uint8List? _tryDecode(String b64, {String context = ''}) {
        try {
          final clean = _stripDataUrlPrefix(b64.trim());
          final bytes = base64Decode(clean);
          debugPrint('[Gemini] Decoded image ${bytes.length} bytes ${context.isNotEmpty ? 'from $context' : ''}');
          return bytes;
        } catch (e) {
          debugPrint('[Gemini] base64 decode failed ${context.isNotEmpty ? 'for $context ' : ''}-> $e');
          return null;
        }
      }

      // Handle the response
      if (dataDynamic is Map) {
        // Check for error first
        if (dataDynamic['error'] != null) {
          debugPrint('[Gemini] API error: ${dataDynamic['error']}');
          return null;
        }

        // Fast-path: URL provided by Edge Function (preferred)
        final urlKeys = [
          'result_image_url',
          'image_url',
          'resultUrl',
          'url',
        ];
        for (final key in urlKeys) {
          final v = dataDynamic[key];
          if (v is String && v.startsWith('http')) {
            debugPrint('[Gemini] Found "$key" URL -> $v');
            String? clothingDesc;
            if (dataDynamic['clothing_description'] != null) {
              clothingDesc = (dataDynamic['clothing_description'] as dynamic).toString();
              debugPrint('[Gemini] Clothing description: $clothingDesc');
            }
            return TryOnGeneration(url: v, usedPrompt: extractedPrompt, clothingDescription: clothingDesc);
          }
        }
        // Common shapes to support:
        // 1) { status: 'success', result_image_base64: '...' }
        // 2) { image_base64: '...' } or { image: 'data:image/jpeg;base64,...' }
        // 3) { result: { image_base64: '...' | image: '...' } }
        // 4) { data: { ...same as above } }
        // 5) Anything containing a plausible base64 image string

        final directKeys = [
          'result_image_base64',
          'image_base64',
          'image',
          'resultImageBase64',
          'resultImage',
        ];

        for (final key in directKeys) {
          final v = dataDynamic[key];
          if (v is String && v.isNotEmpty) {
            debugPrint('[Gemini] Found "$key" (${v.length} chars)');
            final bytes = _tryDecode(v, context: key);
            if (bytes != null) {
              String? clothingDesc;
              if (dataDynamic['clothing_description'] != null) {
                clothingDesc = (dataDynamic['clothing_description'] as dynamic).toString();
                debugPrint('[Gemini] Clothing description: $clothingDesc');
              }
              return TryOnGeneration(bytes: bytes, usedPrompt: extractedPrompt, clothingDescription: clothingDesc);
            }
          }
        }

        // Nested maps: result / data
        for (final nestKey in ['result', 'data', 'output']) {
          final nested = dataDynamic[nestKey];
          if (nested is Map) {
            for (final key in directKeys) {
              final v = nested[key];
              if (v is String && v.isNotEmpty) {
                debugPrint('[Gemini] Found nested "$nestKey.$key" (${v.length} chars)');
                final bytes = _tryDecode(v, context: '$nestKey.$key');
                if (bytes != null) return TryOnGeneration(bytes: bytes, usedPrompt: extractedPrompt);
              }
            }
          }
        }

        // Last resort: scan for any string value that looks like data URL or long base64
        Uint8List? best;
        void scan(dynamic node, {String path = ''}) {
          if (node is Map) {
            node.forEach((k, v) => scan(v, path: path.isEmpty ? '$k' : '$path.$k'));
          } else if (node is List) {
            for (var i = 0; i < node.length; i++) {
              scan(node[i], path: '$path[$i]');
            }
          } else if (node is String) {
            final s = node;
            // Heuristic: long enough string or data URL prefix
            if (s.startsWith('data:image') || s.length > 500) {
              final bytes = _tryDecode(s, context: path);
              if (bytes != null) {
                best ??= bytes;
              }
            }
          }
        }
        scan(dataDynamic);
        if (best != null) return TryOnGeneration(bytes: best, usedPrompt: extractedPrompt);

        debugPrint('[Gemini] No recognizable base64 image field. Keys: ${dataDynamic.keys.join(", ")}');
      }

      // If the response is raw base64 string
      if (dataDynamic is String) {
        debugPrint('[Gemini] Received raw base64 string');
        final bytes = _tryDecode(dataDynamic, context: 'raw');
        if (bytes != null) return TryOnGeneration(bytes: bytes, usedPrompt: extractedPrompt);
        return null;
      }

      debugPrint('[Gemini] Unexpected response format: ${dataDynamic.runtimeType}');
      debugPrint('[Gemini] Total pipeline time: ${totalSw.elapsedMilliseconds}ms');
      return null;
    } catch (e, stack) {
      debugPrint('[Gemini] Exception during generation: $e');
      debugPrint('[Gemini] Stack trace: $stack');
      return null;
    }
  }
}
