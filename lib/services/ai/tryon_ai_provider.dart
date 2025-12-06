import 'dart:typed_data';
import 'package:envisionfit/services/ai/tryon_generation.dart';

/// Abstraction for virtual try-on AI engines.
///
/// Implementations should return:
/// - analyzeStyle: a human-readable description of fit/style from two images
/// - generateComposite: PNG/JPEG bytes of the composed try-on image
abstract class TryOnAiProvider {
  Future<String?> analyzeStyle(
    Uint8List userImage,
    Uint8List clothingImage,
  );

  Future<TryOnGeneration?> generateComposite(
    Uint8List userImage,
    Uint8List clothingImage, {
    String? styleAnalysis,
    String? clothingCategory,
    String? clothingName,
    String? clothingGender,
  });
}
