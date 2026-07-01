import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dukanx/features/avatar/domain/models/avatar_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repository for managing avatar data persistence and retrieval.
/// Uses SharedPreferences for simple offline persistence (MVP).
/// NOTE: SharedPreferences is intentional for simplicity. Drift migration
/// deferred as avatar data is non-critical and doesn't need sync.
class AvatarRepository {
  // ignore: unused_field
  final dynamic _db; // Placeholder for future Drift DB injection

  AvatarRepository(this._db);

  static const String _storageKeyPrefix = 'user_avatar_';

  /// Saves the avatar data for the given user.
  Future<void> saveAvatar(String userId, AvatarData data) async {
    try {
      final jsonString = jsonEncode(data.toJson());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_storageKeyPrefix$userId', jsonString);

      debugPrint('AvatarRepository: Saved avatar for $userId (SharedPrefs)');
    } catch (e) {
      debugPrint('AvatarRepository: Error saving avatar: $e');
      rethrow;
    }
  }

  /// Retrieves the avatar data for the given user.
  /// Returns null if no avatar is set.
  Future<AvatarData?> getAvatar(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('$_storageKeyPrefix$userId');

      if (jsonString != null) {
        final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
        return AvatarData.fromJson(jsonMap);
      }
      return null;
    } catch (e) {
      debugPrint('AvatarRepository: Error retrieving avatar: $e');
      return null;
    }
  }

  /// Watches the avatar data stream for real-time updates.
  /// Not fully implemented for SharedPrefs, returns a single future as stream.
  Stream<AvatarData?> watchAvatar(String userId) async* {
    final avatar = await getAvatar(userId);
    yield avatar;
  }
}
