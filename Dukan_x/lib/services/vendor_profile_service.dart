// Vendor Profile Service
// Manages vendor profile data with Firestore sync and local caching
// Single source of truth for invoice generation
//
// Created: 2024-12-25
// Author: DukanX Team

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// Logo blobs now go through the S3-backed storage service, not Firebase.
import 'package:dukanx/core/service_registry/service_registry.dart';
import 'package:image_picker/image_picker.dart';
import '../models/vendor_profile.dart';
import 'session_service.dart';
import '../core/sync/sync_manager.dart';
import '../core/sync/sync_queue_state_machine.dart';

/// Global singleton for vendor profile service
final vendorProfileService = VendorProfileService._internal();

class VendorProfileService extends ChangeNotifier {
  static final VendorProfileService _instance =
      VendorProfileService._internal();
  factory VendorProfileService() => _instance;
  VendorProfileService._internal() : _syncManager = SyncManager.instance;

  final SyncManager _syncManager;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      debugPrint('VendorProfileService Error: $e');

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
      final profileDoc = await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('profile')
          .doc('main')
          .get();

      if (profileDoc.exists) {
        return VendorProfile.fromFirestore(profileDoc);
      }

      // Fallback: try to get from owners collection
      final ownerDoc = await _firestore
          .collection('owners')
          .doc(vendorId)
          .get();

      if (ownerDoc.exists) {
        return VendorProfile.fromFirestore(ownerDoc);
      }

      return null;
    } catch (e) {
      debugPrint('Firestore fetch error: $e');
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
      debugPrint('Background refresh failed: $e');
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
      // 1. Save to local cache FIRST — guarantees offline persistence
      _cachedProfile = profile;
      await _saveToCache(profile);
      _lastFetchTime = DateTime.now();

      // 2. Enqueue primary profile sync (offline-first via SyncManager)
      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: vendorId,
          operationType: SyncOperationType.update,
          targetCollection: 'vendors/$vendorId/profile',
          documentId: 'main',
          payload: profile.toFirestore(),
        ),
      );

      // 3. Enqueue backward-compatible owners collection update via SyncManager
      //    (was a direct Firestore call — the root cause of offline save failures)
      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: vendorId,
          operationType: SyncOperationType.update,
          targetCollection: 'owners',
          documentId: vendorId,
          payload: {
            'shopName': profile.shopName,
            'vendorName': profile.vendorName,
            'shopAddress': profile.shopAddress,
            'shopMobile': profile.shopMobile,
            'gstin': profile.gstin,
            'email': profile.email,
            'shopLogoUrl': profile.shopLogoUrl,
            'profileUpdatedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // 4. Save version history (non-blocking — must never fail the save)
      if (_cachedProfile != null && _cachedProfile!.version > 0) {
        _saveVersionHistory(vendorId, _cachedProfile!);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to save profile: $e';
      debugPrint('VendorProfileService Save Error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Save version history via SyncManager (non-blocking, fire-and-forget)
  void _saveVersionHistory(
    String vendorId,
    VendorProfile oldProfile,
  ) {
    // Fire-and-forget: enqueue to SyncManager instead of calling Firestore directly.
    // This ensures version history is recorded even when offline.
    () async {
      try {
        await _syncManager.enqueue(
          SyncQueueItem.create(
            userId: vendorId,
            operationType: SyncOperationType.create,
            targetCollection: 'vendors/$vendorId/profile_history',
            documentId: DateTime.now().millisecondsSinceEpoch.toString(),
            payload: ProfileHistoryEntry(
              version: oldProfile.version,
              timestamp: DateTime.now(),
              changes: oldProfile.toMap(),
              changedBy: vendorId,
            ).toMap(),
          ),
        );
      } catch (e) {
        debugPrint('Failed to enqueue version history: $e');
      }
    }();
  }

  /// Upload shop logo to S3 (presigned URL). Returns a stable storage *key*
  /// (not an expiring URL) to persist in [VendorProfile.shopLogoUrl].
  Future<String?> uploadShopLogo(XFile imageFile) async {
    final vendorId = _vendorId;
    if (vendorId == null) return null;

    try {
      _isLoading = true;
      notifyListeners();

      final bytes = await imageFile.readAsBytes();
      final key = 'vendors/$vendorId/logo.jpg';
      final storedKey = await Services.storage.upload(
        bytes,
        key,
        mimeType: 'image/jpeg',
        context: 'profile',
      );

      _isLoading = false;
      notifyListeners();
      return storedKey;
    } catch (e) {
      _error = 'Failed to upload logo: $e';
      debugPrint('Logo upload error: $e');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Resolves the stored logo value into a currently-displayable URL.
  /// Legacy full URLs are returned as-is; storage keys are resolved via S3.
  Future<String?> resolveLogoUrl(String? stored) async {
    if (stored == null || stored.isEmpty) return null;
    if (stored.startsWith('http://') || stored.startsWith('https://')) {
      return stored;
    }
    try {
      return await Services.storage.getUrl(stored);
    } catch (e) {
      debugPrint('Failed to resolve logo url: $e');
      return null;
    }
  }

  /// Get logo image bytes (for PDF generation).
  Future<Uint8List?> getLogoBytes() async {
    final stored = _cachedProfile?.shopLogoUrl;
    if (stored == null || stored.isEmpty) return null;

    try {
      if (stored.startsWith('http://') || stored.startsWith('https://')) {
        final res = await http.get(Uri.parse(stored));
        return res.statusCode == 200 ? res.bodyBytes : null;
      }
      return await Services.storage.download(stored);
    } catch (e) {
      debugPrint('Failed to get logo bytes: $e');
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
      debugPrint('Cache load error: $e');
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
      debugPrint('Cache save error: $e');
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
      debugPrint('Cache clear error: $e');
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

    return _firestore
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
      final snapshot = await _firestore
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
      debugPrint('Failed to get profile history: $e');
      return [];
    }
  }
}
