import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:envisionfit/services/ai/tryon_ai_provider.dart';
import 'package:envisionfit/services/ai/tryon_generation.dart';

const apiKey = String.fromEnvironment('OPENAI_PROXY_API_KEY');
const endpoint = String.fromEnvironment('OPENAI_PROXY_ENDPOINT');
// Global HTTP timeout for OpenAI requests (in milliseconds).
// You can override this at runtime via --dart-define=OPENAI_HTTP_TIMEOUT_MS=240000
// Defaults to 4 minutes to accommodate image generation latency.
const int _openAiTimeoutMs = int.fromEnvironment('OPENAI_HTTP_TIMEOUT_MS', defaultValue: 240000);
const Duration _openAiTimeout = Duration(milliseconds: _openAiTimeoutMs);

// Image generation configuration
// e.g. --dart-define=OPENAI_IMAGE_SIZE=2048x2048
const String _imageSize = String.fromEnvironment('OPENAI_IMAGE_SIZE', defaultValue: '1024x1024');
// quality can be 'standard' or 'high' (some proxies may use 'hd'). We'll try
// to send it, and fall back gracefully if the API rejects the field.
const String _imageQuality = String.fromEnvironment('OPENAI_IMAGE_QUALITY', defaultValue: 'high');

/// Simple exponential backoff helper for transient errors.
Future<T> _withRetries<T>(
  Future<T> Function() run, {
  int maxAttempts = 2,
  Duration initialDelay = const Duration(milliseconds: 800),
  bool Function(Object error)? shouldRetry,
}) async {
  int attempt = 0;
  Object? lastError;
  while (attempt < maxAttempts) {
    attempt += 1;
    try {
      return await run();
    } catch (e) {
      lastError = e;
      if (attempt >= maxAttempts || (shouldRetry != null && !shouldRetry(e))) {
        rethrow;
      }
      final delay = initialDelay * attempt;
      await Future.delayed(delay);
    }
  }
  throw lastError ?? Exception('Unknown error in _withRetries');
}

class OpenAIService {
  /// Builds the final image-edit prompt used for the Images API based on
  /// the provided style analysis. If [analysis] is null/empty, a generic
  /// high-quality try-on prompt is returned.
  static String composeImageEditPrompt(String? analysis) {
    final baseConstraints =
        'Edit the base photo to create a hyper-realistic virtual try-on. '
        'Strictly preserve the person\'s identity, face, hair, body anatomy, skin tone, pose, hands, and the entire background. '
        'Do not crop, blur, or change framing. Maintain consistent scene lighting and perspective. '
        'Replace only the outfit with precise garment fit, natural fabric drape, correct garment scale and alignment to the body, '
        'and seamless edges with no halos or artifacts.';

    final garmentDetailGuide =
        'When rendering the garment, honor neckline, sleeve length, hemline, silhouette, fabric type, pattern, color, and closures. '
        'Ensure realistic shadows where the garment contacts the body and layered clothing behaves naturally.';

    final negativeDirectives =
        'Avoid deformed limbs, duplicate fingers, melting textures, incorrect proportions, color bleeding, or background alterations.';

    final garmentSpec = (analysis != null && analysis.trim().isNotEmpty)
        ? 'Garment description to apply: ${analysis.trim()}'
        : 'Apply a well-fitted, photo-realistic garment appropriate to the person\'s pose and body.';

    return '$baseConstraints\n$garmentDetailGuide\n$negativeDirectives\n$garmentSpec';
  }

  static Future<String?> generateVirtualTryOn(
    Uint8List userImage,
    Uint8List clothingImage,
  ) async {
    try {
      if (apiKey.isEmpty || endpoint.isEmpty) {
        print('OpenAI configuration missing: endpoint or apiKey is empty');
        return null;
      }
      const String model = 'gpt-4o';
      
      final String userImageBase64 = base64Encode(userImage);
      final String clothingImageBase64 = base64Encode(clothingImage);

      final Map<String, dynamic> requestBody = {
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content': 'You are an AI fashion stylist that creates realistic virtual try-on experiences. Analyze the user photo and clothing item, then describe how the person would look wearing the outfit. Focus on fit, style, and overall appearance. Be detailed and realistic in your description.',
          },
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': 'Please create a detailed description of how this person would look wearing this clothing item. Consider body type, fit, style, colors, and overall aesthetic. Provide a realistic and helpful fashion assessment.',
              },
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$userImageBase64'},
              },
              {
                'type': 'image_url', 
                'image_url': {'url': 'data:image/jpeg;base64,$clothingImageBase64'},
              },
            ],
          },
        ],
        'max_tokens': 450,
        'temperature': 0.4,
      };

      final response = await _withRetries<Response>(() async {
        // Dreamflow OpenAI proxy requires hitting the base endpoint without extra paths
        return await http
            .post(
              Uri.parse(endpoint),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKey',
              },
              body: utf8.encode(json.encode(requestBody)),
            )
            .timeout(_openAiTimeout);
      }, shouldRetry: (e) {
        return e is TimeoutException;
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'];
      } else {
        print('OpenAI API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } on TimeoutException catch (_) {
      print('OpenAI request timed out after ${_openAiTimeout.inSeconds}s (virtual try-on analysis).');
      return null;
    } catch (e) {
      print('Error generating virtual try-on: $e');
      return null;
    }
  }

  static Future<String?> generateStyleRecommendations(
    Uint8List userImage,
  ) async {
    try {
      if (apiKey.isEmpty || endpoint.isEmpty) {
        print('OpenAI configuration missing: endpoint or apiKey is empty');
        return null;
      }
      const String model = 'gpt-4o-mini';
      
      final String userImageBase64 = base64Encode(userImage);

      final Map<String, dynamic> requestBody = {
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content': 'You are a professional fashion stylist. Analyze the person in the image and provide style recommendations based on their body type, complexion, and personal style. Give practical outfit suggestions.',
          },
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': 'Please analyze this person and provide personalized style recommendations. Include clothing types, colors, and styling tips that would look great on them.',
              },
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$userImageBase64'},
              },
            ],
          },
        ],
        'max_tokens': 350,
        'temperature': 0.5,
      };

      final response = await _withRetries<Response>(() async {
        return await http
            .post(
              Uri.parse('$endpoint/chat/completions'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKey',
              },
              body: utf8.encode(json.encode(requestBody)),
            )
            .timeout(_openAiTimeout);
      }, shouldRetry: (e) {
        return e is TimeoutException;
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'];
      } else {
        print('OpenAI API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } on TimeoutException catch (_) {
      print('OpenAI request timed out after ${_openAiTimeout.inSeconds}s (style recommendations).');
      return null;
    } catch (e) {
      print('Error generating style recommendations: $e');
      return null;
    }
  }

  /// Generates a composite try-on image by first analyzing style and then
  /// calling the Images Edits API to render a realistic try-on.
  /// Returns raw PNG bytes on success, or null on failure.
  static Future<Uint8List?> generateTryOnComposite(
    Uint8List userImage,
    Uint8List clothingImage, {
    String? styleAnalysis,
  }) async {
    try {
      if (apiKey.isEmpty || endpoint.isEmpty) {
        print('OpenAI configuration missing: endpoint or apiKey is empty');
        return null;
      }
      // Step 1: Get a style/fit description from the two images
      final analysis = styleAnalysis ?? await generateVirtualTryOn(userImage, clothingImage);

      final prompt = composeImageEditPrompt(analysis);

      // Step 2: Call Images Edits to render composite (no explicit mask; allow model to edit clothing area)
      Future<Response> _sendEdit({required String size, bool includeQuality = true}) async {
        // Dreamflow OpenAI proxy requires hitting the base endpoint without extra paths
        final request = http.MultipartRequest('POST', Uri.parse(endpoint));
        request.fields.addAll({
          'model': 'gpt-image-1',
          'prompt': prompt,
          'size': size,
          'response_format': 'b64_json',
          'n': '1',
        });
        if (includeQuality) {
          request.fields['quality'] = _imageQuality; // will be ignored if unsupported
        }
        request.headers['Authorization'] = 'Bearer $apiKey';

        // Temporary diagnostics to ensure model/parameters are attached as expected.
        print('Images Edit request url: ${request.url}');
        print('Images Edit request fields (quality=$includeQuality, size=$size): ${request.fields}');

        // Attach base user image (Images Edits API expects `image` field)
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          userImage,
          filename: 'user.png',
        ));

        final streamed = await request.send().timeout(_openAiTimeout);
        return await http.Response.fromStream(streamed).timeout(_openAiTimeout);
      }

      // First attempt: configured size and quality
      Response response;
      try {
        response = await _withRetries<Response>(() async {
          return await _sendEdit(size: _imageSize, includeQuality: true);
        }, shouldRetry: (e) => e is TimeoutException);
      } catch (_) {
        // Retry without quality if the proxy/server rejects the field
        response = await _withRetries<Response>(() async {
          return await _sendEdit(size: _imageSize, includeQuality: false);
        }, shouldRetry: (e) => e is TimeoutException);
      }

      // Fallback to 1024 if higher resolution failed
      if (response.statusCode != 200 && _imageSize != '1024x1024') {
        response = await _withRetries<Response>(() async {
          return await _sendEdit(size: '1024x1024', includeQuality: false);
        }, shouldRetry: (e) => e is TimeoutException);
      }

      if (response.statusCode == 200) {
        final bodyText = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> data = json.decode(bodyText);
        final dynamic error = data['error'];
        if (error != null) {
          print('OpenAI Images API logical error payload: $error');
          return null;
        }
        final items = data['data'] as List<dynamic>?;
        if (items != null && items.isNotEmpty) {
          final first = items.first as Map<String, dynamic>;
          // Prefer b64_json, but some proxies may return url instead
          final b64 = first['b64_json'] as String?;
          if (b64 != null) {
            return base64Decode(b64);
          }
          final url = first['url'] as String?;
          if (url != null && url.isNotEmpty) {
            try {
              final imgRes = await http.get(Uri.parse(url)).timeout(_openAiTimeout);
              if (imgRes.statusCode == 200) {
                return imgRes.bodyBytes;
              } else {
                print('OpenAI Images URL fetch failed: ${imgRes.statusCode}');
              }
            } catch (e) {
              print('Error fetching image from URL: $e');
            }
          }
        }
        print('OpenAI Images API returned 200 but no usable image payload. Raw: $bodyText');
        return null;
      } else {
        final bodyText = utf8.decode(response.bodyBytes);
        print('OpenAI Images API Error: ${response.statusCode} - $bodyText');
        return null;
      }
    } on TimeoutException catch (_) {
      print('OpenAI images edit timed out after ${_openAiTimeout.inSeconds}s.');
      return null;
    } catch (e) {
      print('Error generating try-on composite: $e');
      return null;
    }
  }
}

/// OpenAI-backed implementation of the TryOnAiProvider abstraction.
class OpenAiTryOnProvider implements TryOnAiProvider {
  @override
  Future<String?> analyzeStyle(Uint8List userImage, Uint8List clothingImage) {
    return OpenAIService.generateVirtualTryOn(userImage, clothingImage);
  }

  @override
  Future<TryOnGeneration?> generateComposite(
    Uint8List userImage,
    Uint8List clothingImage, {
    String? styleAnalysis,
    String? clothingCategory,
    String? clothingName,
    String? clothingGender,
  }) {
    // OpenAI provider doesn't use the pre-computed metadata yet
    // Could be enhanced in the future to pass metadata to OpenAI
    return OpenAIService
        .generateTryOnComposite(
          userImage,
          clothingImage,
          styleAnalysis: styleAnalysis,
        )
        .then((bytes) => bytes == null ? null : TryOnGeneration(bytes: bytes));
  }
}