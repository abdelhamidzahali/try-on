import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:envisionfit/services/image_service.dart';
import 'package:envisionfit/services/onboarding_service.dart';
import 'package:envisionfit/supabase/supabase_config.dart';

/// Result of describing a clothing item, including gender validation
class ClothingDescription {
  final String category;
  final String name;
  final String gender; // 'Gentleman' or 'Lady'
  final String fullDescription;
  final bool genderMatches;
  final String? mismatchMessage;

  const ClothingDescription({
    required this.category,
    required this.name,
    required this.gender,
    required this.fullDescription,
    required this.genderMatches,
    this.mismatchMessage,
  });
}

/// Service to describe clothing items using the Describ_Garment edge function
class ClothingDescriptionService {
  /// Analyzes a clothing photo and returns category, name, gender, and validation result
  static Future<ClothingDescription> describeClothing(File clothingPhoto) async {
    debugPrint('[ClothingDescriptionService] Starting clothing description...');
    
    // 1. Read clothing image bytes
    final bytes = await ImageService.fileToBytes(clothingPhoto);
    if (bytes == null) {
      throw Exception('Unable to read clothing image');
    }

    // 2. Infer MIME type
    String mime = 'image/jpeg';
    final path = clothingPhoto.path.toLowerCase();
    if (path.startsWith('data:')) {
      final headerEnd = path.indexOf(';base64,');
      if (headerEnd != -1) {
        mime = path.substring(5, headerEnd);
      }
    } else if (path.endsWith('.png')) {
      mime = 'image/png';
    } else if (path.endsWith('.webp')) {
      mime = 'image/webp';
    }

    // 3. Call Describ_Garment edge function
    final b64 = base64.encode(bytes);
    debugPrint('[ClothingDescriptionService] Calling Describ_Garment edge function');
    final response = await SupabaseConfig.client.functions.invoke(
      'Describ_Garment',
      body: {
        'clothing_image_base64': b64,
        'mime_type': mime,
      },
    );

    // 4. Parse response
    String fullDescription;
    final data = response.data;
    if (data is Map && data.containsKey('description')) {
      fullDescription = data['description']?.toString() ?? '';
    } else if (data is String && data.isNotEmpty) {
      fullDescription = data;
    } else {
      throw Exception('No description returned from edge function');
    }

    debugPrint('[ClothingDescriptionService] Got description: ${fullDescription.substring(0, fullDescription.length > 100 ? 100 : fullDescription.length)}...');

    // 5. Extract category, name, and gender from description
    final parsed = _parseDescription(fullDescription);
    final category = parsed['category'] ?? '';
    final name = parsed['name'] ?? '';
    final gender = parsed['gender'] ?? '';

    if (category.isEmpty || name.isEmpty || gender.isEmpty) {
      throw Exception('Failed to extract category, name, or gender from description');
    }

    // 6. Get user gender and validate
    final userGenderRaw = await OnboardingService.getGender();
    final userGender = _normalizeGender(userGenderRaw ?? '');
    final clothingGender = _normalizeGender(gender);

    debugPrint('[ClothingDescriptionService] User gender: $userGender, Clothing gender: $clothingGender');

    final genderMatches = userGender == clothingGender;
    String? mismatchMessage;
    if (!genderMatches) {
      if (userGender == 'Gentleman' && clothingGender == 'Lady') {
        mismatchMessage = 'Seeems this outfit is for Ladies !';
      } else if (userGender == 'Lady' && clothingGender == 'Gentleman') {
        mismatchMessage = 'Seeems this outfit is for Gentlemen !';
      }
    }

    return ClothingDescription(
      category: category,
      name: name,
      gender: clothingGender,
      fullDescription: fullDescription,
      genderMatches: genderMatches,
      mismatchMessage: mismatchMessage,
    );
  }

  /// Parses the description text returned by Describ_Garment
  /// Expected format:
  /// Line 1: Category (e.g., "Outerwear")
  /// Line 2: Name (e.g., "Men's Slim-Fit Denim Jacket")
  /// Line 3: Gender (e.g., "Gentleman" or "Lady")
  /// ... rest of description
  static Map<String, String> _parseDescription(String description) {
    final lines = description
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (lines.length < 3) {
      debugPrint('[ClothingDescriptionService] Warning: Description has fewer than 3 lines');
      return {'category': '', 'name': '', 'gender': ''};
    }

    // Extract lines - may need to parse labels like "Main Category: Outerwear"
    String category = lines[0];
    String name = lines[1];
    String gender = lines[2];

    // Strip common labels
    category = category.replaceFirst(RegExp(r'^(Main )?Category:\s*', caseSensitive: false), '').trim();
    name = name.replaceFirst(RegExp(r'^(Sub-Category & Core )?Name:\s*', caseSensitive: false), '').trim();
    
    // Gender line might be just "Gentleman" or "Lady", or labeled
    if (gender.toLowerCase().contains('gentleman')) {
      gender = 'Gentleman';
    } else if (gender.toLowerCase().contains('lady') || gender.toLowerCase().contains('woman')) {
      gender = 'Lady';
    }

    debugPrint('[ClothingDescriptionService] Parsed -> category: "$category", name: "$name", gender: "$gender"');

    return {
      'category': category,
      'name': name,
      'gender': gender,
    };
  }

  /// Normalizes gender strings to 'Gentleman' or 'Lady'
  static String _normalizeGender(String value) {
    final v = value.trim().toLowerCase();
    switch (v) {
      case 'gentleman':
      case 'man':
      case 'male':
      case 'm':
        return 'Gentleman';
      case 'lady':
      case 'woman':
      case 'female':
      case 'f':
        return 'Lady';
      default:
        // Try substring heuristics
        if (v.contains('gentleman') || v.contains('male') || v.contains('men')) return 'Gentleman';
        if (v.contains('lady') || v.contains('female') || v.contains('women')) return 'Lady';
        return value.trim();
    }
  }
}
