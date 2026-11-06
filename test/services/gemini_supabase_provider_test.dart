import 'dart:convert';
import 'dart:typed_data';

import 'package:envisionfit/services/ai/gemini_supabase_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/mock_supabase.dart';

void main() {
  late MockSupabase supabase;
  late GeminiSupabaseTryOnProvider provider;
  final userImage = Uint8List.fromList(List.generate(64, (i) => i));
  final clothImage = Uint8List.fromList(List.generate(32, (i) => 255 - i));
  final resultImage = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]);

  /// Signed-URL uploads go through the top-level `http.put`, so they are
  /// mocked with [http.runWithClient] rather than through Supabase.
  late List<http.Request> uploads;
  late int uploadStatus;

  Future<T> withUploads<T>(Future<T> Function() body) => http.runWithClient(
        body,
        () => MockClient((req) async {
          uploads.add(req);
          return http.Response('', uploadStatus);
        }),
      );

  void mockSignedUrls() {
    supabase.onFunction(
      'tryon-upload-urls',
      (_) => jsonResponse({
        'model_upload_url': 'https://storage.test/upload/model',
        'cloth_upload_url': 'https://storage.test/upload/cloth',
        'model_read_url': 'https://storage.test/read/model',
        'cloth_read_url': 'https://storage.test/read/cloth',
      }),
    );
  }

  Future generate() => withUploads(() => provider.generateComposite(
        userImage,
        clothImage,
        styleAnalysis: 'Slim fit',
        clothingCategory: 'Jacket',
        clothingName: 'Black leather jacket',
        clothingGender: 'Gentleman',
      ));

  setUp(() {
    supabase = MockSupabase();
    provider = GeminiSupabaseTryOnProvider();
    uploads = [];
    uploadStatus = 200;
  });
  tearDown(() => supabase.dispose());

  test('analyzeStyle is a no-op for this provider', () async {
    expect(await provider.analyzeStyle(userImage, clothImage), isNull);
  });

  group('URL path', () {
    test('uploads both photos and sends signed URLs with clothing metadata', () async {
      mockSignedUrls();
      supabase.onFunction(
        'tryon',
        (_) => jsonResponse({
          'result_image_url': 'https://cdn.test/result.png',
          'clothing_description': 'Jacket\nBlack leather jacket\nGentleman',
          'used_prompt': 'composed prompt',
        }),
      );

      final gen = await generate();

      expect(uploads.map((r) => r.url.toString()), [
        'https://storage.test/upload/model',
        'https://storage.test/upload/cloth',
      ]);
      expect(uploads[0].bodyBytes, userImage);
      expect(uploads[1].bodyBytes, clothImage);

      final call = supabase.callsTo('tryon').single;
      expect(call['model_image_url'], 'https://storage.test/read/model');
      expect(call['cloth_image_url'], 'https://storage.test/read/cloth');
      expect(call['clothing_category'], 'Jacket');
      expect(call['clothing_name'], 'Black leather jacket');
      expect(call['clothing_gender'], 'Gentleman');
      expect(call['prompt'], 'Slim fit');
      expect(call.containsKey('model_image_base64'), isFalse);

      expect(gen.url, 'https://cdn.test/result.png');
      expect(gen.usedPrompt, 'composed prompt');
      expect(gen.clothingDescription, 'Jacket\nBlack leather jacket\nGentleman');
    });

    test('falls back to base64 when the URL call fails', () async {
      mockSignedUrls();
      var call = 0;
      supabase.onFunction('tryon', (body) {
        call++;
        if (body.containsKey('model_image_url')) {
          return jsonResponse({'error': 'cannot fetch url'}, status: 502);
        }
        return jsonResponse({'image_base64': base64Encode(resultImage)});
      });

      final gen = await generate();

      expect(call, 2);
      final calls = supabase.callsTo('tryon');
      expect(calls[0].containsKey('model_image_url'), isTrue);
      expect(calls[1]['model_image_base64'], base64Encode(userImage));
      expect(gen.bytes, resultImage);
    });
  });

  group('base64 fallback', () {
    test('is used when signed URLs cannot be obtained', () async {
      supabase.onFunction('tryon-upload-urls', (_) => jsonResponse({'error': 'nope'}, status: 500));
      supabase.onFunction('tryon', (_) => jsonResponse({'image_base64': base64Encode(resultImage)}));

      final gen = await generate();

      expect(uploads, isEmpty);
      final call = supabase.callsTo('tryon').single;
      expect(call['model_image_base64'], base64Encode(userImage));
      expect(call['cloth_image_base64'], base64Encode(clothImage));
      expect(call['clothing_gender'], 'Gentleman');
      expect(gen.bytes, resultImage);
      expect(gen.hasUrl, isFalse);
    });

    test('is used when a signed upload is rejected', () async {
      mockSignedUrls();
      uploadStatus = 403;
      supabase.onFunction('tryon', (_) => jsonResponse({'image_base64': base64Encode(resultImage)}));

      final gen = await generate();

      expect(uploads, hasLength(1)); // stops after the model upload fails
      expect(supabase.callsTo('tryon').single.containsKey('model_image_base64'), isTrue);
      expect(gen.bytes, resultImage);
    });
  });

  group('response parsing', () {
    setUp(() => mockSignedUrls());

    test('strips a data URL prefix', () async {
      supabase.onFunction(
        'tryon',
        (_) => jsonResponse({'image': 'data:image/png;base64,${base64Encode(resultImage)}'}),
      );

      final gen = await generate();

      expect(gen.bytes, resultImage);
    });

    test('reads an image nested under result', () async {
      supabase.onFunction(
        'tryon',
        (_) => jsonResponse({
          'result': {'result_image_base64': base64Encode(resultImage)},
        }),
      );

      final gen = await generate();

      expect(gen.bytes, resultImage);
    });

    test('returns null when the function reports an error', () async {
      supabase.onFunction('tryon', (_) => jsonResponse({'error': 'quota exceeded'}));

      expect(await generate(), isNull);
    });

    test('returns null when no image is in the response', () async {
      supabase.onFunction('tryon', (_) => jsonResponse({'status': 'success'}));

      expect(await generate(), isNull);
    });
  });

  test('returns null when every tryon call fails', () async {
    supabase.onFunction('tryon-upload-urls', (_) => jsonResponse({}, status: 500));
    supabase.onFunction('tryon', (_) => jsonResponse({'error': 'down'}, status: 500));

    expect(await generate(), isNull);
  });
}
