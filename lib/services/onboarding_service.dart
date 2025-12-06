import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _completedKey = 'onboarding_completed_v1';
  static const String _nameKey = 'profile_name_v1';
  static const String _emailKey = 'profile_email_v1';
  static const String _genderKey = 'profile_gender_v1';
  static const String _selfiePathKey = 'profile_selfie_path_v1';
  static const String _fullBodyPathKey = 'profile_fullbody_path_v1';

  static Future<bool> isCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_completedKey) ?? false;
    } catch (e) {
      debugPrint('OnboardingService.isCompleted error: $e');
      return false;
    }
  }

  static Future<void> setCompleted({
    required String name,
    required String email,
    String? gender,
    String? selfiePath,
    String? fullBodyPath,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_nameKey, name);
      await prefs.setString(_emailKey, email);
      if (gender != null && gender.isNotEmpty) {
        await prefs.setString(_genderKey, gender);
      }
      if (selfiePath != null && selfiePath.isNotEmpty) {
        await prefs.setString(_selfiePathKey, selfiePath);
      }
      if (fullBodyPath != null && fullBodyPath.isNotEmpty) {
        await prefs.setString(_fullBodyPathKey, fullBodyPath);
      }
      await prefs.setBool(_completedKey, true);
    } catch (e) {
      debugPrint('OnboardingService.setCompleted error: $e');
    }
  }

  static Future<String?> getName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_nameKey);
    } catch (e) {
      debugPrint('OnboardingService.getName error: $e');
      return null;
    }
  }

  static Future<String?> getEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_emailKey);
    } catch (e) {
      debugPrint('OnboardingService.getEmail error: $e');
      return null;
    }
  }

  static Future<String?> getGender() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_genderKey);
    } catch (e) {
      debugPrint('OnboardingService.getGender error: $e');
      return null;
    }
  }

  static Future<String?> getSelfiePath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_selfiePathKey);
    } catch (e) {
      debugPrint('OnboardingService.getSelfiePath error: $e');
      return null;
    }
  }

  static Future<String?> getFullBodyPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_fullBodyPathKey);
    } catch (e) {
      debugPrint('OnboardingService.getFullBodyPath error: $e');
      return null;
    }
  }
}
