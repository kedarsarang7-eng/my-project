// Vendor Profile Service
// Manages vendor profile data with Firestore sync and local caching
// Single source of truth for invoice generation
//
// Created: 2024-12-25
// Author: DukanX Team

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:dukanx/core/api/api_client.dart';
import 'package:dukanx/core/di/service_locator.dart' hide sessionService;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../models/vendor_profile.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/sync/sync_manager.dart';
import '../../../../core/sync/sync_queue_state_machine.dart';

/// Global singleton for vendor profile service
final vendorProfileService = VendorProfileService._internal();

class VendorProfileService extends ChangeNotifier {
  static final VendorProfileService _instance =
      VendorProfileService._internal();
  factory VendorProfileService() => _instance;
  VendorProfileService._internal() : _syncManager = SyncManager.instance;

  final SyncManager _syncManager;

  // These are only safe to use on non-web platforms after Firebase init
  ApiClient get _api => sl<ApiClient>();
  FirebaseStorage get _storage => FirebaseStorage.instance;

  // Cache keys
  static const String _profileCacheKey = 'vendor_profile_cache';
  static const String _profileTimestampKey = 'vendor_profile_timestamp';

  // Cache duration (5 minutes for fresh data check)
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Cached profile
  VendorProfile? _cachedProfile;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetchTime;

  // Getters
  VendorProfile? get profile => _cachedProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasProfile => _cachedProfile != null && _cachedProfile!.isComplete;

  /// Get current vendor ID
  String? get _vendorId => sessionService.getOwnerDocId();

  /// Initialize and load profile
  Future<void> init() async {
    if (_vendorId == null) return;
    await loadProfile();
  }

  /// Load profile from cache first, then sync with Firestore
  Future<VendorProfile?> loadProfile({bool forceRefresh = false}) async {
    final vendorId = _vendorId;
    if (vendorId == null) {
      _error = 'No vendor logged in';
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try to load from local cache first (for offline support)
      if (!forceRefresh) {
        final cachedProfile = await _loadFromCache();
        if (cachedProfile != null) {
          _cachedProfile = cachedProfile;
          notifyListeners();

          // Check if cache is stale and refresh in background
          if (_isCacheStale()) {
            _refreshFromFirestore(vendorId);
          }
          return cachedProfile;
        }
      }

      // Load from Firestore
      final profile = await _fetchFromFirestore(vendorId);
      if (profile != null) {
        _cachedProfile = profile;
        await _saveToCache(profile);
      } else {
        // Create empty profile if none exists
        _cachedProfile = VendorProfile.empty(vendorId);
      }

      _lastFetchTime = DateTime.now();
      _isLoading = false;
      notifyListeners();
      return _cachedProfile;
    } catch (e) {
      _error = 'Failed to load profile: $e';
      LoggerService.d('VendorProfile', 'VendorProfileService Error: $e');

      // Try to use cached data on error
      final cachedProfile = await _loadFromCache();
      if (cachedProfile != null) {
        _cachedProfile = cachedProfile;
      }

      _isLoading = false;
      notifyListeners();
      return _cachedProfile;
    }
  }

  /// Fetch profile from Firestore
  Future<VendorProfile?> _fetchFromFirestore(String vendorId) async {
    try {
      // Try new profile collection first
      final profileDoc = await _api
          .collection('vendors')
          .doc(vendorId)
          .collection('profile')
          .doc('main')
          .get();

      if (profileDoc.exists) {
        return VendorProfile.fromFirestore(profileDoc);
      }

      // Fallback: try to get from owners collection
      final ownerDoc = await _api
          .collection('owners')
          .doc(vendorId)
          .get();

      if (ownerDoc.exists) {
        return VendorProfile.fromFirestore(ownerDoc);
      }

      return null;
    } catch (e) {
      LoggerService.d('VendorProfile', 'Firestore fetch error: $e');
      rethrow;
    }
  }

  /// Refresh profile from Firestore in background
  Future<void> _refreshFromFirestore(String vendorId) async {
    try {
      final profile = await _fetchFromFirestore(vendorId);
      if (profile != null) {
        _cachedProfile = profile;
        await _saveToCache(profile);
        _lastFetchTime = DateTime.now();
        notifyListeners();
      }
    } catch (e) {
      LoggerService.d('VendorProfile', 'Background refresh failed: $e');
    }
  }

  /// Save profile to Firestore and local cache
  Future<bool> saveProfile(VendorProfile profile) async {
    final vendorId = _vendorId;
    if (vendorId == null) {
      _error = 'No vendor logged in';
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Save version history before update
      if (_cachedProfile != null && _cachedProfile!.version > 0) {
        await _saveVersionHistory(vendorId, _cachedProfile!);
      }

      // Save to Firestore (new structure)
      // Save to Firestore (new structure)
      // REFACTORED: Use SyncManager for Offline-First Support
      /*
      await _api
          .collection('vendors')
          .doc(vendorId)
          .collection('profile')
          .doc('main')
          .set(profile.toFirestore(), SetOptions(merge: true));
      */

      // Enqueue sync operation
      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: vendorId,
          operationType: SyncOperationType.update,
          targetCollection:
              'vendors/$vendorId/profile', // Special path handling might be needed in SyncManager, or standard collection/doc
          // Standard SyncManager expects collection and documentId.
          // If collection is nested 'vendors/{id}/profile', we should pass that.
          // Let's assume SyncManager handles path-like collections or we pass 'profile' and rely on implicit vendorId hierarchy?
          // Based on SyncManager implementation, it constructs path: collection(targetCollection).doc(documentId).
          // So targetCollection should be 'vendors/$vendorId/profile'.
          documentId: 'main',
          payload: profile.toFirestore(),
        ),
      );

      // Also update owners collection for backward compatibility
      await _api.collection('owners').doc(vendorId).set({
        'shopName': profile.shopName,
        'vendorName': profile.vendorName,
        'shopAddress': profile.shopAddress,
        'shopMobile': profile.shopMobile,
        'gstin': profile.gstin,
        'email': profile.email,
        'shopLogoUrl': profile.shopLogoUrl,
        'profileUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update local cache
      _cachedProfile = profile;
      await _saveToCache(profile);
      _lastFetchTime = DateTime.now();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to save profile: $e';
      LoggerService.d('VendorProfile', 'VendorProfileService Save Error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Save version history
  Future<void> _saveVersionHistory(
    String vendorId,
    VendorProfile oldProfile,
  ) async {
    try {
      await _api
          .collection('vendors')
          .doc(vendorId)
          .collection('profile_history')
          .add(
            ProfileHistoryEntry(
              version: oldProfile.version,
              timestamp: DateTime.now(),
              changes: oldProfile.toMap(),
              changedBy: vendorId,
            ).toMap(),
          );
    } catch (e) {
      LoggerService.d('VendorProfile', 'Failed to save version history: $e');
    }
  }

  /// Upload shop logo
  Future<String?> uploadShopLogo(XFile imageFile) async {
    final vendorId = _vendorId;
    if (vendorId == null) return null;

    // Firebase Storage upload not supported on web in this configuration
    if (kIsWeb) {
      LoggerService.d('VendorProfile', 'VendorProfileService: Logo upload skipped on web');
      return null;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final bytes = await imageFile.readAsBytes();
      final fileName = 'shop_logo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('vendors/$vendorId/logos/$fileName');

      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

      final downloadUrl = await ref.getDownloadURL();

      _isLoading = false;
      notifyListeners();
      return downloadUrl;
    } catch (e) {
      _error = 'Failed to upload logo: $e';
      LoggerService.d('VendorProfile', 'Logo upload error: $e');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Get logo image bytes (for PDF generation)
  Future<Uint8List?> getLogoBytes() async {
    if (_cachedProfile?.shopLogoUrl == null) return null;

    try {
      final ref = _storage.refFromURL(_cachedProfile!.shopLogoUrl!);
      return await ref.getData(10 * 1024 * 1024); // 10MB max
    } catch (e) {
      LoggerService.d('VendorProfile', 'Failed to get logo bytes: $e');
      return null;
    }
  }

  /// Load from local cache
  Future<VendorProfile?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_profileCacheKey);
      if (jsonString == null) return null;

      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      return VendorProfile.fromMap(map);
    } catch (e) {
      LoggerService.d('VendorProfile', 'Cache load error: $e');
      return null;
    }
  }

  /// Save to local cache
  Future<void> _saveToCache(VendorProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profileCacheKey, jsonEncode(profile.toMap()));
      await prefs.setString(
        _profileTimestampKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      LoggerService.d('VendorProfile', 'Cache save error: $e');
    }
  }

  /// Check if cache is stale
  bool _isCacheStale() {
    if (_lastFetchTime == null) return true;
    return DateTime.now().difference(_lastFetchTime!) > _cacheDuration;
  }

  /// Clear cache
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profileCacheKey);
      await prefs.remove(_profileTimestampKey);
      _cachedProfile = null;
      _lastFetchTime = null;
      notifyListeners();
    } catch (e) {
      LoggerService.d('VendorProfile', 'Cache clear error: $e');
    }
  }

  /// Get profile for invoice generation (real-time fetch)
  /// This ensures invoices always use the latest profile data
  Future<VendorProfile?> getProfileForInvoice() async {
    // Force refresh for invoice to ensure latest data
    return await loadProfile(forceRefresh: true);
  }

  /// Stream profile changes for real-time updates
  Stream<VendorProfile?> streamProfile() {
    final vendorId = _vendorId;
    if (vendorId == null) {
      return Stream.value(null);
    }

    return _api
        .collection('vendors')
        .doc(vendorId)
        .collection('profile')
        .doc('main')
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            final profile = VendorProfile.fromFirestore(doc);
            _cachedProfile = profile;
            _saveToCache(profile); // Update cache
            return profile;
          }
          return null;
        });
  }

  /// Get profile history (version history)
  Future<List<ProfileHistoryEntry>> getProfileHistory() async {
    final vendorId = _vendorId;
    if (vendorId == null) return [];

    try {
      final snapshot = await _api
          .collection('vendors')
          .doc(vendorId)
          .collection('profile_history')
          .orderBy('version', descending: true)
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => ProfileHistoryEntry.fromMap(doc.data()))
          .toList();
    } catch (e) {
      LoggerService.d('VendorProfile', 'Failed to get profile history: $e');
      return [];
    }
  }
}
