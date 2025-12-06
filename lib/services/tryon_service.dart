import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:envisionfit/models/tryon_session.dart';
import 'package:envisionfit/models/generated_image.dart';
import 'package:envisionfit/services/ai/ai_providers.dart';
import 'package:envisionfit/services/image_service.dart';
import 'package:envisionfit/services/ai/tryon_generation.dart';
import 'package:envisionfit/services/onboarding_service.dart';
import 'package:envisionfit/supabase/supabase_config.dart';

class TryOnService {
  static const String _tryOnKey = 'tryon_sessions';
  static const int _maxSessionsToKeep = 8; // Cap persisted history to avoid quota issues

  static Future<List<TryOnSession>> getAllSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? sessionsJson = prefs.getString(_tryOnKey);
      
      if (sessionsJson != null) {
        final List<dynamic> decodedData = json.decode(sessionsJson);
        bool hadInvalid = false;
        final list = decodedData.map((item) {
          try {
            return TryOnSession.fromJson(item as Map<String, dynamic>);
          } catch (e) {
            print('Error parsing try-on session: $e');
            hadInvalid = true;
            return null;
          }
        }).where((item) => item != null).cast<TryOnSession>().toList();

        // Sanitize and trim persisted list if needed
        if (hadInvalid || list.length > _maxSessionsToKeep) {
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final trimmed = list.take(_maxSessionsToKeep).toList();
          await _saveSessionsList(trimmed);
          return trimmed;
        }
        return list;
      }
      
      return [];
    } catch (e) {
      print('Error loading try-on sessions: $e');
      return [];
    }
  }

  static Future<TryOnSession?> getSessionById(String id) async {
    final sessions = await getAllSessions();
    try {
      return sessions.firstWhere((session) => session.id == id);
    } catch (e) {
      return null;
    }
  }

  static Future<List<TryOnSession>> getSessionsByUserId(String userId) async {
    final sessions = await getAllSessions();
    return sessions.where((session) => session.userId == userId).toList();
  }

  static Future<List<TryOnSession>> getRecentSessions({int limit = 10}) async {
    final sessions = await getAllSessions();
    sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions.take(limit).toList();
  }

  static Future<TryOnSession> createSession({
    required String userId,
    required File userPhoto,
    required String clothingId,
    required File clothingPhoto,
    String? clothingCategory,
    String? clothingName,
    String? clothingGender,
  }) async {
    try {
      final sessionId = _generateSessionId();
      final now = DateTime.now();

      // Use the provided image references directly to avoid filesystem
      // dependencies (especially on Web where path_provider is unavailable).
      // If later we need persistent copies, we can add a platform-specific
      // copy step guarded behind a feature flag.
      final resolvedUserFile = userPhoto;
      final resolvedClothingFile = clothingPhoto;

      // Store metadata in session for later use
      final session = TryOnSession(
        id: sessionId,
        userId: userId,
        userPhotoPath: resolvedUserFile.path,
        clothingId: clothingId,
        clothingPhotoPath: resolvedClothingFile.path,
        clothingCategory: clothingCategory,
        clothingName: clothingName,
        clothingGender: clothingGender,
        status: TryOnStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      await _saveSession(session);
      return session;
    } catch (e) {
      print('Error creating try-on session: $e');
      rethrow;
    }
  }

  static Future<TryOnSession?> processSession(String sessionId) async {
    try {
      final session = await getSessionById(sessionId);
      if (session == null) return null;

      // Update status to processing
      final processingSession = session.copyWith(
        status: TryOnStatus.processing,
        updatedAt: DateTime.now(),
      );
      await _saveSession(processingSession);

      // Load images and convert to bytes
      final userImageBytes = await ImageService.fileToBytes(File(session.userPhotoPath));
      final clothingImageBytes = await ImageService.fileToBytes(File(session.clothingPhotoPath));

      if (userImageBytes == null || clothingImageBytes == null) {
        final failedSession = session.copyWith(
          status: TryOnStatus.failed,
          errorMessage: 'Failed to load images',
          updatedAt: DateTime.now(),
        );
        await _saveSession(failedSession);
        return failedSession;
      }

      // Log which AI provider is currently active to aid diagnostics
      debugPrint('TryOnService using AI provider: ${AiProviders.current.runtimeType}');

      // PRE-CHECK: Use pre-computed clothing gender (no Describ_Garment here)
      try {
        final userGenderRaw = (await OnboardingService.getGender()) ?? '';
        final userGenderNorm = _normalizeGender(userGenderRaw);
        final describedGender = session.clothingGender;
        debugPrint('Gender pre-check -> user="$userGenderNorm" described="$describedGender"');
        final mismatchMessage = _getGenderMismatchMessage(userGenderNorm, describedGender);
        if (mismatchMessage != null) {
          final failedSession = session.copyWith(
            status: TryOnStatus.failed,
            errorMessage: mismatchMessage,
            updatedAt: DateTime.now(),
          );
          await _saveSession(failedSession);
          return failedSession;
        }
      } catch (e) {
        debugPrint('Gender pre-check (using session metadata) failed softly: $e');
      }

      // Generate AI description
      final aiResult = await AiProviders.current.analyzeStyle(
        userImageBytes,
        clothingImageBytes,
      );

      // Use pre-computed metadata stored on the session
      final String? category = session.clothingCategory;
      final String? name = session.clothingName;
      final String? gender = session.clothingGender;

      final generation = await AiProviders.current.generateComposite(
        userImageBytes,
        clothingImageBytes,
        styleAnalysis: aiResult,
        clothingCategory: category,
        clothingName: name,
        clothingGender: gender,
      );

      if (generation != null) {
        // Secondary guard using generation's clothingDescription if present
        try {
          final userGenderRaw = (await OnboardingService.getGender()) ?? '';
          final userGenderNorm = _normalizeGender(userGenderRaw);
          final describedGender = _extractGenderFromDescription(generation.clothingDescription);
          debugPrint('Gender check -> user="$userGenderNorm" described="$describedGender"');
          final mismatchMessage = _getGenderMismatchMessage(userGenderNorm, describedGender);
          if (mismatchMessage != null) {
            final failedSession = session.copyWith(
              status: TryOnStatus.failed,
              errorMessage: mismatchMessage,
              updatedAt: DateTime.now(),
            );
            await _saveSession(failedSession);
            return failedSession;
          }
        } catch (e) {
          debugPrint('Gender check failed softly: $e');
        }

        // If we got a URL from the Edge Function, store it directly
          if (generation.hasUrl) {
          final generatedImage = GeneratedImage(
            id: _generateImageId(),
            userId: session.userId,
            imagePath: generation.url!,
              prompt: generation.usedPrompt ?? aiResult ?? 'Try-on generated successfully.',
            clothingDescription: generation.clothingDescription,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final completedSession = session.copyWith(
            status: TryOnStatus.completed,
            result: generatedImage,
            updatedAt: DateTime.now(),
          );
          await _saveSession(completedSession);
          return completedSession;
        }

        // Otherwise, fall back to saving the returned bytes locally
        if (generation.hasBytes) {
          final saved = await ImageService.saveBytesToImageFile(
            generation.bytes!,
            ImageService.generateFileName('generated_${session.id}').replaceAll('.jpg', '.png'),
            mimeType: 'image/png',
          );

          if (saved != null) {
            final generatedImage = GeneratedImage(
              id: _generateImageId(),
              userId: session.userId,
              imagePath: saved.path,
              prompt: generation.usedPrompt ?? aiResult ?? 'Try-on generated successfully.',
              clothingDescription: generation.clothingDescription,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            final completedSession = session.copyWith(
              status: TryOnStatus.completed,
              result: generatedImage,
              updatedAt: DateTime.now(),
            );
            await _saveSession(completedSession);
            return completedSession;
          }
        }
      }

      // At this point, either the AI provider returned no image or saving failed.
      // Provide a more actionable error.
      final String reason;
      if (aiResult == null) {
        reason = 'AI style analysis unavailable. Please check your AI backend configuration or try again later.';
      } else {
        reason = 'AI did not return an image. Please try again.';
      }

      print('TryOn failure diagnostic: aiResultIsNull=${aiResult == null}');

      final failedSession = session.copyWith(
        status: TryOnStatus.failed,
        errorMessage: 'Failed to generate try-on image. $reason',
        updatedAt: DateTime.now(),
      );
      await _saveSession(failedSession);
      return failedSession;
    } catch (e) {
      print('Error processing try-on session: $e');
      
      final session = await getSessionById(sessionId);
      if (session != null) {
        final failedSession = session.copyWith(
          status: TryOnStatus.failed,
          errorMessage: e.toString(),
          updatedAt: DateTime.now(),
        );
        await _saveSession(failedSession);
        return failedSession;
      }
      return null;
    }
  }

  /// Returns the style analysis text for a given session by loading the
  /// user and clothing images and calling the active AI provider. Does not mutate session.
  static Future<String?> getStyleAnalysisForSession(String sessionId) async {
    try {
      final session = await getSessionById(sessionId);
      if (session == null) return null;

      final userImageBytes = await ImageService.fileToBytes(File(session.userPhotoPath));
      final clothingImageBytes = await ImageService.fileToBytes(File(session.clothingPhotoPath));

      if (userImageBytes == null || clothingImageBytes == null) {
        return null;
      }

      final aiResult = await AiProviders.current.analyzeStyle(
        userImageBytes,
        clothingImageBytes,
      );
      return aiResult;
    } catch (e) {
      print('Error getting style analysis: $e');
      return null;
    }
  }

  /// Processes a session using a pre-computed [styleAnalysis] to generate the
  /// final composite image. Updates the session status and result.
  static Future<TryOnSession?> processSessionWithAnalysis(
    String sessionId,
    String? styleAnalysis,
  ) async {
    try {
      final session = await getSessionById(sessionId);
      if (session == null) return null;

      // Update status to processing
      final processingSession = session.copyWith(
        status: TryOnStatus.processing,
        updatedAt: DateTime.now(),
      );
      await _saveSession(processingSession);

      // Load images and convert to bytes
      final userImageBytes = await ImageService.fileToBytes(File(session.userPhotoPath));
      final clothingImageBytes = await ImageService.fileToBytes(File(session.clothingPhotoPath));

      if (userImageBytes == null || clothingImageBytes == null) {
        final failedSession = session.copyWith(
          status: TryOnStatus.failed,
          errorMessage: 'Failed to load images',
          updatedAt: DateTime.now(),
        );
        await _saveSession(failedSession);
        return failedSession;
      }

      // Use pre-computed metadata stored on the session
      final String? category = session.clothingCategory;
      final String? name = session.clothingName;
      final String? gender = session.clothingGender;

      // Generate composite try-on image using the provided analysis
      final generation = await AiProviders.current.generateComposite(
        userImageBytes,
        clothingImageBytes,
        styleAnalysis: styleAnalysis,
        clothingCategory: category,
        clothingName: name,
        clothingGender: gender,
      );

      if (generation != null) {
        // Gender guard identical to processSession()
        try {
          final userGender = (await OnboardingService.getGender())?.trim();
          final describedGender = _extractGenderFromDescription(generation.clothingDescription);
          debugPrint('Gender check (withAnalysis) -> user="$userGender" described="$describedGender"');
          final mismatchMessage = _getGenderMismatchMessage(userGender, describedGender);
          if (mismatchMessage != null) {
            final failedSession = session.copyWith(
              status: TryOnStatus.failed,
              errorMessage: mismatchMessage,
              updatedAt: DateTime.now(),
            );
            await _saveSession(failedSession);
            return failedSession;
          }
        } catch (e) {
          debugPrint('Gender check (withAnalysis) failed softly: $e');
        }

        if (generation.hasUrl) {
          final generatedImage = GeneratedImage(
            id: _generateImageId(),
            userId: session.userId,
            imagePath: generation.url!,
            prompt: generation.usedPrompt ?? styleAnalysis ?? 'Try-on generated successfully.',
            clothingDescription: generation.clothingDescription,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final completedSession = session.copyWith(
            status: TryOnStatus.completed,
            result: generatedImage,
            updatedAt: DateTime.now(),
          );
          await _saveSession(completedSession);
          return completedSession;
        }

        if (generation.hasBytes) {
          final saved = await ImageService.saveBytesToImageFile(
            generation.bytes!,
            ImageService.generateFileName('generated_${session.id}').replaceAll('.jpg', '.png'),
            mimeType: 'image/png',
          );

        if (saved != null) {
            final generatedImage = GeneratedImage(
              id: _generateImageId(),
              userId: session.userId,
              imagePath: saved.path,
            prompt: generation.usedPrompt ?? styleAnalysis ?? 'Try-on generated successfully.',
              clothingDescription: generation.clothingDescription,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            final completedSession = session.copyWith(
              status: TryOnStatus.completed,
              result: generatedImage,
              updatedAt: DateTime.now(),
            );
            await _saveSession(completedSession);
            return completedSession;
          }
        }
      }

      final failedSession = session.copyWith(
        status: TryOnStatus.failed,
        errorMessage: 'Failed to generate try-on image. AI did not return an image. Please try again.',
        updatedAt: DateTime.now(),
      );
      await _saveSession(failedSession);
      return failedSession;
    } catch (e) {
      print('Error processing with analysis: $e');
      final session = await getSessionById(sessionId);
      if (session != null) {
        final failedSession = session.copyWith(
          status: TryOnStatus.failed,
          errorMessage: e.toString(),
          updatedAt: DateTime.now(),
        );
        await _saveSession(failedSession);
        return failedSession;
      }
      return null;
    }
  }

  static Future<bool> deleteSession(String sessionId) async {
    try {
      final sessions = await getAllSessions();
      final sessionToDelete = sessions.where((s) => s.id == sessionId).firstOrNull;
      
      if (sessionToDelete != null) {
        // Delete associated images
        await ImageService.deleteImage(sessionToDelete.userPhotoPath);
        await ImageService.deleteImage(sessionToDelete.clothingPhotoPath);
      }
      
      sessions.removeWhere((session) => session.id == sessionId);
      return await _saveSessionsList(sessions);
    } catch (e) {
      print('Error deleting try-on session: $e');
      return false;
    }
  }

  static Future<bool> _saveSession(TryOnSession session) async {
    try {
      final sessions = await getAllSessions();
      
      // Remove existing session with same ID if exists
      sessions.removeWhere((existingSession) => existingSession.id == session.id);
      
      // Add the new/updated session
      sessions.add(session);
      
      return await _saveSessionsList(sessions);
    } catch (e) {
      print('Error saving try-on session: $e');
      return false;
    }
  }

  static Future<bool> _saveSessionsList(List<TryOnSession> sessions) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Newest first, then cap list size
      final sorted = [...sessions]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final trimmed = sorted.take(_maxSessionsToKeep).toList();

      List<Map<String, dynamic>> _toStorableJson(List<TryOnSession> list, {bool aggressive = false}) {
        return list.map((s) {
          final m = s.toJson();
          if (kIsWeb) {
            final result = m['result'];
            if (result is Map<String, dynamic>) {
              final path = (result['imagePath'] ?? '').toString();
              if (path.startsWith('data:')) {
                // Avoid persisting massive data URLs in localStorage
                result['imagePath'] = '';
              }
              final prompt = (result['prompt'] ?? '').toString();
              if (prompt.length > (aggressive ? 400 : 1200)) {
                result['prompt'] = prompt.substring(0, aggressive ? 400 : 1200);
              }
              m['result'] = result;
            }
          }
          return m;
        }).toList();
      }

      try {
        final jsonList = _toStorableJson(trimmed);
        return await prefs.setString(_tryOnKey, json.encode(jsonList));
      } catch (e) {
        print('Error saving sessions list: $e');
        // Retry with aggressive pruning
        try {
          final smaller = trimmed.take(3).toList();
          final jsonList = _toStorableJson(smaller, aggressive: true);
          return await prefs.setString(_tryOnKey, json.encode(jsonList));
        } catch (e2) {
          print('Error saving sessions list after pruning: $e2');
          // Last resort: remove key and reset to empty to recover
          try {
            await prefs.remove(_tryOnKey);
            return await prefs.setString(_tryOnKey, json.encode(<dynamic>[]));
          } catch (e3) {
            print('Final attempt to clear sessions failed: $e3');
            return false;
          }
        }
      }
    } catch (e) {
      print('Error saving sessions list: $e');
      return false;
    }
  }

  static String _generateSessionId() {
    return 'session_${DateTime.now().millisecondsSinceEpoch}';
  }

  static String _generateImageId() {
    return 'image_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Extracts a gender label from a multiline clothing description.
/// Assumes the 3rd non-empty line is exactly 'Gentleman' or 'Lady'.
/// Returns null if not found or ambiguous.
String? _extractGenderFromDescription(String? desc) {
  if (desc == null) return null;
  try {
    final lines = desc
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.length < 3) return null;
    final third = lines[2];
    final lower = third.toLowerCase();
    if (lower.contains('gentleman')) return 'Gentleman';
    if (lower.contains('lady')) return 'Lady';
    return null;
  } catch (_) {
    return null;
  }
}

/// Returns a user-friendly mismatch message if user and described genders conflict.
String? _getGenderMismatchMessage(String? userGender, String? describedGender) {
  if (userGender == null || describedGender == null) return null;
  // Normalize to canonical labels
  final u = _normalizeGender(userGender);
  final d = _normalizeGender(describedGender);
  if (u == 'Gentleman' && d == 'Lady') {
    return 'Seeems this outfit is for Ladies !';
  }
  if (u == 'Lady' && d == 'Gentleman') {
    return 'Seeems this outfit is for Gentlemen !';
  }
  return null;
}

/// Normalizes any user/description gender string into canonical 'Gentleman' or 'Lady'.
String _normalizeGender(String value) {
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
      // Try substring heuristics to be defensive
      if (v.contains('gentleman') || v.contains('male') || v.contains('men')) return 'Gentleman';
      if (v.contains('lady') || v.contains('female') || v.contains('women')) return 'Lady';
      return value.trim();
  }
}
