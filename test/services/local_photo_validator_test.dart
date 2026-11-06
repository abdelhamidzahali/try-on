import 'dart:typed_data';

import 'package:envisionfit/services/local_photo_validator.dart';
import 'package:envisionfit/services/photo_validation_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_images.dart';

void main() {
  group('LocalPhotoValidator.basicChecks', () {
    test('rejects bytes that are not an image', () async {
      final r = await LocalPhotoValidator.basicChecks(Uint8List.fromList([0, 1, 2, 3]), PhotoType.selfie);
      expect(r.ok, isFalse);
      // The image package either returns null or throws on garbage input,
      // which map to two different messages; both must reject the photo.
      expect(r.reason, anyOf('Unsupported image format.', 'Could not analyze the image locally.'));
    });

    test('accepts a bright selfie of at least 400x400', () async {
      final r = await LocalPhotoValidator.basicChecks(solidJpeg(width: 400, height: 400), PhotoType.selfie);
      expect(r.ok, isTrue);
      expect(r.reason, isNull);
    });

    test('rejects a low-resolution selfie', () async {
      final r = await LocalPhotoValidator.basicChecks(solidJpeg(width: 399, height: 600), PhotoType.selfie);
      expect(r.ok, isFalse);
      expect(r.reason, contains('resolution is too low'));
    });

    test('rejects a dark selfie', () async {
      final r = await LocalPhotoValidator.basicChecks(
        solidJpeg(width: 500, height: 500, grey: 20),
        PhotoType.selfie,
      );
      expect(r.ok, isFalse);
      expect(r.reason, contains('too dark'));
    });

    test('accepts a bright portrait full-body photo', () async {
      final r = await LocalPhotoValidator.basicChecks(solidJpeg(width: 400, height: 800), PhotoType.fullbody);
      expect(r.ok, isTrue);
    });

    test('rejects a full-body photo shorter than 700px', () async {
      final r = await LocalPhotoValidator.basicChecks(solidJpeg(width: 400, height: 699), PhotoType.fullbody);
      expect(r.ok, isFalse);
      expect(r.reason, contains('>= 700px tall'));
    });

    test('rejects a landscape full-body photo', () async {
      final r = await LocalPhotoValidator.basicChecks(solidJpeg(width: 1000, height: 800), PhotoType.fullbody);
      expect(r.ok, isFalse);
      expect(r.reason, contains('portrait-oriented'));
    });

    test('uses a lower darkness threshold for full-body than for selfies', () async {
      // Grey 40 sits between the full-body (38) and selfie (45) thresholds.
      final selfie = await LocalPhotoValidator.basicChecks(
        solidJpeg(width: 500, height: 800, grey: 40),
        PhotoType.selfie,
      );
      final fullbody = await LocalPhotoValidator.basicChecks(
        solidJpeg(width: 500, height: 800, grey: 40),
        PhotoType.fullbody,
      );
      expect(selfie.ok, isFalse);
      expect(fullbody.ok, isTrue);
    });
  });
}
