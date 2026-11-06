import 'dart:io';
import 'dart:typed_data';

import 'package:envisionfit/screens/onboarding_fullbody_screen.dart';
import 'package:envisionfit/screens/onboarding_photos_screen.dart';
import 'package:envisionfit/services/fullbody_gallery_service.dart';
import 'package:envisionfit/services/model_gallery_service.dart';
import 'package:envisionfit/widgets/photo_capture_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_supabase.dart';
import '../helpers/test_images.dart';

/// Widget tests for how the onboarding screens react to photo validation.
///
/// The photo picker is bypassed: each test hands a file straight to the
/// screen's [PhotoCaptureCard.onImageSelected] callback, which is what the
/// card calls after the user picks or captures a photo. The validation edge
/// function is answered by [MockSupabase].
void main() {
  late MockSupabase supabase;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    supabase = MockSupabase();
  });
  tearDown(() => supabase.dispose());

  void validationReturns(Map<String, dynamic> body) {
    supabase.onFunction('profile_photo_validation', (_) => jsonResponse(body));
  }

  void validationIsDown() {
    supabase.onFunction('profile_photo_validation', (_) => jsonResponse({'error': 'down'}, status: 500));
  }

  /// Pumps [screen], hands it a photo made of [bytes] and returns once the
  /// validation round-trip and resulting UI update have finished.
  Future<void> pickPhoto(WidgetTester tester, Widget screen, Uint8List bytes) async {
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pump();

    final card = tester.widget<PhotoCaptureCard>(find.byType(PhotoCaptureCard));
    await tester.runAsync(() async {
      final File file = await writeTempImage(bytes);
      await card.onImageSelected(file);
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  final goodSelfie = solidJpeg(width: 500, height: 500);
  final goodFullBody = solidJpeg(width: 400, height: 800);

  group('Selfie onboarding', () {
    Widget screen({String? gender = 'gentleman'}) =>
        OnboardingPhotosScreen(name: 'Sam', email: 'sam@example.com', gender: gender);

    Future<int> savedSelfies() async => (await ModelGalleryService.getAll()).length;

    testWidgets('shows the reason and does not save when validation says NOT OK', (tester) async {
      validationReturns({'gender': 'Man', 'status': 'NOT OK', 'reason': 'Please remove your sunglasses.'});

      await pickPhoto(tester, screen(), goodSelfie);

      expect(find.text('Please remove your sunglasses.'), findsOneWidget);
      expect(await tester.runAsync(savedSelfies), 0);
      expect(supabase.callsTo('profile_photo_validation').single['photoType'], 'selfie');
    });

    testWidgets('shows a generic message when NOT OK comes without a reason', (tester) async {
      validationReturns({'gender': 'Man', 'status': 'NOT OK', 'reason': ''});

      await pickPhoto(tester, screen(), goodSelfie);

      expect(find.text('Photo not accepted.'), findsOneWidget);
      expect(await tester.runAsync(savedSelfies), 0);
    });

    testWidgets('rejects a photo where no person is found', (tester) async {
      validationReturns({'gender': 'NA', 'status': 'OK', 'reason': null});

      await pickPhoto(tester, screen(), goodSelfie);

      expect(
        find.text("Can't identify a person in the photo. Please upload a clear photo."),
        findsOneWidget,
      );
      expect(await tester.runAsync(savedSelfies), 0);
    });

    testWidgets('rejects a woman when Gentleman was selected', (tester) async {
      validationReturns({'gender': 'Woman', 'status': 'OK', 'reason': null});

      await pickPhoto(tester, screen(gender: 'gentleman'), goodSelfie);

      expect(
        find.text('Selected gender is Gentleman, but the photo appears to be a Woman. '
            'Please upload a photo matching the selected gender.'),
        findsOneWidget,
      );
      expect(await tester.runAsync(savedSelfies), 0);
    });

    testWidgets('rejects a man when Lady was selected', (tester) async {
      validationReturns({'gender': 'Man', 'status': 'OK', 'reason': null});

      await pickPhoto(tester, screen(gender: 'lady'), goodSelfie);

      expect(
        find.text('Selected gender is Lady, but the photo appears to be a Man. '
            'Please upload a photo matching the selected gender.'),
        findsOneWidget,
      );
      expect(await tester.runAsync(savedSelfies), 0);
    });

    testWidgets('saves the photo as default when validation passes', (tester) async {
      validationReturns({'gender': 'Woman', 'status': 'OK', 'reason': null});

      await pickPhoto(tester, screen(gender: 'lady'), goodSelfie);

      final saved = await tester.runAsync(ModelGalleryService.getAll);
      expect(saved, hasLength(1));
      expect(saved!.single.isDefault, isTrue);
      expect(find.byType(SnackBar), findsNothing); // guests get no remote "looks good" toast
    });

    testWidgets('falls back to local checks and accepts a good photo when the service is down', (tester) async {
      validationIsDown();

      await pickPhoto(tester, screen(), goodSelfie);

      expect(find.text('Selfie looks good (basic checks).'), findsOneWidget);
      expect(await tester.runAsync(savedSelfies), 1);
    });

    testWidgets('falls back to local checks and rejects a dark photo when the service is down', (tester) async {
      validationIsDown();

      await pickPhoto(tester, screen(), solidJpeg(width: 500, height: 500, grey: 15));

      expect(find.text('The photo seems too dark. Please retake in better lighting.'), findsOneWidget);
      expect(await tester.runAsync(savedSelfies), 0);
    });
  });

  group('Full-body onboarding', () {
    Widget screen({String? gender = 'gentleman'}) =>
        OnboardingFullBodyScreen(name: 'Sam', email: 'sam@example.com', gender: gender);

    Future<int> savedFullBodies() async => (await FullBodyGalleryService.getAll()).length;

    testWidgets('sends the photo as fullbody and shows the rejection reason', (tester) async {
      validationReturns({'gender': 'Man', 'status': 'NOT OK', 'reason': 'Your whole body must be visible.'});

      await pickPhoto(tester, screen(), goodFullBody);

      expect(find.text('Your whole body must be visible.'), findsOneWidget);
      expect(supabase.callsTo('profile_photo_validation').single['photoType'], 'fullbody');
      expect(await tester.runAsync(savedFullBodies), 0);
    });

    testWidgets('rejects a gender mismatch', (tester) async {
      validationReturns({'gender': 'Woman', 'status': 'OK', 'reason': null});

      await pickPhoto(tester, screen(gender: 'gentleman'), goodFullBody);

      expect(find.textContaining('Selected gender is Gentleman'), findsOneWidget);
      expect(await tester.runAsync(savedFullBodies), 0);
    });

    testWidgets('saves the photo when validation passes', (tester) async {
      validationReturns({'gender': 'Man', 'status': 'OK', 'reason': null});

      await pickPhoto(tester, screen(), goodFullBody);

      expect(await tester.runAsync(savedFullBodies), 1);
    });

    testWidgets('falls back to local checks and rejects a landscape photo', (tester) async {
      validationIsDown();

      await pickPhoto(tester, screen(), solidJpeg(width: 1000, height: 800));

      expect(
        find.text('Please upload a portrait-oriented full-body photo (taller than it is wide).'),
        findsOneWidget,
      );
      expect(await tester.runAsync(savedFullBodies), 0);
    });

    testWidgets('falls back to local checks and accepts a good photo', (tester) async {
      validationIsDown();

      await pickPhoto(tester, screen(), goodFullBody);

      expect(find.text('Full-body looks good (basic checks).'), findsOneWidget);
      expect(await tester.runAsync(savedFullBodies), 1);
    });
  });
}
