import 'dart:io';
import 'dart:typed_data';

import 'package:envisionfit/models/tryon_session.dart';
import 'package:envisionfit/services/ai/ai_providers.dart';
import 'package:envisionfit/services/ai/tryon_ai_provider.dart';
import 'package:envisionfit/services/ai/tryon_generation.dart';
import 'package:envisionfit/services/tryon_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_ai_provider.dart';
import '../helpers/test_images.dart';

const _genderKey = 'profile_gender_v1';

void main() {
  late TryOnAiProvider originalProvider;
  late FakeTryOnAiProvider ai;
  late File userPhoto;
  late File clothingPhoto;
  late Uint8List userBytes;
  late Uint8List clothingBytes;

  setUpAll(() => originalProvider = AiProviders.current);
  tearDownAll(() => AiProviders.current = originalProvider);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ai = FakeTryOnAiProvider();
    AiProviders.current = ai;
    userBytes = solidJpeg(width: 40, height: 60, grey: 180);
    clothingBytes = solidJpeg(width: 30, height: 30, grey: 90);
    userPhoto = await writeTempImage(userBytes, name: 'user.jpg');
    clothingPhoto = await writeTempImage(clothingBytes, name: 'cloth.jpg');
  });

  Future<TryOnSession> newSession({String? clothingGender}) => TryOnService.createSession(
        userId: 'user-1',
        userPhoto: userPhoto,
        clothingId: 'jacket-1',
        clothingPhoto: clothingPhoto,
        clothingCategory: 'Jacket',
        clothingName: 'Black leather jacket',
        clothingGender: clothingGender,
      );

  Future<void> setUserGender(String gender) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_genderKey, gender);
  }

  group('createSession', () {
    test('persists a pending session with the clothing metadata', () async {
      final session = await newSession(clothingGender: 'Gentleman');

      expect(session.status, TryOnStatus.pending);
      final stored = await TryOnService.getSessionById(session.id);
      expect(stored, isNotNull);
      expect(stored!.userPhotoPath, userPhoto.path);
      expect(stored.clothingPhotoPath, clothingPhoto.path);
      expect(stored.clothingName, 'Black leather jacket');
      expect(stored.clothingGender, 'Gentleman');
    });
  });

  group('processSession', () {
    test('returns null for an unknown session', () async {
      expect(await TryOnService.processSession('missing'), isNull);
    });

    test('completes with the image URL returned by the AI backend', () async {
      await setUserGender('gentleman');
      ai
        ..styleAnalysis = 'Relaxed fit'
        ..generation = const TryOnGeneration(
          url: 'https://cdn.example.com/result.png',
          usedPrompt: 'final prompt',
          clothingDescription: 'Jacket\nBlack leather jacket\nGentleman',
        );
      final session = await newSession(clothingGender: 'Gentleman');

      final result = await TryOnService.processSession(session.id);

      expect(result!.status, TryOnStatus.completed);
      expect(result.result!.imagePath, 'https://cdn.example.com/result.png');
      expect(result.result!.prompt, 'final prompt');
      expect(result.result!.userId, 'user-1');

      // The provider received the photo bytes and the pre-computed metadata.
      expect(ai.lastUserImage, userBytes);
      expect(ai.lastClothingImage, clothingBytes);
      expect(ai.lastStyleAnalysis, 'Relaxed fit');
      expect(ai.lastClothingCategory, 'Jacket');
      expect(ai.lastClothingName, 'Black leather jacket');
      expect(ai.lastClothingGender, 'Gentleman');

      // The persisted copy matches what was returned.
      final stored = await TryOnService.getSessionById(session.id);
      expect(stored!.status, TryOnStatus.completed);
      expect(stored.result!.imagePath, 'https://cdn.example.com/result.png');
    });

    test('falls back to the style analysis as prompt when none is returned', () async {
      ai
        ..styleAnalysis = 'Relaxed fit'
        ..generation = const TryOnGeneration(url: 'https://cdn.example.com/r.png');
      final session = await newSession();

      final result = await TryOnService.processSession(session.id);

      expect(result!.result!.prompt, 'Relaxed fit');
    });

    test('fails before generating when the outfit is for the other gender', () async {
      await setUserGender('lady');
      ai.generation = const TryOnGeneration(url: 'https://cdn.example.com/r.png');
      final session = await newSession(clothingGender: 'Gentleman');

      final result = await TryOnService.processSession(session.id);

      expect(result!.status, TryOnStatus.failed);
      expect(result.errorMessage, 'Seeems this outfit is for Gentlemen !');
      expect(ai.generateCalls, 0);
    });

    test('fails when the returned clothing description is for the other gender', () async {
      await setUserGender('man');
      ai.generation = const TryOnGeneration(
        url: 'https://cdn.example.com/r.png',
        clothingDescription: 'Dress\nPink floral dress\nLady',
      );
      final session = await newSession();

      final result = await TryOnService.processSession(session.id);

      expect(result!.status, TryOnStatus.failed);
      expect(result.errorMessage, 'Seeems this outfit is for Ladies !');
      expect(result.result, isNull);
    });

    test('runs normally when the user has not picked a gender', () async {
      ai.generation = const TryOnGeneration(url: 'https://cdn.example.com/r.png');
      final session = await newSession(clothingGender: 'Lady');

      final result = await TryOnService.processSession(session.id);

      expect(result!.status, TryOnStatus.completed);
    });

    test('explains a missing style analysis when no image comes back', () async {
      final session = await newSession();

      final result = await TryOnService.processSession(session.id);

      expect(result!.status, TryOnStatus.failed);
      expect(result.errorMessage, contains('AI style analysis unavailable'));
    });

    test('reports that the AI returned no image when analysis succeeded', () async {
      ai.styleAnalysis = 'Relaxed fit';
      final session = await newSession();

      final result = await TryOnService.processSession(session.id);

      expect(result!.status, TryOnStatus.failed);
      expect(result.errorMessage, contains('AI did not return an image'));
    });

    test('fails when the photos cannot be read', () async {
      final session = await newSession();
      await userPhoto.delete();

      final result = await TryOnService.processSession(session.id);

      expect(result!.status, TryOnStatus.failed);
      expect(result.errorMessage, 'Failed to load images');
      expect(ai.generateCalls, 0);
    });

    test('records the error when the AI provider throws', () async {
      ai.error = Exception('network down');
      final session = await newSession();

      final result = await TryOnService.processSession(session.id);

      expect(result!.status, TryOnStatus.failed);
      expect(result.errorMessage, contains('network down'));
      final stored = await TryOnService.getSessionById(session.id);
      expect(stored!.status, TryOnStatus.failed);
    });
  });

  group('processSessionWithAnalysis', () {
    test('passes the given analysis through without re-analysing', () async {
      ai.generation = const TryOnGeneration(url: 'https://cdn.example.com/r.png');
      final session = await newSession();

      final result = await TryOnService.processSessionWithAnalysis(session.id, 'Slim fit');

      expect(result!.status, TryOnStatus.completed);
      expect(ai.analyzeCalls, 0);
      expect(ai.lastStyleAnalysis, 'Slim fit');
      expect(result.result!.prompt, 'Slim fit');
    });

    test('fails on a gender mismatch in the clothing description', () async {
      await setUserGender('Lady');
      ai.generation = const TryOnGeneration(
        url: 'https://cdn.example.com/r.png',
        clothingDescription: 'Shirt\nWhite button shirt\nGentleman',
      );
      final session = await newSession();

      final result = await TryOnService.processSessionWithAnalysis(session.id, null);

      expect(result!.status, TryOnStatus.failed);
      expect(result.errorMessage, 'Seeems this outfit is for Gentlemen !');
    });

    test('fails when the AI returns nothing', () async {
      final session = await newSession();

      final result = await TryOnService.processSessionWithAnalysis(session.id, 'Slim fit');

      expect(result!.status, TryOnStatus.failed);
      expect(result.errorMessage, contains('AI did not return an image'));
    });
  });
}
