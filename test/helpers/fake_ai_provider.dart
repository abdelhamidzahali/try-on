import 'dart:typed_data';

import 'package:envisionfit/services/ai/tryon_ai_provider.dart';
import 'package:envisionfit/services/ai/tryon_generation.dart';

/// Records what the try-on flow asks of the AI backend and returns canned
/// results, so `TryOnService` can be tested without Supabase.
class FakeTryOnAiProvider extends TryOnAiProvider {
  FakeTryOnAiProvider({this.styleAnalysis, this.generation, this.error});

  String? styleAnalysis;
  TryOnGeneration? generation;
  Object? error;

  int analyzeCalls = 0;
  int generateCalls = 0;
  Uint8List? lastUserImage;
  Uint8List? lastClothingImage;
  String? lastStyleAnalysis;
  String? lastClothingCategory;
  String? lastClothingName;
  String? lastClothingGender;

  @override
  Future<String?> analyzeStyle(Uint8List userImage, Uint8List clothingImage) async {
    analyzeCalls++;
    return styleAnalysis;
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
    generateCalls++;
    lastUserImage = userImage;
    lastClothingImage = clothingImage;
    lastStyleAnalysis = styleAnalysis;
    lastClothingCategory = clothingCategory;
    lastClothingName = clothingName;
    lastClothingGender = clothingGender;
    if (error != null) throw error!;
    return generation;
  }
}
