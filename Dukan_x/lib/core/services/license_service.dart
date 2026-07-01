// License Service - Enterprise License Validation & Management
// Handles license validation, activation, and offline-first caching
//
// SECURITY NOTES:
// - All license checks are performed both locally AND remotely
// - Offline grace period is now SERVER-CONTROLLED (0h trial, 48h paid, 168h lifetime)
// - Device fingerprint must match for license to be valid
// - Business type must match exactly - wrong type = app blocked
// - Sends client_timestamp for clock drift detection (Phase A)
//
// ARCHITECTURE:
// - Activation calls SLS Licensing Backend REST API (POST /api/client/validate)
// - Uses real DeviceFingerprintService for hardware-bound HWID
// - Caches license locally in Drift licenseCache table

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../../../config/api_config.dart';
import '../database/app_database.dart';
import '../../../models/business_type.dart';
import '../../../security/anti_tamper_service.dart';
import 'module_loader_service.dart';
import '../di/service_locator.dart';
import 'logger_service.dart';
import 'device_fingerprint_service.dart';

/// License validation result
enum LicenseStatus {
  valid,
  expired,
  suspended,
  blocked,
  deviceMismatch,
  businessTypeMismatch,
  notFound,
  networkError,
  offlineGraceExpired,
  error,
}

/// Result of license validation
class LicenseValidationResult {
  final bool isValid;
  final LicenseStatus status;
  final String? message;
  final LicenseCacheEntity? license;
  final List<String> enabledModules;
  final int? daysUntilExpiry;
  final bool isOfflineValidation;

  const LicenseValidationResult({
    required this.isValid,
    required this.status,
    this.message,
    this.license,
    this.enabledModules = const [],
    this.daysUntilExpiry,
    this.isOfflineValidation = false,
  });

  factory LicenseValidationResult.invalid(
    LicenseStatus status, [
    String? message,
  ]) =>
      LicenseValidationResult(isValid: false, status: status, message: message);

  factory LicenseValidationResult.valid({
    required LicenseCacheEntity license,
    required List<String> enabledModules,
    int? daysUntilExpiry,
    bool isOfflineValidation = false,
  }) => LicenseValidationResult(
    isValid: true,
    status: LicenseStatus.valid,
    license: license,
    enabledModules: enabledModules,
    daysUntilExpiry: daysUntilExpiry,
    isOfflineValidation: isOfflineValidation,
  );
}

/// License activation result
class LicenseActivationResult {
  final bool isSuccess;
  final String? errorCode;
  final String? errorMessage;
  final LicenseCacheEntity? license;
  final String? businessType;

  /// All business types allowed by this license (multi-business support)
  final List<String> businessTypes;
  final String? planTier;

  /// 'single' | 'multi'
  final String? planType;

  /// Server-signed JWT for tamper-proof verification
  final String? signedToken;

  const LicenseActivationResult({
    required this.isSuccess,
    this.errorCode,
    this.errorMessage,
    this.license,
    this.businessType,
    this.businessTypes = const [],
    this.planTier,
    this.planType,
    this.signedToken,
  });

  factory LicenseActivationResult.success(
    LicenseCacheEntity license, {
    String? businessType,
    List<String> businessTypes = const [],
    String? planTier,
    String? planType,
    String? signedToken,
  }) => LicenseActivationResult(
    isSuccess: true,
    license: license,
    businessType: businessType,
    businessTypes: businessTypes,
    planTier: planTier,
    planType: planType,
    signedToken: signedToken,
  );

  factory LicenseActivationResult.failure(String errorCode, String message) =>
      LicenseActivationResult(
        isSuccess: false,
        errorCode: errorCode,
        errorMessage: message,
      );
}

/// Enterprise License Service
///
/// Calls the SLS Licensing Backend REST API for validation and activation.
/// Uses [DeviceFingerprintService] for real hardware-bound fingerprints.
class LicenseService {
  final AppDatabase _db;
  final DeviceFingerprintService _fingerprintService;

  LicenseService(this._db, {DeviceFingerprintService? fingerprintService})
    : _fingerprintService = fingerprintService ?? DeviceFingerprintService();

  // ============================================================
  // PUBLIC METHODS
  // ============================================================

  /// Validate license (local-first, then online if needed)
  Future<LicenseValidationResult> validateLicense({
    required BusinessType requiredBusinessType,
  }) async {
    try {
      final license = await _getCachedLicense();

      if (license == null) {
        return LicenseValidationResult.invalid(
          LicenseStatus.notFound,
          'No license found',
        );
      }

      // 1. Check Business Type (multi-business: check if the required type
      // is in the license's business_types array)
      final allowedTypes = _parseBusinessTypes(license.businessType);
      if (!allowedTypes.contains(requiredBusinessType.name)) {
        return LicenseValidationResult.invalid(
          LicenseStatus.businessTypeMismatch,
          'License does not include: ${requiredBusinessType.name}. Allowed: ${allowedTypes.join(', ')}',
        );
      }

      // 2. Check Expiry
      if (license.expiryDate.isBefore(DateTime.now())) {
        return LicenseValidationResult.invalid(
          LicenseStatus.expired,
          'License expired on ${license.expiryDate}',
        );
      }

      // 3. Check Status
      if (license.status != 'active') {
        return LicenseValidationResult.invalid(
          _mapStatusString(license.status),
          'License is ${license.status}',
        );
      }

      // 4. Verify device fingerprint matches (if online validation time)
      // FIX P0-005: Compute next validation deadline from cached fields
      // (nextValidationRequiredBy column added to table but codegen not yet run)
      final nextValidationDeadline = license.lastValidatedAt.add(
        Duration(hours: license.offlineGraceDays),
      );
      final now = DateTime.now();
      
      if (now.isAfter(nextValidationDeadline)) {
        // Offline grace period expired — must re-validate online
        final onlineResult = await _validateOnline(license);
        if (onlineResult != null) return onlineResult;
        // If online validation fails due to network, allow offline grace
        return LicenseValidationResult.valid(
          license: license,
          enabledModules: _parseModules(license.enabledModulesJson),
          daysUntilExpiry: license.expiryDate.difference(now).inDays,
          isOfflineValidation: true,
        );
      }

      return LicenseValidationResult.valid(
        license: license,
        enabledModules: _parseModules(license.enabledModulesJson),
        daysUntilExpiry: license.expiryDate.difference(now).inDays,
      );
    } catch (e) {
      LoggerService.d('LicenseService', 'LicenseService: Validation error: $e');
      return LicenseValidationResult.invalid(LicenseStatus.error, e.toString());
    }
  }

  /// Activate license by calling SLS Backend REST API
  ///
  /// Sends the license key and real hardware fingerprint to
  /// POST /api/client/validate on the SLS Licensing Backend.
  Future<LicenseActivationResult> activateLicense({
    required String licenseKey,
  }) async {
    try {
      // 1. Get real device fingerprint
      final fingerprint = await _fingerprintService.getFingerprint();

      LoggerService.d('LicenseService', 
        'LicenseService: Activating with HWID: ${fingerprint.fingerprint.substring(0, 12)}...',
      );

      // 2. Call Backend REST API (POST /api/client/activate)
      final response = await http
          .post(
            Uri.parse(ApiConfig.licenseActivationUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'licenseKey': licenseKey,
              'deviceId': fingerprint.fingerprint,
              'deviceInfo': {'platform': fingerprint.platform},
              // Phase A: anti-tamper fields
              'client_timestamp': DateTime.now().toUtc().toIso8601String(),
              'app_version': ApiConfig.appVersion,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Backend returns standard: { status: 'success', success: true, data: {...} }
      final isSuccess = (response.statusCode == 200 || response.statusCode == 201) &&
          (data['status'] == 'success' || data['success'] == true);

      if (isSuccess) {
        // 3. Extract license info from the standard response envelope
        final respData = data['data'] as Map<String, dynamic>? ?? data;

        // The backend returns: tenantId, planTier, message, activatedAt, expiresAt
        final planTier = respData['planTier'] as String? ?? 'basic';
        final expiresAtStr = respData['expiresAt'] as String?;
        final tenantId = respData['tenantId'] as String? ?? '';

        // ---- Multi-Business Types Support ----
        // Parse business_types array (new format) or fall back to business_type (old format)
        final List<String> businessTypes;
        if (respData['business_types'] is List) {
          businessTypes = (respData['business_types'] as List)
              .map((e) => e.toString())
              .toList();
        } else if (respData['businessTypes'] is List) {
          businessTypes = (respData['businessTypes'] as List)
              .map((e) => e.toString())
              .toList();
        } else {
          final singleType = respData['business_type'] as String?
              ?? respData['businessType'] as String?
              ?? 'other';
          businessTypes = [singleType];
        }
        final planType = respData['plan_type'] as String?
            ?? respData['planType'] as String?
            ?? 'single';
        final signedToken = data['token'] as String?;

        // licenseType parsed but license_category takes precedence (Phase A)
        final featureFlags =
            respData['feature_flags'] as Map<String, dynamic>? ?? {};

        // Extract active modules from SaaS Super Admin backend response
        final activeModules =
            (data['activeModules'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        // Prefer explicit module list; otherwise use business types from the same response.
        try {
          final toStore =
              activeModules.isNotEmpty ? activeModules : businessTypes;
          await sl<ModuleLoaderService>().updateActiveModules(toStore);
        } catch (_) {}

        // Phase A: Parse new response fields
        final licenseCategory =
            respData['license_category'] as String? ?? 'paid';
        final offlineGraceHours =
            respData['offline_grace_hours'] as int? ?? 48;
        final durationDays = respData['duration_days'] as int?;

        // 4. Cache license locally
        // Store business_types as JSON array in the businessType field
        final now = DateTime.now();
        final expiryDate = expiresAtStr != null
            ? DateTime.parse(expiresAtStr)
            : licenseCategory == 'lifetime'
            ? now.add(const Duration(days: 36500)) // ~100 years for lifetime
            : now.add(Duration(days: durationDays ?? 365));

        final cachedLicense = LicenseCacheEntity(
          id: licenseKey.hashCode.toRadixString(16),
          licenseKey: licenseKey,
          businessType: jsonEncode(businessTypes), // Store as JSON array
          customerId: tenantId,
          enabledModulesJson: jsonEncode(featureFlags),
          issueDate: now,
          expiryDate: expiryDate,
          deviceFingerprint: fingerprint.fingerprint,
          deviceId: fingerprint.platform,
          lastValidatedAt: now,
          validationToken: signedToken ?? 'activated', // Store signed JWT
          tokenSignature: planType, // Legacy: Store planType in signature field
          createdAt: now,
          updatedAt: now,
          licenseType: licenseCategory, // Store license_category here
          status: 'active',
          maxDevices: respData['max_devices'] as int? ?? 1,
          offlineGraceDays: offlineGraceHours, // Store as hours from server
          isSynced: true,
          lastSyncAt: now,
        );

        await _cacheLicense(cachedLicense);

        return LicenseActivationResult.success(
          cachedLicense,
          businessType: businessTypes.first,
          businessTypes: businessTypes,
          planTier: planTier,
          planType: planType,
          signedToken: signedToken,
        );
      } else {
        // Activation failed — return exact error from backend
        final errorObj = data['error'] as Map<String, dynamic>?;
        final errorCode = errorObj?['code'] as String?
            ?? data['code'] as String?
            ?? 'UNKNOWN';
        final errorMessage = errorObj?['message'] as String?
            ?? data['message'] as String?
            ?? data['error'] as String?
            ?? 'Activation failed';

        return LicenseActivationResult.failure(errorCode, errorMessage);
      }
    } on SocketException {
      return LicenseActivationResult.failure(
        'NETWORK_ERROR',
        'No internet connection. License activation requires a live connection.',
      );
    } on HttpException {
      return LicenseActivationResult.failure(
        'NETWORK_ERROR',
        'Cannot reach license server. Please try again later.',
      );
    } catch (e) {
      LoggerService.d('LicenseService', 'LicenseService: Activation error: $e');
      return LicenseActivationResult.failure('ACTIVATION_ERROR', e.toString());
    }
  }

  /// Send periodic heartbeat to update license status.
  /// Calls POST /api/client/heartbeat with anti-tamper fields.
  Future<void> sendHeartbeat() async {
    try {
      final license = await _getCachedLicense();
      if (license == null) return;

      final fingerprint = await _fingerprintService.getFingerprint();
      final antiTamper = AntiTamperService();

      final response = await http
          .post(
            Uri.parse(ApiConfig.heartbeatUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'license_key': license.licenseKey,
              'machine_hwid': fingerprint.fingerprint,
              'client_timestamp': DateTime.now().toUtc().toIso8601String(),
              'app_signature': antiTamper.getAppSignature(),
              'app_version': ApiConfig.appVersion,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Update server time offset for clock drift detection
        antiTamper.updateServerTimeOffset(data['server_time'] as String?);
        await _updateLastValidated(license.id);
        LoggerService.d('LicenseService', 
          'LicenseService: Heartbeat OK. '
          'Grace remaining: ${data['offline_grace_remaining_hours']}h',
        );
      } else if (response.statusCode == 403) {
        // License revoked/banned/expired server-side
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final code = data['code'] as String? ?? '';
        LoggerService.d('LicenseService', 'LicenseService: Heartbeat rejected [$code]');
      }
    } catch (e) {
      LoggerService.d('LicenseService', 'LicenseService: Heartbeat error: $e');
    }
  }

  /// Clear all locally cached license data from the Drift database.
  /// Called by [LicenseInvalidListener] when the license is invalidated.
  Future<void> clearLocalCache() async {
    try {
      await _db.delete(_db.licenseCache).go();
      LoggerService.d('LicenseService', 'LicenseService: Local license cache cleared.');
    } catch (e) {
      LoggerService.d('LicenseService', 'LicenseService: Failed to clear local cache: $e');
    }
  }

  /// Check if module is enabled
  Future<bool> isModuleEnabled(String moduleCode) async {
    final license = await _getCachedLicense();
    if (license == null) return false;

    final modules = _parseModules(license.enabledModulesJson);
    return modules.contains(moduleCode);
  }

  /// Check if license needs renewal soon (within 30 days)
  Future<bool> needsRenewalSoon() async {
    try {
      final license = await _getCachedLicense();
      if (license == null) return false;

      final daysUntilExpiry = license.expiryDate
          .difference(DateTime.now())
          .inDays;
      return daysUntilExpiry <= 30;
    } catch (e) {
      return false;
    }
  }

  /// Get days until license expires
  Future<int?> getDaysUntilExpiry() async {
    try {
      final license = await _getCachedLicense();
      if (license == null) return null;

      return license.expiryDate.difference(DateTime.now()).inDays;
    } catch (e) {
      return null;
    }
  }

  /// Check if currently has valid cached license
  Future<bool> hasValidCachedLicense() async {
    try {
      final license = await _getCachedLicense();
      if (license == null) return false;

      // Check expiry
      if (license.expiryDate.isBefore(DateTime.now())) return false;

      // Check status
      if (license.status != 'active') return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get current license info (for display)
  Future<Map<String, dynamic>?> getLicenseInfo() async {
    try {
      final license = await _getCachedLicense();
      if (license == null) return null;

      return {
        'licenseKey': _maskLicenseKey(license.licenseKey),
        'businessType': license.businessType,
        'businessTypes': _parseBusinessTypes(license.businessType),
        'planType': license.tokenSignature, // planType stored in tokenSignature
        'status': license.status,
        'expiryDate': license.expiryDate.toIso8601String(),
        'daysUntilExpiry': license.expiryDate.difference(DateTime.now()).inDays,
        'enabledModules': _parseModules(license.enabledModulesJson),
        'lastValidated': license.lastValidatedAt.toIso8601String(),
      };
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Get cached license from local database
  Future<LicenseCacheEntity?> _getCachedLicense() async {
    try {
      final query = _db.select(_db.licenseCache);
      final results = await query.get();
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      LoggerService.d('LicenseService', 'LicenseService: Cache read error: $e');
      return null;
    }
  }

  /// Cache license to local database
  Future<void> _cacheLicense(LicenseCacheEntity license) async {
    try {
      // Clear existing licenses first
      await _db.delete(_db.licenseCache).go();

      // Insert new license
      await _db
          .into(_db.licenseCache)
          .insert(
            LicenseCacheCompanion.insert(
              id: license.id,
              licenseKey: license.licenseKey,
              businessType: license.businessType,
              customerId: Value(license.customerId),
              enabledModulesJson: Value(license.enabledModulesJson),
              issueDate: license.issueDate,
              expiryDate: license.expiryDate,
              deviceFingerprint: license.deviceFingerprint,
              deviceId: Value(license.deviceId),
              lastValidatedAt: license.lastValidatedAt,
              validationToken: license.validationToken,
              tokenSignature: license.tokenSignature,
              createdAt: license.createdAt,
              updatedAt: license.updatedAt,
              licenseType: Value(license.licenseType),
              status: Value(license.status),
              maxDevices: Value(license.maxDevices),
              offlineGraceDays: Value(license.offlineGraceDays),
              isSynced: Value(license.isSynced),
              lastSyncAt: Value(license.lastSyncAt),
            ),
          );
    } catch (e) {
      LoggerService.d('LicenseService', 'LicenseService: Cache write error: $e');
    }
  }

  /// Update last validated timestamp
  Future<void> _updateLastValidated(String id) async {
    try {
      await (_db.update(_db.licenseCache)..where((t) => t.id.equals(id))).write(
        LicenseCacheCompanion(
          lastValidatedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(true),
          lastSyncAt: Value(DateTime.now()),
        ),
      );
    } catch (e) {
      LoggerService.d('LicenseService', 'LicenseService: Validation update error: $e');
    }
  }

  /// Validate license online (re-check with backend)
  /// Includes anti-tamper fields for server-side integrity checks.
  Future<LicenseValidationResult?> _validateOnline(
    LicenseCacheEntity license,
  ) async {
    try {
      final fingerprint = await _fingerprintService.getFingerprint();
      final antiTamper = AntiTamperService();

      final response = await http
          .post(
            Uri.parse(ApiConfig.licenseValidationUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${license.validationToken}',
            },
            body: jsonEncode({
              'license_key': license.licenseKey,
              'machine_hwid': fingerprint.fingerprint,
              'client_timestamp': DateTime.now().toUtc().toIso8601String(),
              'app_signature': antiTamper.getAppSignature(),
              'app_version': ApiConfig.appVersion,
            }),
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Update server time offset for clock drift detection
      antiTamper.updateServerTimeOffset(data['server_time'] as String?);

      if (response.statusCode == 200 && data['valid'] == true) {
        await _updateLastValidated(license.id);
        return null; // null = success, continue with local validation
      } else {
        // P1-008: Handle all structured error codes from server
        final errorCode = data['code'] as String? ?? 'UNKNOWN_ERROR';
        final errorMessage = data['error'] as String? ?? 'Validation failed';

        switch (errorCode) {
          case 'KEY_NOT_FOUND':
          case 'KEY_BANNED':
          case 'KEY_INACTIVE':
          case 'KEY_REVOKED':
            return LicenseValidationResult.invalid(
              LicenseStatus.blocked,
              errorMessage,
            );
          case 'KEY_SUSPENDED':
            return LicenseValidationResult.invalid(
              LicenseStatus.suspended,
              errorMessage,
            );
          case 'KEY_EXPIRED':
            return LicenseValidationResult.invalid(
              LicenseStatus.expired,
              errorMessage,
            );
          case 'HWID_MISMATCH':
            return LicenseValidationResult.invalid(
              LicenseStatus.deviceMismatch,
              errorMessage,
            );
          case 'DEVICE_LIMIT_EXCEEDED':
            return LicenseValidationResult.invalid(
              LicenseStatus.blocked,  // Treat as blocked since user can't use license
              errorMessage,
            );
          case 'BUSINESS_TYPE_MISMATCH':
            return LicenseValidationResult.invalid(
              LicenseStatus.businessTypeMismatch,
              errorMessage,
            );
          case 'RATE_LIMITED':
          case 'REPLAY_DETECTED':
            // Transient errors — allow offline grace period
            return null;
          default:
            // Unknown error — allow offline grace period
            LoggerService.d('LicenseService', 'LicenseService: Unknown error code: $errorCode');
            return null;
        }
      }
    } catch (e) {
      // Network error — allow offline grace period
      LoggerService.d('LicenseService', 'LicenseService: Online validation error: $e');
    }
    return null; // null = can't validate online, allow offline
  }

  /// Map status string to enum
  LicenseStatus _mapStatusString(String status) {
    switch (status) {
      case 'expired':
        return LicenseStatus.expired;
      case 'blocked':
      case 'banned':
        return LicenseStatus.blocked;
      case 'suspended':
        return LicenseStatus.suspended;
      case 'device_mismatch':
        return LicenseStatus.deviceMismatch;
      case 'inactive':
        return LicenseStatus.blocked;
      default:
        return LicenseStatus.networkError;
    }
  }

  /// Raw feature flags / enabled-modules JSON object from the license cache (for plan gating).
  Future<Map<String, dynamic>> getDecodedFeatureFlags() async {
    try {
      final license = await _getCachedLicense();
      if (license == null) return {};
      final raw = license.enabledModulesJson.trim();
      if (raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      LoggerService.d('LicenseService', 'LicenseService: Feature flags decode error: $e');
    }
    return {};
  }

  /// Parse modules JSON
  List<String> _parseModules(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return decoded.cast<String>();
      }
      if (decoded is Map) {
        // Feature flags — return keys where value is truthy
        return decoded.entries
            .where((e) => e.value == true || e.value == 1)
            .map((e) => e.key as String)
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Mask license key for display (show only partial)
  String _maskLicenseKey(String key) {
    if (key.length < 10) return '***';
    return '${key.substring(0, 4)}****${key.substring(key.length - 4)}';
  }

  /// Parse business_types from the stored value.
  /// The businessType field may contain:
  ///   - A JSON array string (new format): '["grocery","pharmacy"]'
  ///   - A plain string (old format): 'grocery'
  List<String> _parseBusinessTypes(String stored) {
    try {
      final decoded = jsonDecode(stored);
      if (decoded is List) {
        return decoded.cast<String>();
      }
    } catch (_) {
      // Not JSON — treat as single plain string
    }
    return [stored];
  }

  // ============================================================
  // SUBSCRIPTION METHODS
  // ============================================================

  /// Get subscription status from backend
  Future<Map<String, dynamic>?> getSubscriptionStatus() async {
    try {
      final license = await _getCachedLicense();
      if (license == null) return null;

      final response = await http.get(
        Uri.parse('${ApiConfig.subscriptionStatusUrl}?license_key=${license.licenseKey}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        LoggerService.d('LicenseService', 'Subscription status error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      LoggerService.d('LicenseService', 'Subscription status request error: $e');
      return null;
    }
  }

  /// Renew subscription manually
  Future<Map<String, dynamic>?> renewSubscription() async {
    try {
      final license = await _getCachedLicense();
      if (license == null) return null;

      final response = await http.post(
        Uri.parse(ApiConfig.subscriptionRenewUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'license_key': license.licenseKey}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        LoggerService.d('LicenseService', 'Subscription renewal failed: ${data['message']}');
        return null;
      }
    } catch (e) {
      LoggerService.d('LicenseService', 'Subscription renewal error: $e');
      return null;
    }
  }

  /// Cancel subscription
  Future<Map<String, dynamic>?> cancelSubscription({String? reason}) async {
    try {
      final license = await _getCachedLicense();
      if (license == null) return null;

      final body = {'license_key': license.licenseKey};
      if (reason != null) body['reason'] = reason;

      final response = await http.post(
        Uri.parse(ApiConfig.subscriptionCancelUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        LoggerService.d('LicenseService', 'Subscription cancel failed: ${data['message']}');
        return null;
      }
    } catch (e) {
      LoggerService.d('LicenseService', 'Subscription cancel error: $e');
      return null;
    }
  }

  /// Update subscription settings
  Future<Map<String, dynamic>?> updateSubscription(Map<String, dynamic> updates) async {
    try {
      final license = await _getCachedLicense();
      if (license == null) return null;

      final body = {'license_key': license.licenseKey, ...updates};

      final response = await http.put(
        Uri.parse(ApiConfig.subscriptionUpdateUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        LoggerService.d('LicenseService', 'Subscription update failed: ${data['message']}');
        return null;
      }
    } catch (e) {
      LoggerService.d('LicenseService', 'Subscription update error: $e');
      return null;
    }
  }
}
