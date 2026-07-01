import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:dukanx/core/compat/firebase_auth_compat.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// Repository for User Profile and Auth-related Data
/// Extracted from FirestoreService
class AuthRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool get _isWeb => kIsWeb;

  Future<void> _ensureNetwork() async {
    try {
      await _db.enableNetwork().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('AuthRepository: enableNetwork warning: $e');
    }
  }

  /// CRITICAL: Ensure 'users' document exists for the authenticated user.
  /// Uses roleLocked to prevent accidental overwrites
  Future<Map<String, dynamic>> ensureUserDocument(
    User user, {
    required String role,
    String? name,
  }) async {
    final userData = {
      'uid': user.uid,
      'name': name ?? user.displayName ?? '',
      'email': user.email ?? '',
      'role': role,
      'roleLocked': true, // CRITICAL: Prevents role overwrite
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (_isWeb) {
      return _ensureUserDocumentWeb(user, userData);
    }
    return _ensureUserDocumentNative(user, userData);
  }

  Future<Map<String, dynamic>> _ensureUserDocumentWeb(
    User user,
    Map<String, dynamic> userData,
  ) async {
    final userRef = _db.collection('users').doc(user.uid);
    try {
      await _ensureNetwork();
      await Future.delayed(const Duration(milliseconds: 300));
      final snapshot = await userRef.get().timeout(const Duration(seconds: 5));
      if (snapshot.exists) return snapshot.data()!;
    } catch (e) {
      debugPrint('AuthRepository: Web Read failed: $e');
    }

    try {
      // Check if doc exists with role already set
      final existingDoc = await userRef.get().timeout(
        const Duration(seconds: 3),
      );
      if (existingDoc.exists && existingDoc.data()?['role'] != null) {
        return existingDoc.data()!;
      }

      // New doc or missing role - create/update
      await userRef
          .set(userData) // NO merge - atomic write
          .timeout(const Duration(seconds: 5));
      return _localUserData(userData);
    } catch (e) {
      debugPrint('AuthRepository: Web Write failed: $e');
    }

    return _localUserData(userData, pendingSync: true);
  }

  Future<Map<String, dynamic>> _ensureUserDocumentNative(
    User user,
    Map<String, dynamic> userData,
  ) async {
    await _ensureNetwork();
    await Future.delayed(const Duration(milliseconds: 500));
    final userRef = _db.collection('users').doc(user.uid);

    try {
      final cachedSnapshot = await userRef
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 3))
          .catchError((_) => userRef.get());
      if (cachedSnapshot.exists) return cachedSnapshot.data()!;
    } catch (_) {}

    try {
      final serverSnapshot = await userRef
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      if (serverSnapshot.exists) return serverSnapshot.data()!;
    } catch (_) {}

    int writeAttempts = 0;
    while (writeAttempts < 5) {
      writeAttempts++;
      try {
        await _ensureNetwork();
        await userRef
            .set(userData, SetOptions(merge: true))
            .timeout(const Duration(seconds: 15));
        return _localUserData(userData);
      } catch (e) {
        if (writeAttempts >= 5) {
          return _localUserData(
            userData,
            pendingSync: true,
            error: e.toString(),
          );
        }
        await Future.delayed(Duration(milliseconds: 1000 * writeAttempts));
      }
    }
    return _localUserData(userData, pendingSync: true);
  }

  Map<String, dynamic> _localUserData(
    Map<String, dynamic> userData, {
    bool pendingSync = false,
    String? error,
  }) {
    final localData = Map<String, dynamic>.from(userData);
    localData['createdAt'] = DateTime.now().toIso8601String();
    localData['updatedAt'] = DateTime.now().toIso8601String();
    if (pendingSync) localData['_pendingSync'] = true;
    if (error != null) localData['_error'] = error;
    return localData;
  }

  Future<Map<String, dynamic>?> getOwnerDetails(String id) async {
    try {
      final doc = await _db.collection('users').doc(id).get();
      if (doc.exists && doc.data()?['role'] == 'owner') return doc.data();
    } catch (_) {}

    try {
      final query = await _db
          .collection('users')
          .where('role', isEqualTo: 'owner')
          .where('shopId', isEqualTo: id)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) return query.docs.first.data();
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getOwnerProfile(String ownerId) async {
    try {
      final doc = await _db.collection('owners').doc(ownerId).get();
      if (doc.exists) return doc.data();
      final userDoc = await _db.collection('users').doc(ownerId).get();
      if (userDoc.exists) return userDoc.data();
    } catch (e) {
      debugPrint('Error fetching owner profile: $e');
    }
    return null;
  }

  Future<void> updateOwnerProfile(
    String ownerId,
    Map<String, dynamic> data,
  ) async {
    await _db
        .collection('owners')
        .doc(ownerId)
        .set(data, SetOptions(merge: true));
  }

  /// Create customer profile during signup
  /// This is called during customer registration to establish role
  /// WRITES TO BOTH: users/{uid} (role) AND customers/{uid} (profile)
  Future<void> createCustomerProfile({
    required String uid,
    required String name,
    required String phone,
    required String email,
  }) async {
    try {
      // CRITICAL: Write role to users collection FIRST (atomic, non-merge)
      final userRef = _db.collection('users').doc(uid);
      final existingDoc = await userRef.get();

      if (!existingDoc.exists || existingDoc.data()?['role'] == null) {
        await userRef.set({
          'uid': uid,
          'name': name,
          'email': email,
          'role': 'customer',
          'roleLocked': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }); // NO merge
        debugPrint('AuthRepository: User doc created with role: customer');
      }

      // Then write customer profile
      await _db.collection('customers').doc(uid).set({
        'name': name,
        'phone': phone,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'role': 'customer',
        'isActive': true,
      });
      debugPrint('AuthRepository: Customer profile created for $uid');
    } catch (e) {
      debugPrint('AuthRepository: Failed to create customer profile: $e');
      // Don't throw - the session will be refreshed and role determined from intent
    }
  }
}
