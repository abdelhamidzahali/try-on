import 'dart:convert';
import 'dart:typed_data';

import 'package:envisionfit/services/photo_validation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/mock_supabase.dart';

void main() {
  late MockSupabase supabase;
  final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

  setUp(() => supabase = MockSupabase());
  tearDown(() => supabase.dispose());

  group('PhotoValidationResult', () {
    test('isOk is case-insensitive', () {
      expect(const PhotoValidationResult(gender: 'Man', status: 'ok', reason: null).isOk, isTrue);
      expect(const PhotoValidationResult(gender: 'Man', status: 'OK', reason: null).isOk, isTrue);
      expect(const PhotoValidationResult(gender: 'Man', status: 'NOT OK', reason: 'x').isOk, isFalse);
    });

    test('fromMap keeps a null reason null and stringifies values', () {
      final r = PhotoValidationResult.fromMap({'gender': 'Woman', 'status': 'OK', 'reason': null});
      expect(r.gender, 'Woman');
      expect(r.reason, isNull);
    });
  });

  group('PhotoValidationService.validateBytes', () {
    test('sends base64 image and photo type to profile_photo_validation', () async {
      supabase.onFunction(
        'profile_photo_validation',
        (_) => jsonResponse({'gender': 'Man', 'status': 'OK', 'reason': null}),
      );

      await PhotoValidationService.validateBytes(bytes: bytes, type: PhotoType.fullbody);

      final calls = supabase.callsTo('profile_photo_validation');
      expect(calls, hasLength(1));
      expect(calls.single['imageBase64'], base64Encode(bytes));
      expect(calls.single['photoType'], 'fullbody');
    });

    test('parses a flat JSON object', () async {
      supabase.onFunction(
        'profile_photo_validation',
        (_) => jsonResponse({'gender': 'Woman', 'status': 'NOT OK', 'reason': 'Sunglasses detected'}),
      );

      final r = await PhotoValidationService.validateBytes(bytes: bytes, type: PhotoType.selfie);

      expect(r, isNotNull);
      expect(r!.isOk, isFalse);
      expect(r.gender, 'Woman');
      expect(r.reason, 'Sunglasses detected');
    });

    test('unwraps a nested result object', () async {
      supabase.onFunction(
        'profile_photo_validation',
        (_) => jsonResponse({
          'data': {'gender': 'Man', 'status': 'OK', 'reason': null},
        }),
      );

      final r = await PhotoValidationService.validateBytes(bytes: bytes, type: PhotoType.selfie);

      expect(r?.isOk, isTrue);
      expect(r?.gender, 'Man');
    });

    test('unwraps a result field holding a JSON string', () async {
      supabase.onFunction(
        'profile_photo_validation',
        (_) => jsonResponse({
          'result': jsonEncode({'gender': 'Woman', 'status': 'OK', 'reason': null}),
        }),
      );

      final r = await PhotoValidationService.validateBytes(bytes: bytes, type: PhotoType.selfie);

      expect(r?.isOk, isTrue);
      expect(r?.gender, 'Woman');
    });

    test('parses a plain-text JSON body', () async {
      supabase.onFunction(
        'profile_photo_validation',
        (_) => http.Response(
          jsonEncode({'gender': 'Man', 'status': 'NOT OK', 'reason': 'Too dark'}),
          200,
          headers: {'content-type': 'text/plain'},
        ),
      );

      final r = await PhotoValidationService.validateBytes(bytes: bytes, type: PhotoType.selfie);

      expect(r?.isOk, isFalse);
      expect(r?.reason, 'Too dark');
    });

    test('returns null when the edge function errors', () async {
      supabase.onFunction(
        'profile_photo_validation',
        (_) => jsonResponse({'error': 'boom'}, status: 500),
      );

      final r = await PhotoValidationService.validateBytes(bytes: bytes, type: PhotoType.selfie);

      expect(r, isNull);
    });

    test('returns null for a body that is not JSON', () async {
      supabase.onFunction(
        'profile_photo_validation',
        (_) => http.Response('upstream timeout', 200, headers: {'content-type': 'text/plain'}),
      );

      final r = await PhotoValidationService.validateBytes(bytes: bytes, type: PhotoType.selfie);

      expect(r, isNull);
    });

    test('treats an object without the expected keys as not OK', () async {
      supabase.onFunction('profile_photo_validation', (_) => jsonResponse({'message': 'hello'}));

      final r = await PhotoValidationService.validateBytes(bytes: bytes, type: PhotoType.selfie);

      expect(r, isNotNull);
      expect(r!.isOk, isFalse);
    });
  });
}
