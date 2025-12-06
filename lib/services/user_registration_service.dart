import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:envisionfit/services/onboarding_service.dart';
import 'package:envisionfit/services/model_gallery_service.dart';
import 'package:envisionfit/services/fullbody_gallery_service.dart';
import 'package:envisionfit/models/model_image.dart';
import 'package:envisionfit/supabase/supabase_config.dart';
import 'package:envisionfit/supabase/supabase_config.dart' show SupabaseUserService;

class UserRegistrationService {
  /// Completes onboarding: ensures both photos exist, persists locally, and upserts basics to Supabase.
  /// Returns a tuple with the two paths if successful; otherwise returns null.
  static Future<({String selfiePath, String fullBodyPath})?> completeRegistration({
    required String name,
    required String email,
    String? gender,
  }) async {
    try {
      // Load defaults from both galleries
      final ModelImage? selfie = await ModelGalleryService.getDefault();
      final ModelImage? fullBody = await FullBodyGalleryService.getDefault();
      if (selfie == null || fullBody == null) {
        debugPrint('[Registration] Missing required photos: selfie=${selfie != null}, fullBody=${fullBody != null}');
        return null;
      }

      final selfiePath = selfie.path;
      final fullBodyPath = fullBody.path;

      // Persist to local onboarding storage
      await OnboardingService.setCompleted(
        name: name,
        email: email,
        gender: gender,
        selfiePath: selfiePath,
        fullBodyPath: fullBodyPath,
      );

      // Attempt to upsert to Supabase 'users' table using auth uid if available
      final authUser = SupabaseConfig.auth.currentUser;
      final uid = authUser?.id;
      final nowIso = DateTime.now().toIso8601String();

      if (uid != null) {
        try {
          // Try update first; if not exists, create
          final existing = await SupabaseUserService.getUserById(uid);
          final baseData = <String, dynamic>{
            'name': name,
            'email': email,
            if (gender != null && gender.isNotEmpty) 'gender': gender,
            'updatedAt': nowIso,
            // Save local references so we can rehydrate later; you may switch to Storage URLs
            'selfieImagePath': selfiePath,
            'fullBodyImagePath': fullBodyPath,
          };

          if (existing != null) {
            await SupabaseUserService.updateUser(uid, baseData);
          } else {
            final createData = <String, dynamic>{
              'id': uid,
              ...baseData,
              'createdAt': nowIso,
            };
            await SupabaseUserService.createUser(createData);
          }
        } catch (e) {
          debugPrint('[Registration] Supabase upsert (with photo paths) failed: $e');
          // Fallback: save minimal fields
          try {
            final existing = await SupabaseUserService.getUserById(uid);
            final minimal = <String, dynamic>{
              'name': name,
              'email': email,
              if (gender != null && gender.isNotEmpty) 'gender': gender,
              'updatedAt': nowIso,
            };
            if (existing != null) {
              await SupabaseUserService.updateUser(uid, minimal);
            } else {
              await SupabaseUserService.createUser({
                'id': uid,
                ...minimal,
                'createdAt': nowIso,
              });
            }
          } catch (e2) {
            debugPrint('[Registration] Supabase minimal upsert failed: $e2');
          }
        }
      } else {
        debugPrint('[Registration] No authenticated user, skipping Supabase upsert');
      }

      return (selfiePath: selfiePath, fullBodyPath: fullBodyPath);
    } catch (e, st) {
      debugPrint('[Registration] completeRegistration error: $e');
      debugPrint('[Registration] stack: $st');
      return null;
    }
  }
}
