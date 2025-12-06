import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Generic Supabase configuration template
/// Replace YOUR_ and YOUR_ with your actual values
class SupabaseConfig {
  static const String supabaseUrl = 'https://nwstkzmtyqophnhxbpob.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im53c3Rrem10eXFvcGhuaHhicG9iIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2ODU5NTYsImV4cCI6MjA3OTI2MTk1Nn0.m-x6QQNFVEgrxboJkh9A0oUSzIeMl-NE50F0yVy1NLc';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: anonKey,
      debug: kDebugMode,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
}

/// Generic database service for CRUD operations
class SupabaseService {
  /// Select multiple records from a table
  static Future<List<Map<String, dynamic>>> select(
    String table, {
    String? select,
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).select(select ?? '*');

      // Apply filters
      if (filters != null) {
        for (final entry in filters.entries) {
          query = query.eq(entry.key, entry.value);
        }
      }

      // Apply ordering
      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      }

      // Apply limit
      if (limit != null) {
        query = query.limit(limit);
      }

      return await query;
    } catch (e) {
      throw _handleDatabaseError('select', table, e);
    }
  }

  /// Select a single record from a table
  static Future<Map<String, dynamic>?> selectSingle(
    String table, {
    String? select,
    required Map<String, dynamic> filters,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).select(select ?? '*');

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      return await query.maybeSingle();
    } catch (e) {
      throw _handleDatabaseError('selectSingle', table, e);
    }
  }

  /// Insert a record into a table
  static Future<List<Map<String, dynamic>>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    try {
      return await SupabaseConfig.client.from(table).insert(data).select();
    } catch (e) {
      throw _handleDatabaseError('insert', table, e);
    }
  }

  /// Insert multiple records into a table
  static Future<List<Map<String, dynamic>>> insertMultiple(
    String table,
    List<Map<String, dynamic>> data,
  ) async {
    try {
      return await SupabaseConfig.client.from(table).insert(data).select();
    } catch (e) {
      throw _handleDatabaseError('insertMultiple', table, e);
    }
  }

  /// Update records in a table
  static Future<List<Map<String, dynamic>>> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> filters,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).update(data);

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      return await query.select();
    } catch (e) {
      throw _handleDatabaseError('update', table, e);
    }
  }

  /// Delete records from a table
  static Future<void> delete(
    String table, {
    required Map<String, dynamic> filters,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).delete();

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      await query;
    } catch (e) {
      throw _handleDatabaseError('delete', table, e);
    }
  }

  /// Get direct table reference for complex queries
  static SupabaseQueryBuilder from(String table) =>
      SupabaseConfig.client.from(table);

  /// Handle database errors
  static String _handleDatabaseError(
    String operation,
    String table,
    dynamic error,
  ) {
    if (error is PostgrestException) {
      return 'Failed to $operation from $table: ${error.message}';
    } else {
      return 'Failed to $operation from $table: ${error.toString()}';
    }
  }
}

/// Helper extension for User table operations
class SupabaseUserService {
  static const String tableName = 'users';

  static Future<Map<String, dynamic>?> getUserById(String userId) async {
    return await SupabaseService.selectSingle(
      tableName,
      filters: {'id': userId},
    );
  }

  static Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    return await SupabaseService.selectSingle(
      tableName,
      filters: {'email': email},
    );
  }

  static Future<List<Map<String, dynamic>>> createUser(Map<String, dynamic> userData) async {
    return await SupabaseService.insert(tableName, userData);
  }

  static Future<List<Map<String, dynamic>>> updateUser(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    return await SupabaseService.update(
      tableName,
      updates,
      filters: {'id': userId},
    );
  }
}

/// Helper extension for ClothingItem table operations
class SupabaseClothingService {
  static const String tableName = 'clothing_items';

  static Future<List<Map<String, dynamic>>> getAllClothingItems({
    String? userId,
    int? limit,
  }) async {
    return await SupabaseService.select(
      tableName,
      filters: userId != null ? {'userId': userId} : null,
      orderBy: 'createdAt',
      ascending: false,
      limit: limit,
    );
  }

  static Future<Map<String, dynamic>?> getClothingItemById(String itemId) async {
    return await SupabaseService.selectSingle(
      tableName,
      filters: {'id': itemId},
    );
  }

  static Future<List<Map<String, dynamic>>> createClothingItem(
    Map<String, dynamic> itemData,
  ) async {
    return await SupabaseService.insert(tableName, itemData);
  }

  static Future<List<Map<String, dynamic>>> updateClothingItem(
    String itemId,
    Map<String, dynamic> updates,
  ) async {
    return await SupabaseService.update(
      tableName,
      updates,
      filters: {'id': itemId},
    );
  }

  static Future<void> deleteClothingItem(String itemId) async {
    await SupabaseService.delete(tableName, filters: {'id': itemId});
  }
}

/// Helper extension for TryOnSession table operations
class SupabaseTryOnService {
  static const String tableName = 'tryon_sessions';

  static Future<List<Map<String, dynamic>>> getUserSessions({
    required String userId,
    int? limit,
  }) async {
    return await SupabaseService.select(
      tableName,
      filters: {'userId': userId},
      orderBy: 'createdAt',
      ascending: false,
      limit: limit,
    );
  }

  static Future<Map<String, dynamic>?> getSessionById(String sessionId) async {
    return await SupabaseService.selectSingle(
      tableName,
      filters: {'id': sessionId},
    );
  }

  static Future<List<Map<String, dynamic>>> createSession(
    Map<String, dynamic> sessionData,
  ) async {
    return await SupabaseService.insert(tableName, sessionData);
  }

  static Future<List<Map<String, dynamic>>> updateSession(
    String sessionId,
    Map<String, dynamic> updates,
  ) async {
    return await SupabaseService.update(
      tableName,
      updates,
      filters: {'id': sessionId},
    );
  }

  static Future<void> deleteSession(String sessionId) async {
    await SupabaseService.delete(tableName, filters: {'id': sessionId});
  }

  /// Get completed sessions for a user
  static Future<List<Map<String, dynamic>>> getCompletedSessions({
    required String userId,
    int? limit,
  }) async {
    try {
      dynamic query = SupabaseConfig.client
          .from(tableName)
          .select()
          .eq('userId', userId)
          .eq('status', 'completed')
          .order('createdAt', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      return await query;
    } catch (e) {
      debugPrint('Error fetching completed sessions: $e');
      rethrow;
    }
  }
}

/// Helper extension for GeneratedImage table operations
class SupabaseGeneratedImageService {
  static const String tableName = 'generated_images';

  static Future<List<Map<String, dynamic>>> getAllImages({
    String? userId,
    int? limit,
  }) async {
    return await SupabaseService.select(
      tableName,
      filters: userId != null ? {'userId': userId} : null,
      orderBy: 'createdAt',
      ascending: false,
      limit: limit,
    );
  }

  static Future<Map<String, dynamic>?> getImageById(String imageId) async {
    return await SupabaseService.selectSingle(
      tableName,
      filters: {'id': imageId},
    );
  }

  static Future<List<Map<String, dynamic>>> createImage(
    Map<String, dynamic> imageData,
  ) async {
    return await SupabaseService.insert(tableName, imageData);
  }

  static Future<void> deleteImage(String imageId) async {
    await SupabaseService.delete(tableName, filters: {'id': imageId});
  }
}
