// ============================================================================
// CLINIC LICENSE VALIDATION SERVICE
// ============================================================================
// Validates license key on app boot
// Checks: businessType === "clinic", isActive === true, expiresAt > now
// Redirects to /unauthorized if validation fails
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/clinic_dashboard_models.dart';
import 'clinic_dashboard_repository.dart';

final clinicLicenseServiceProvider = Provider<ClinicLicenseService>((ref) {
  return ClinicLicenseService(
    repository: ref.read(clinicDashboardRepositoryProvider),
  );
});

class ClinicLicenseService {
  final ClinicDashboardRepository _repository;

  static const String _licenseKeyKey = 'clinic_license_key';
  static const String _clinicIdKey = 'clinic_id';
  static const String _validatedAtKey = 'clinic_license_validated_at';

  ClinicLicenseService({required ClinicDashboardRepository repository})
      : _repository = repository;

  /// Validates the license key and returns the result
  /// Call this on app boot before rendering any clinic dashboard
  Future<LicenseValidationResult> validateLicense(String licenseKey) async {
    try {
      // Check cache first (valid for 1 hour)
      final cachedResult = await _getCachedValidation(licenseKey);
      if (cachedResult != null) {
        return cachedResult;
      }

      // Validate with API
      final license = await _repository.validateLicense(licenseKey);

      // Check business type
      if (license.businessType?.toLowerCase() != 'clinic') {
        return LicenseValidationResult.invalid(
          reason: InvalidLicenseReason.wrongBusinessType,
          message: 'This license is not valid for clinic business type',
        );
      }

      // Check if active
      if (!license.isValidClinic) {
        if (license.isExpired) {
          return LicenseValidationResult.invalid(
            reason: InvalidLicenseReason.expired,
            message: 'Your clinic license has expired',
            expiresAt: license.expiresAt,
          );
        }
        if (license.isInactive) {
          return LicenseValidationResult.invalid(
            reason: InvalidLicenseReason.inactive,
            message: 'Your clinic license is inactive',
          );
        }
        return LicenseValidationResult.invalid(
          reason: InvalidLicenseReason.unknown,
          message: license.error ?? 'License validation failed',
        );
      }

      // Save valid license
      await _saveLicenseData(licenseKey, license);

      return LicenseValidationResult.valid(
        clinicId: license.clinicId!,
        tenantId: license.tenantId!,
        expiresAt: license.expiresAt,
      );
    } catch (e) {
      return LicenseValidationResult.invalid(
        reason: InvalidLicenseReason.networkError,
        message: 'Failed to validate license: $e',
      );
    }
  }

  /// Gets the stored license key if available
  Future<String?> getStoredLicenseKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_licenseKeyKey);
  }

  Future<String?> getStoredClinicId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_clinicIdKey);
  }

  Future<void> clearLicenseData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_licenseKeyKey);
    await prefs.remove(_clinicIdKey);
    await prefs.remove(_validatedAtKey);
  }

  Future<bool> needsRevalidation() async {
    final prefs = await SharedPreferences.getInstance();
    final validatedAt = prefs.getString(_validatedAtKey);
    if (validatedAt == null) return true;
    final lastValidated = DateTime.tryParse(validatedAt);
    if (lastValidated == null) return true;
    return DateTime.now().difference(lastValidated).inHours >= 1;
  }

  Future<LicenseValidationResult?> _getCachedValidation(String licenseKey) async {
    final storedKey = await getStoredLicenseKey();
    if (storedKey != licenseKey) return null;
    if (await needsRevalidation()) return null;
    final clinicId = await getStoredClinicId();
    if (clinicId == null) return null;
    return LicenseValidationResult.valid(clinicId: clinicId, tenantId: null, expiresAt: null);
  }

  Future<void> _saveLicenseData(String licenseKey, ClinicLicense license) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_licenseKeyKey, licenseKey);
    if (license.clinicId != null) await prefs.setString(_clinicIdKey, license.clinicId!);
    await prefs.setString(_validatedAtKey, DateTime.now().toIso8601String());
  }
}

// ============================================================================
// LICENSE VALIDATION RESULT
// ============================================================================

class LicenseValidationResult {
  final bool isValid;
  final String? clinicId;
  final String? tenantId;
  final String? expiresAt;
  final InvalidLicenseReason? reason;
  final String? message;

  const LicenseValidationResult._({
    required this.isValid,
    this.clinicId,
    this.tenantId,
    this.expiresAt,
    this.reason,
    this.message,
  });

  factory LicenseValidationResult.valid({
    required String clinicId,
    String? tenantId,
    String? expiresAt,
  }) {
    return LicenseValidationResult._(
      isValid: true,
      clinicId: clinicId,
      tenantId: tenantId,
      expiresAt: expiresAt,
    );
  }

  factory LicenseValidationResult.invalid({
    required InvalidLicenseReason reason,
    String? message,
    String? expiresAt,
  }) {
    return LicenseValidationResult._(
      isValid: false,
      reason: reason,
      message: message,
      expiresAt: expiresAt,
    );
  }
}

enum InvalidLicenseReason {
  wrongBusinessType,
  expired,
  inactive,
  notFound,
  networkError,
  unknown,
}

// ============================================================================
// LICENSE GUARD WIDGET
// ============================================================================

class LicenseGuard extends ConsumerWidget {
  final Widget child;
  final String licenseKey;
  final Widget unauthorizedWidget;

  const LicenseGuard({
    super.key,
    required this.child,
    required this.licenseKey,
    required this.unauthorizedWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final validationAsync = ref.watch(_licenseValidationProvider(licenseKey));

    return validationAsync.when(
      data: (result) {
        if (result.isValid) {
          return child;
        } else {
          return unauthorizedWidget;
        }
      },
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Validating license...'),
            ],
          ),
        ),
      ),
      error: (err, stack) => unauthorizedWidget,
    );
  }
}

final _licenseValidationProvider = FutureProvider.family<LicenseValidationResult, String>(
  (ref, licenseKey) async {
    final service = ref.read(clinicLicenseServiceProvider);
    return service.validateLicense(licenseKey);
  },
);
