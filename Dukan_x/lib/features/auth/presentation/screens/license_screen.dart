// ============================================================================
// LICENSE SCREEN — First Screen on App Launch
// ============================================================================
// Displays a premium license key input screen.
// Calls POST /license/validate (public, no auth required).
// On success → saves license data → navigates to Login.
//
// Flow: App Launch → License Screen → Login → Dashboard
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/api_config.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../models/business_type.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../providers/license_snapshot_provider.dart';
import '../../../../core/services/module_loader_service.dart';
import '../../../../core/database/app_database.dart';
import '../../../../services/device_fingerprint_service.dart';
import '../../../../services/secure_license_storage.dart';
import 'package:dukanx/core/responsive/responsive.dart'; // FIX P0-008: Encrypted storage

// Colors (Design Specs)
const Color _bgNavy = Color(0xFF0D0F2B);
const Color _bgPurpleBlue = Color(0xFF1E1842);
const Color _tealGradient1 = Color(0xFF00C6C6);
const Color _tealGradient2 = Color(0xFF00A3A3);

/// License validation result from the public API
///
/// Plan tier (basic/pro/premium) is determined by Super Admin at key generation
/// time and validated by DynamoDB. Frontend just reads what backend returns.
class LicenseValidateResult {
  final bool valid;
  final String businessType;
  final String plan;
  final List<String> features;
  final String? expiresAt;
  final int maxDevices;
  final int maxUsers;
  final String tenantId;

  /// Server timestamp for clock-drift prevention (ISO8601)
  final String? serverTime;

  /// Deadline for next online re-validation (ISO8601)
  final String? nextValidationRequiredBy;

  /// Hours of offline grace before re-validation required
  final int? offlineGraceHours;

  /// Server-signed JWT for tamper-proof verification
  final String? signedToken;

  /// Allowed business types array (multi-business licenses)
  final List<String> allowedBusinessTypes;

  /// Subscription plan tier — set by Super Admin (basic/pro/premium)
  final String subscriptionPlan;

  /// Feature flags map — key-value pairs gated by plan tier
  final Map<String, dynamic> featureFlags;

  /// Cognito User Pool ID tied to this license
  final String? cognitoUserPoolId;

  /// Cognito Client ID tied to this license
  final String? cognitoClientId;

  const LicenseValidateResult({
    required this.valid,
    required this.businessType,
    required this.plan,
    required this.features,
    this.expiresAt,
    required this.maxDevices,
    required this.maxUsers,
    required this.tenantId,
    this.serverTime,
    this.nextValidationRequiredBy,
    this.offlineGraceHours,
    this.signedToken,
    this.allowedBusinessTypes = const [],
    this.subscriptionPlan = 'basic',
    this.featureFlags = const {},
    this.cognitoUserPoolId,
    this.cognitoClientId,
  });

  factory LicenseValidateResult.fromJson(Map<String, dynamic> json) {
    // Parse allowed_business_types array (new) or fall back to businessType (old)
    final List<String> bizTypes;
    if (json['allowed_business_types'] is List) {
      bizTypes = (json['allowed_business_types'] as List)
          .map((e) => e.toString())
          .toList();
    } else if (json['allowedBusinessTypes'] is List) {
      bizTypes = (json['allowedBusinessTypes'] as List)
          .map((e) => e.toString())
          .toList();
    } else {
      bizTypes = [json['businessType'] as String? ?? 'general'];
    }

    // Parse feature_flags map
    final Map<String, dynamic> flags;
    if (json['feature_flags'] is Map) {
      flags = Map<String, dynamic>.from(json['feature_flags'] as Map);
    } else if (json['featureFlags'] is Map) {
      flags = Map<String, dynamic>.from(json['featureFlags'] as Map);
    } else {
      flags = {};
    }

    return LicenseValidateResult(
      valid: json['valid'] as bool? ?? false,
      businessType:
          json['businessType'] as String? ??
          json['business_type'] as String? ??
          'general',
      plan:
          json['plan'] as String? ??
          json['subscription_plan'] as String? ??
          json['subscriptionPlan'] as String? ??
          'basic',
      features:
          (json['features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      expiresAt: json['expiresAt'] as String? ?? json['expires_at'] as String?,
      maxDevices:
          json['maxDevices'] as int? ?? json['max_devices'] as int? ?? 5,
      maxUsers: json['maxUsers'] as int? ?? json['max_users'] as int? ?? 10,
      tenantId:
          json['tenantId'] as String? ?? json['tenant_id'] as String? ?? '',
      serverTime:
          json['serverTime'] as String? ?? json['server_time'] as String?,
      nextValidationRequiredBy:
          json['nextValidationRequiredBy'] as String? ??
          json['next_validation_required_by'] as String?,
      offlineGraceHours:
          json['offlineGraceHours'] as int? ??
          json['offline_grace_hours'] as int?,
      signedToken:
          json['signedToken'] as String? ??
          json['signed_token'] as String? ??
          json['token'] as String?,
      allowedBusinessTypes: bizTypes,
      subscriptionPlan:
          json['subscription_plan'] as String? ??
          json['subscriptionPlan'] as String? ??
          json['plan'] as String? ??
          'basic',
      featureFlags: flags,
      cognitoUserPoolId:
          json['cognito_user_pool_id'] as String? ??
          json['cognitoUserPoolId'] as String?,
      cognitoClientId:
          json['cognito_client_id'] as String? ??
          json['cognitoClientId'] as String?,
    );
  }
}

/// Premium License Key Input Screen
class LicenseScreen extends ConsumerStatefulWidget {
  const LicenseScreen({super.key});

  @override
  ConsumerState<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends ConsumerState<LicenseScreen>
    with SingleTickerProviderStateMixin {
  final _licenseController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _bgAnimController;

  @override
  void initState() {
    super.initState();
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _licenseController.dispose();
    _bgAnimController.dispose();
    super.dispose();
  }

  /// Parse business type string from license to BusinessType enum
  /// Handles various naming conventions and fallback cases
  BusinessType _parseBusinessType(String businessTypeName) {
    // Normalize the input: lowercase, remove spaces and special chars
    final normalized = businessTypeName.toLowerCase().replaceAll(
      RegExp(r'[\s_-]'),
      '',
    );

    // Map normalized strings to BusinessType enum values
    switch (normalized) {
      case 'grocery':
      case 'grocerystore':
        return BusinessType.grocery;
      case 'pharmacy':
      case 'medical':
      case 'medicalstore':
        return BusinessType.pharmacy;
      case 'restaurant':
      case 'hotel':
      case 'food':
        return BusinessType.restaurant;
      case 'clothing':
      case 'fashion':
      case 'apparel':
        return BusinessType.clothing;
      case 'electronics':
      case 'electronic':
        return BusinessType.electronics;
      case 'mobileshop':
      case 'mobile':
      case 'mobilephone':
        return BusinessType.mobileShop;
      case 'computershop':
      case 'computer':
        return BusinessType.computerShop;
      case 'hardware':
      case 'hardwarestore':
        return BusinessType.hardware;
      case 'service':
      case 'services':
        return BusinessType.service;
      case 'wholesale':
        return BusinessType.wholesale;
      case 'petrolpump':
      case 'petrol':
      case 'fuelstation':
      case 'gasstation':
        return BusinessType.petrolPump;
      case 'vegetablesbroker':
      case 'vegetablebroker':
      case 'mandi':
      case 'vegetables':
        return BusinessType.vegetablesBroker;
      case 'clinic':
      case 'doctor':
      case 'hospital':
        return BusinessType.clinic;
      case 'bookstore':
      case 'books':
      case 'stationery':
        return BusinessType.bookStore;
      case 'jewellery':
      case 'jewelry':
      case 'jeweller':
      case 'jeweler':
        return BusinessType.jewellery;
      case 'autoparts':
      case 'auto':
      case 'garage':
      case 'automotive':
        return BusinessType.autoParts;
      case 'general':
      case 'other':
      case 'default':
      default:
        return BusinessType.other;
    }
  }

  /// Validate the license key via public API
  Future<void> _validateLicense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final licenseKey = _licenseController.text.trim().toUpperCase();

      // Call the public POST /license/validate endpoint
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/license/validate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'licenseKey': licenseKey}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 &&
          (data['status'] == 'success' || data['success'] == true)) {
        // Extract the validated license data
        final respData = data['data'] as Map<String, dynamic>? ?? data;
        final result = LicenseValidateResult.fromJson(respData);

        // Cache the license locally
        await _cacheLicenseData(licenseKey, result);

        try {
          ProviderScope.containerOf(
            context,
          ).invalidate(licenseSnapshotProvider);
        } catch (_) {}

        // Allowed business types come from the license — not the generic features list.
        try {
          final allowed = result.allowedBusinessTypes.isNotEmpty
              ? result.allowedBusinessTypes
              : [result.businessType];
          await sl<ModuleLoaderService>().updateActiveModules(allowed);
        } catch (_) {}

        // CRITICAL FIX: Synchronize business type from license to provider
        // This ensures BusinessGuard works correctly for hardware and other types
        try {
          final businessTypeName = result.allowedBusinessTypes.isNotEmpty
              ? result.allowedBusinessTypes.first
              : result.businessType;

          // Parse string to BusinessType enum
          final businessType = _parseBusinessType(businessTypeName);

          // Set in provider (sync to SharedPreferences internally)
          await ref
              .read(businessTypeProvider.notifier)
              .setBusinessType(businessType);

          LoggerService.d(
            'LicenseScreen',
            'LicenseScreen: Business type set to ${businessType.name} from license',
          );
        } catch (e, stackTrace) {
          // Log but don't block - business type can be set later
          LoggerService.d(
            'LicenseScreen',
            'ERROR: LicenseScreen: Failed to set business type: $e',
          );
          LoggerService.d('LicenseScreen', 'Stack trace: $stackTrace');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Activation Successful!'),
              backgroundColor: Colors.green,
            ),
          );
          // Navigate to login — only licensed + authenticated users get through
          LoggerService.d(
            'LicenseScreen',
            'LicenseScreen: License valid → navigating to login',
          );
          if (mounted) context.pushReplacement(RoutePaths.login);
        }
      } else {
        // Extract error message from response
        final errorObj = data['error'] as Map<String, dynamic>?;
        final errorCode =
            errorObj?['code'] as String? ??
            data['code'] as String? ??
            'UNKNOWN';
        final errorMessage =
            errorObj?['message'] as String? ??
            data['message'] as String? ??
            'License validation failed';

        setState(() {
          _errorMessage = _humanizeError(errorCode, errorMessage);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid License Key: $_errorMessage'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } on SocketException {
      setState(() {
        _errorMessage =
            'No internet connection. Please check your network and try again.';
      });
    } on HttpException {
      setState(() {
        _errorMessage = 'Cannot reach license server. Please try again later.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Validation error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Convert error codes to user-friendly messages
  String _humanizeError(String code, String fallback) {
    switch (code) {
      // P1-008 + P1-001: License state errors with actionable guidance
      case 'KEY_NOT_FOUND':
        return 'Invalid license key. Please check the key format and try again. Format: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX';
      case 'KEY_UNASSIGNED':
        return 'This license key has not been activated yet. Please contact support or your administrator to activate it.';
      case 'KEY_BANNED':
        return 'This license key has been banned and cannot be used. Contact support for assistance.';
      case 'KEY_SUSPENDED':
        return 'This license key has been temporarily suspended. Please contact support for details.';
      case 'KEY_INACTIVE':
        return 'This license key is inactive. Please contact support to reactivate it.';
      case 'KEY_EXPIRED':
        return 'This license key has expired. Contact support to renew your license or purchase a new one.';
      case 'HWID_MISMATCH':
        return 'This license is bound to a different device. Contact your administrator to allow this device, or use the licensed device.';
      case 'DEVICE_LIMIT_EXCEEDED':
        return 'Maximum devices reached for this license. Deactivate a device on another machine or contact support to increase the limit.';
      case 'BUSINESS_TYPE_MISMATCH':
        return 'This license does not support your business type. Purchase a license for your business type or contact support.';
      case 'RATE_LIMITED':
        return 'Too many validation attempts. Please wait 15 minutes and try again.';
      case 'OFFLINE_GRACE_EXPIRED':
        return 'Offline validation period expired. Please connect to the internet to re-validate your license.';
      case 'NETWORK_ERROR':
        return 'Cannot reach the license server. Please check your internet connection and try again.';
      case 'REPLAY_DETECTED':
        return 'This request was already processed. Please try again with a fresh request.';
      case 'MISSING_LICENSE_KEY':
        return 'Please enter your license key.';
      case 'INVALID_FORMAT':
        return 'Invalid license key format. Expected format: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX';
      default:
        return fallback;
    }
  }

  /// Cache validated license data into the local Drift database
  Future<void> _cacheLicenseData(
    String licenseKey,
    LicenseValidateResult result,
  ) async {
    try {
      final db = sl<AppDatabase>();
      final fingerprintService = DeviceFingerprintService();
      final fingerprint = await fingerprintService.getFingerprint();

      // FIX P0-005: Use server time instead of client time to prevent clock manipulation
      final serverTime = result.serverTime != null
          ? DateTime.parse(result.serverTime!)
          : DateTime.now();

      final expiryDate = result.expiresAt != null
          ? DateTime.parse(result.expiresAt!)
          : serverTime.add(const Duration(days: 365));

      // FIX P0-005: Store next_validation_required_by from server response
      final nextValidationDeadline = result.nextValidationRequiredBy != null
          ? DateTime.parse(result.nextValidationRequiredBy!)
          : serverTime.add(Duration(hours: result.offlineGraceHours ?? 48));

      // Store allowed business types + feature flags from backend
      // Plan tier (basic/pro/premium) determined by Super Admin
      final cachedLicense = LicenseCacheEntity(
        id: licenseKey.hashCode.toRadixString(16),
        licenseKey: licenseKey,
        businessType: jsonEncode(
          result.allowedBusinessTypes.isNotEmpty
              ? result.allowedBusinessTypes
              : [result.businessType],
        ),
        customerId: result.tenantId,
        enabledModulesJson: jsonEncode(
          result.featureFlags.isNotEmpty
              ? result.featureFlags
              : result.features,
        ),
        issueDate: serverTime,
        expiryDate: expiryDate,
        deviceFingerprint: fingerprint.fingerprint,
        deviceId: fingerprint.platform,
        lastValidatedAt: serverTime,
        validationToken: result.signedToken ?? 'validated',
        tokenSignature: result.subscriptionPlan,

        createdAt: serverTime,
        updatedAt: serverTime,
        licenseType: 'paid',
        status: 'active',
        maxDevices: result.maxDevices,
        offlineGraceDays: result.offlineGraceHours ?? 48,
        isSynced: true,
        lastSyncAt: serverTime,
        // nextValidationRequiredBy not yet in generated entity
        // Computed at runtime: lastValidatedAt + offlineGraceDays
      );

      // Clear existing and insert new
      await db.delete(db.licenseCache).go();
      await db
          .into(db.licenseCache)
          .insert(
            LicenseCacheCompanion.insert(
              id: cachedLicense.id,
              licenseKey: cachedLicense.licenseKey,
              businessType: cachedLicense.businessType,
              customerId: Value(cachedLicense.customerId),
              enabledModulesJson: Value(cachedLicense.enabledModulesJson),
              issueDate: cachedLicense.issueDate,
              expiryDate: cachedLicense.expiryDate,
              deviceFingerprint: cachedLicense.deviceFingerprint,
              deviceId: Value(cachedLicense.deviceId),
              lastValidatedAt: cachedLicense.lastValidatedAt,
              validationToken: cachedLicense.validationToken,
              tokenSignature: cachedLicense.tokenSignature,
              createdAt: cachedLicense.createdAt,
              updatedAt: cachedLicense.updatedAt,
              licenseType: Value(cachedLicense.licenseType),
              status: Value(cachedLicense.status),
              maxDevices: Value(cachedLicense.maxDevices),
              offlineGraceDays: Value(cachedLicense.offlineGraceDays),
              isSynced: Value(cachedLicense.isSynced),
              lastSyncAt: Value(cachedLicense.lastSyncAt),
            ),
          );

      // FIX P0-008: Also save encrypted copy to secure storage (platform keychain)
      // This protects license token from extraction if device is stolen
      final secureLicenseData = SecureLicenseData(
        licenseKey: licenseKey,
        clientId: result.tenantId.isNotEmpty ? result.tenantId : 'unknown',
        businessType: result.businessType,
        status: 'active',
        expiryDate: expiryDate,
        activationDate: serverTime,
        maxDevices: result.maxDevices,
        offlineGraceHours: result.offlineGraceHours ?? 48,
        signedToken: result.signedToken,
        nextValidationRequiredBy: nextValidationDeadline,
        features: result.featureFlags,
        storedAt: serverTime,
      );

      await SecureLicenseStorage().saveLicense(secureLicenseData);
      LoggerService.d(
        'LicenseScreen',
        'LicenseScreen: License cached and encrypted',
      );
    } catch (e) {
      LoggerService.d(
        'LicenseScreen',
        'LicenseScreen: Failed to cache license: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = context.isMobile;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient & Animated Mesh
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgAnimController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _BackgroundPatternPainter(
                    animationValue: _bgAnimController.value,
                  ),
                );
              },
            ),
          ),

          // Soft glowing icons
          _buildFloatingIcons(size),

          // Main Card
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 0),
              child: Container(
                width: isMobile ? double.infinity : 480,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Card Header (Top Bar)
                    Container(
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildWindowControl(const Color(0xFFFF5F56)),
                          const SizedBox(width: 8),
                          _buildWindowControl(const Color(0xFFFFBD2E)),
                          const SizedBox(width: 8),
                          _buildWindowControl(const Color(0xFF27C93F)),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo + Brand Row
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFF7A00),
                                      Color(0xFFD63C00),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'DXB',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'DUKANXMULTIBIZ PRO',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF1E293B),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      'Unlock Your Business Potential',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF64748B),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Card Body
                          Text(
                            'DukanxMultibiz Pro Activation',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF0F172A),
                              fontSize: responsiveValue<double>(
                                context,
                                mobile: 16,
                                tablet: 18,
                                desktop: 20,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please enter your 16-character license key to activate your premium features.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF64748B),
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // License Key Input
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LICENSE KEY',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _licenseController,
                                  enabled: !_isLoading,
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF334155),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[A-Za-z0-9]'),
                                    ),
                                    _LicenseNumberFormatter(),
                                  ],
                                  decoration: InputDecoration(
                                    hintText: 'XXXX-XXXX-XXXX-XXXX',
                                    hintStyle: GoogleFonts.poppins(
                                      color: const Color(0xFFCBD5E1),
                                      fontSize: 14,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: _tealGradient1,
                                        width: 2,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Colors.red,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter a license key';
                                    }
                                    if (value.length < 19) {
                                      return 'Please enter the full 16-character key';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),

                          if (_errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              style: GoogleFonts.poppins(
                                color: Colors.red.shade400,
                                fontSize: 12,
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(
                                        'Find Your License Key',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      content: Text(
                                        'Your license key was sent to your registered email at the time of purchase.\n\nCheck your inbox (and spam folder) for an email from DukanX with subject "Your License Key".\n\nIf you cannot find it, contact support@dukanx.com.',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          height: 1.5,
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(),
                                          child: const Text('Got It'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Text(
                                  'Where can I find my License Key?',
                                  style: GoogleFonts.poppins(
                                    color: _tealGradient1,
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                    decorationColor: _tealGradient1,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  launchUrl(
                                    Uri.parse(
                                      '${AppConfig.webBaseUrl}/pricing',
                                    ),
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                                child: Text(
                                  'Need a License? Buy Now',
                                  style: GoogleFonts.poppins(
                                    color: _tealGradient1,
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                    decorationColor: _tealGradient1,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Action Button
                          Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_tealGradient1, _tealGradient2],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: _tealGradient1.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _validateLicense,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'ACTIVATE NOW',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.arrow_forward,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(height: 32),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 16),

                          // Card Footer
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Powered by Dukanx',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                              ),
                              Row(
                                children: [
                                  _buildFooterLink('Support'),
                                  const SizedBox(width: 8),
                                  _buildFooterLink('Terms'),
                                  const SizedBox(width: 8),
                                  _buildFooterLink('Privacy'),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowControl(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildFooterLink(String text) {
    final urls = {
      'Support': '${AppConfig.webBaseUrl}/support',
      'Terms': '${AppConfig.webBaseUrl}/terms',
      'Privacy': '${AppConfig.webBaseUrl}/privacy',
    };
    return InkWell(
      onTap: () {
        final url = urls[text];
        if (url != null) {
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      },
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: const Color(0xFF94A3B8),
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildFloatingIcons(Size size) {
    return Stack(
      children: [
        _buildGlowingIcon(
          Icons.bar_chart_rounded,
          size.width * 0.15,
          size.height * 0.2,
        ),
        _buildGlowingIcon(
          Icons.shopping_cart_outlined,
          size.width * 0.8,
          size.height * 0.15,
        ),
        _buildGlowingIcon(
          Icons.lightbulb_outline,
          size.width * 0.85,
          size.height * 0.7,
        ),
        _buildGlowingIcon(
          Icons.monetization_on_outlined,
          size.width * 0.1,
          size.height * 0.8,
        ),
        _buildGlowingIcon(
          Icons.mail_outline_rounded,
          size.width * 0.5,
          size.height * 0.9,
          opacity: 0.3,
        ),
      ],
    );
  }

  Widget _buildGlowingIcon(
    IconData icon,
    double x,
    double y, {
    double opacity = 0.5,
  }) {
    return Positioned(
      left: x,
      top: y,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00C6C6).withValues(alpha: opacity * 0.5),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: opacity),
          size: 40,
        ),
      ),
    );
  }
}

/// Custom formatter for license key XXXX-XXXX-XXXX-XXXX
class _LicenseNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.toUpperCase().replaceAll('-', '');
    if (text.length > 16) {
      text = text.substring(0, 16);
    }
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write('-');
      }
    }
    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

/// Custom painter for background gradient and subtle polygons
class _BackgroundPatternPainter extends CustomPainter {
  final double animationValue;

  _BackgroundPatternPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    // Base gradient
    final Rect rect = Offset.zero & size;
    final Paint bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_bgNavy, _bgPurpleBlue, _bgNavy],
      ).createShader(rect);

    canvas.drawRect(rect, bgPaint);

    // Draw mesh/polygons
    final Paint linePaint = Paint()
      ..color = const Color(0xFF00C6C6).withValues(alpha: 0.05)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final Paint fillPaint = Paint()
      ..color = const Color(0xFF00A3A3).withValues(alpha: 0.02)
      ..style = PaintingStyle.fill;

    // A simple grid of points that move slightly with animation
    final int cols = 5;
    final int rows = 5;
    final double cellWidth = size.width / cols;
    final double cellHeight = size.height / rows;

    List<Offset> points = [];

    for (int i = 0; i <= cols; i++) {
      for (int j = 0; j <= rows; j++) {
        double x = i * cellWidth;
        double y = j * cellHeight;

        // Add some noise and animation
        double xOffset = math.sin(animationValue * 2 * math.pi + i) * 30;
        double yOffset = math.cos(animationValue * 2 * math.pi + j) * 30;

        points.add(Offset(x + xOffset, y + yOffset));
      }
    }

    // Draw triangles between points
    for (int i = 0; i < cols; i++) {
      for (int j = 0; j < rows; j++) {
        int p1 = i * (rows + 1) + j;
        int p2 = p1 + 1;
        int p3 = (i + 1) * (rows + 1) + j;
        int p4 = p3 + 1;

        // Triangle 1
        Path path1 = Path()
          ..moveTo(points[p1].dx, points[p1].dy)
          ..lineTo(points[p2].dx, points[p2].dy)
          ..lineTo(points[p3].dx, points[p3].dy)
          ..close();

        canvas.drawPath(path1, fillPaint);
        canvas.drawPath(path1, linePaint);

        // Triangle 2
        Path path2 = Path()
          ..moveTo(points[p2].dx, points[p2].dy)
          ..lineTo(points[p4].dx, points[p4].dy)
          ..lineTo(points[p3].dx, points[p3].dy)
          ..close();

        canvas.drawPath(path2, fillPaint);
        canvas.drawPath(path2, linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPatternPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
