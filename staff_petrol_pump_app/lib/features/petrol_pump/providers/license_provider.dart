import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/token_storage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

/// License profile data model for FuelPOS
/// ENHANCED: Now supports multi-business licenses via allowedBusinessTypes
class LicenseProfile {
  final String userId;
  final String tenantId;
  final String businessType;
  final String stationName;
  final String stationId;
  final String licenseKey;
  final String? licenseValidUntil;
  final List<String> features;
  final List<String> permissions;
  // ENHANCED: Multi-business license support
  final List<String> allowedBusinessTypes;
  final String plan;
  final String status;
  final int? maxUsers;
  final int? maxDevices;
  final String? expiresAt;

  const LicenseProfile({
    required this.userId,
    required this.tenantId,
    required this.businessType,
    required this.stationName,
    required this.stationId,
    required this.licenseKey,
    this.licenseValidUntil,
    required this.features,
    required this.permissions,
    this.allowedBusinessTypes = const [],
    this.plan = '',
    this.status = '',
    this.maxUsers,
    this.maxDevices,
    this.expiresAt,
  });

  bool get isPetrolPump => businessType == 'petrol_pump';
  bool get isRetail => businessType == 'retail';
  bool get isRestaurant => businessType == 'restaurant';
  bool get isPharmacy => businessType == 'pharmacy';

  bool get isValid {
    if (licenseValidUntil == null) return true;
    final expiry = DateTime.tryParse(licenseValidUntil!);
    if (expiry == null) return true;
    return expiry.isAfter(DateTime.now());
  }

  bool hasFeature(String feature) => features.contains(feature);
  bool hasPermission(String permission) => permissions.contains(permission);

  // ENHANCED: Multi-business license support
  bool hasBusinessType(String businessType) => allowedBusinessTypes.contains(businessType);
  
  bool get isMultiBusiness => allowedBusinessTypes.length > 1;
  
  List<String> get availableBusinessTypes => List.unmodifiable(allowedBusinessTypes);
  
  bool get isActive => status.toUpperCase() == 'ACTIVE';
  
  bool get isExpired {
    if (expiresAt == null) return false;
    final expiry = DateTime.tryParse(expiresAt!);
    if (expiry == null) return false;
    return expiry.isBefore(DateTime.now());
  }

  factory LicenseProfile.fromJson(Map<String, dynamic> json) {
    // Handle both legacy format and new enhanced format
    final List<String> allowedBusinessTypes = json['allowedBusinessTypes'] != null
        ? List<String>.from(json['allowedBusinessTypes'])
        : [json['businessType'] ?? ''];
    
    return LicenseProfile(
      userId: json['userId'] ?? '',
      tenantId: json['tenantId'] ?? '',
      businessType: json['businessType'] ?? '',
      stationName: json['stationName'] ?? '',
      stationId: json['stationId'] ?? '',
      licenseKey: json['licenseKey'] ?? '',
      licenseValidUntil: json['licenseValidUntil'],
      features: List<String>.from(json['features'] ?? []),
      permissions: List<String>.from(json['permissions'] ?? []),
      // ENHANCED: Multi-business license support
      allowedBusinessTypes: allowedBusinessTypes,
      plan: json['plan'] ?? '',
      status: json['status'] ?? '',
      maxUsers: json['maxUsers'],
      maxDevices: json['maxDevices'],
      expiresAt: json['expiresAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'tenantId': tenantId,
      'businessType': businessType,
      'stationName': stationName,
      'stationId': stationId,
      'licenseKey': licenseKey,
      'licenseValidUntil': licenseValidUntil,
      'features': features,
      'permissions': permissions,
      // ENHANCED: Multi-business license support
      'allowedBusinessTypes': allowedBusinessTypes,
      'plan': plan,
      'status': status,
      'maxUsers': maxUsers,
      'maxDevices': maxDevices,
      'expiresAt': expiresAt,
    };
  }
}

/// License state
class LicenseState {
  final LicenseProfile? profile;
  final bool isLoading;
  final String? error;
  final bool hasFetched;

  const LicenseState({
    this.profile,
    this.isLoading = false,
    this.error,
    this.hasFetched = false,
  });

  LicenseState copyWith({
    LicenseProfile? profile,
    bool? isLoading,
    String? error,
    bool? hasFetched,
  }) {
    return LicenseState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasFetched: hasFetched ?? this.hasFetched,
    );
  }

  bool get isAuthenticated => profile != null;
  String? get redirectRoute {
    if (profile == null) return null;
    return switch (profile!.businessType) {
      'petrol_pump' => '/dashboard/petrol-pump',
      'retail' => '/dashboard/retail',
      'restaurant' => '/dashboard/restaurant',
      'pharmacy' => '/dashboard/pharmacy',
      _ => '/dashboard',
    };
  }
}

/// License notifier - fetches and caches license profile
class LicenseNotifier extends StateNotifier<LicenseState> {
  LicenseNotifier() : super(const LicenseState()) {
    _loadFromCache();
  }

  Timer? _refreshTimer;

  Future<void> _loadFromCache() async {
    try {
      // Try to load from secure storage first
      final cached = await TokenStorage.getIdToken();
      if (cached != null) {
        // Decode JWT to extract license info
        final profile = _extractProfileFromToken(cached);
        if (profile != null) {
          state = state.copyWith(profile: profile, hasFetched: true);
        }
      }
    } catch (e) {
      // Silent fail - will fetch from API
    }
  }

  LicenseProfile? _extractProfileFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;

      final businessType = payload['custom:business_type'] ?? payload['businessType'];
      if (businessType == null) return null;

      // ENHANCED: Handle multi-business license support
      final allowedBusinessTypes = payload['custom:allowed_business_types'] != null
          ? List<String>.from(payload['custom:allowed_business_types'])
          : [businessType.toString()];

      return LicenseProfile(
        userId: payload['sub'] ?? '',
        tenantId: payload['custom:tenant_id'] ?? payload['businessId'] ?? '',
        businessType: businessType.toString(),
        stationName: payload['stationName']?.toString() ?? 'Unknown Station',
        stationId: payload['stationId']?.toString() ?? '',
        licenseKey: payload['licenseKey']?.toString() ?? '',
        licenseValidUntil: payload['licenseValidUntil']?.toString(),
        features: List<String>.from(payload['features'] ?? []),
        permissions: List<String>.from(payload['permissions'] ?? []),
        // ENHANCED: Multi-business license support
        allowedBusinessTypes: allowedBusinessTypes,
        plan: payload['custom:plan']?.toString() ?? '',
        status: payload['custom:license_status']?.toString() ?? 'ACTIVE',
        maxUsers: payload['custom:max_users'],
        maxDevices: payload['custom:max_devices'],
        expiresAt: payload['custom:expires_at']?.toString(),
      );
    } catch (e) {
      return null;
    }
  }

  /// ENHANCED: Load license data from login response
  void loadLicenseFromLoginResponse(Map<String, dynamic> loginResponse) {
    try {
      final licenseData = loginResponse['license'];
      if (licenseData != null) {
        final profile = LicenseProfile(
          userId: loginResponse['user']?['id'] ?? '',
          tenantId: licenseData['tenantId'] ?? '',
          businessType: licenseData['businessType'] ?? '',
          stationName: 'Unknown Station', // Will be updated from API if needed
          stationId: '', // Will be updated from API if needed
          licenseKey: '', // Will be updated from API if needed
          licenseValidUntil: licenseData['expiresAt'],
          features: List<String>.from(licenseData['features'] ?? []),
          permissions: List<String>.from(loginResponse['permissions'] ?? []),
          // ENHANCED: Multi-business license support
          allowedBusinessTypes: List<String>.from(licenseData['allowedBusinessTypes'] ?? []),
          plan: licenseData['plan'] ?? '',
          status: licenseData['status'] ?? '',
          maxUsers: licenseData['maxUsers'],
          maxDevices: licenseData['maxDevices'],
          expiresAt: licenseData['expiresAt'],
        );
        
        state = state.copyWith(profile: profile, hasFetched: true);
        _startRefreshTimer();
      }
    } catch (e) {
      // Silent fail - will fallback to token extraction
    }
  }

  /// Fetch license profile from API using user ID
  Future<void> fetchLicenseProfile() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final apiClient = ApiClient();
      final response = await apiClient.get(ApiEndpoints.validateLicense);

      if (response.data['success'] == true && response.data['data'] != null) {
        final profile = LicenseProfile.fromJson(response.data['data']);
        state = state.copyWith(
          profile: profile,
          isLoading: false,
          hasFetched: true,
        );

        // Start auto-refresh timer
        _startRefreshTimer();
      } else {
        // Try extracting from token as fallback
        final token = await TokenStorage.getIdToken();
        final profile = token != null ? _extractProfileFromToken(token) : null;

        if (profile != null) {
          state = state.copyWith(
            profile: profile,
            isLoading: false,
            hasFetched: true,
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            error: 'Failed to load license profile',
            hasFetched: true,
          );
        }
      }
    } catch (e) {
      // Fallback to token extraction
      final token = await TokenStorage.getIdToken();
      final profile = token != null ? _extractProfileFromToken(token) : null;

      if (profile != null) {
        state = state.copyWith(
          profile: profile,
          isLoading: false,
          hasFetched: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: e.toString(),
          hasFetched: true,
        );
      }
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      fetchLicenseProfile();
    });
  }

  void clear() {
    _refreshTimer?.cancel();
    state = const LicenseState();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

/// Provider for license state
final licenseProvider = StateNotifierProvider<LicenseNotifier, LicenseState>((ref) {
  return LicenseNotifier();
});

/// Provider for current license profile (convenience)
final licenseStateProvider = Provider<LicenseState>((ref) {
  return ref.watch(licenseProvider);
});

final licenseProfileProvider = Provider<LicenseProfile?>((ref) {
  return ref.watch(licenseProvider).profile;
});

/// Provider for business type
final businessTypeProvider = Provider<String>((ref) {
  return ref.watch(licenseProvider).profile?.businessType ?? '';
});

/// Provider for station ID
final stationIdProvider = Provider<String>((ref) {
  return ref.watch(licenseProvider).profile?.stationId ?? '';
});

/// Provider for tenant ID
final tenantIdProvider = Provider<String>((ref) {
  return ref.watch(licenseProvider).profile?.tenantId ?? '';
});
