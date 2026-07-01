import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/api_config.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/di/service_locator.dart';

// ── Data Models ──────────────────────────────────────────────────────────────

class TenantData {
  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final String? licenseKey;
  final String? planType;
  final List<String> activeModules;

  TenantData({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.licenseKey,
    this.planType,
    required this.activeModules,
  });

  factory TenantData.fromJson(Map<String, dynamic> json) {
    final modulesJson = json['activeModules'] as List<dynamic>? ?? [];
    return TenantData(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      licenseKey: json['licenseKey'] as String?,
      planType: json['planType'] as String?,
      activeModules: modulesJson.map((e) => e.toString()).toList(),
    );
  }
}

/// License data model for list/detail views
class LicenseData {
  final String licenseKey;
  final String? licenseKeyFull;
  final String tenantId;
  final String? tenantName;
  final String plan;
  final String status;
  final String? businessType;
  final String? ownerName;
  final String? ownerEmail;
  final String? ownerPhone;
  final int maxDevices;
  final DateTime? expiryDate;
  final DateTime? createdAt;
  final String type;

  LicenseData({
    required this.licenseKey,
    this.licenseKeyFull,
    required this.tenantId,
    this.tenantName,
    required this.plan,
    required this.status,
    this.businessType,
    this.ownerName,
    this.ownerEmail,
    this.ownerPhone,
    this.maxDevices = 1,
    this.expiryDate,
    this.createdAt,
    this.type = 'standalone',
  });

  factory LicenseData.fromJson(Map<String, dynamic> json) {
    return LicenseData(
      licenseKey: json['licenseKey'] ?? '',
      licenseKeyFull: json['licenseKeyFull'],
      tenantId: json['tenantId'] ?? '',
      tenantName: json['tenantName'],
      plan: json['plan'] ?? 'basic',
      status: json['status'] ?? 'unknown',
      businessType: json['businessType'],
      ownerName: json['ownerName'],
      ownerEmail: json['ownerEmail'],
      ownerPhone: json['ownerPhone'],
      maxDevices: json['maxDevices'] ?? 1,
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      type: json['type'] ?? 'standalone',
    );
  }

  /// Color for status badge
  bool get isActive => status.toUpperCase() == 'ACTIVE' || status.toUpperCase() == 'ACTIVATED';
  bool get isExpired => status.toUpperCase() == 'EXPIRED';
  bool get isSuspended => status.toUpperCase() == 'SUSPENDED';
  bool get isRevoked => status.toUpperCase() == 'REVOKED';
}

/// Audit log entry
class AuditEntry {
  final String action;
  final String? performedBy;
  final DateTime timestamp;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final String? details;

  AuditEntry({
    required this.action,
    this.performedBy,
    required this.timestamp,
    this.oldValues,
    this.newValues,
    this.details,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> json) {
    return AuditEntry(
      action: json['action'] ?? json['entityType'] ?? 'unknown',
      performedBy: json['performedBy'] ?? json['activatedBy'] ?? json['performed_by'],
      timestamp: DateTime.tryParse(json['createdAt']?.toString() ?? json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      oldValues: json['oldValues'] is Map ? Map<String, dynamic>.from(json['oldValues']) : null,
      newValues: json['newValues'] is Map ? Map<String, dynamic>.from(json['newValues']) : null,
      details: json['details'] ?? json['reason'],
    );
  }
}

// ── Repository ───────────────────────────────────────────────────────────────

class SuperAdminRepository {
  Future<Map<String, String>> _getHeaders() async {
    final sessionManager = sl<SessionManager>();
    final cognitoUser = await sessionManager.currentCognitoUser;
    String authToken = '';
    if (cognitoUser != null) {
      final session = await cognitoUser.getSession();
      if (session != null && session.isValid()) {
        authToken = session.getIdToken().getJwtToken() ?? '';
      }
    }
    return {
      'Content-Type': 'application/json',
      if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
    };
  }

  // ── Tenant Management ─────────────────────────────────────────────────────

  Future<List<TenantData>> getAllTenants() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/superadmin/tenants'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        final list = data['data'] as List<dynamic>;
        return list.map((e) => TenantData.fromJson(e)).toList();
      }
    }
    throw Exception('Failed to load tenants: ${response.statusCode}');
  }

  Future<void> toggleTenantModule({
    required String tenantId,
    required String businessType,
    required bool enabled,
  }) async {
    final body = jsonEncode({'businessType': businessType, 'enabled': enabled});

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/superadmin/tenants/$tenantId/modules'),
      headers: await _getHeaders(),
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to toggle module: ${response.statusCode}');
    }
  }

  // ── License Management ────────────────────────────────────────────────────

  /// Generate a new standalone license key via the Admin API.
  Future<Map<String, dynamic>> generateLicenseKey({
    required String plan,
    required String duration,
    String? businessType,
    String? ownerName,
    String? ownerEmail,
    String? ownerPhone,
    String? businessName,
    String? notes,
    int maxDevices = 1,
  }) async {
    final body = jsonEncode({
      'plan': plan,
      'duration': duration,
      ...{'businessType': businessType},
      ...{'ownerName': ownerName},
      ...{'ownerEmail': ownerEmail},
      ...{'ownerPhone': ownerPhone},
      ...{'businessName': businessName},
      ...{'notes': notes},
      'maxDevices': maxDevices,
    });

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/license/generate'),
      headers: await _getHeaders(),
      body: body,
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success' && data['data'] != null) {
        return data['data'] as Map<String, dynamic>;
      }
      throw Exception(data['message'] ?? 'Unexpected response format');
    }

    try {
      final errData = jsonDecode(response.body);
      final errMsg = errData['error']?['message'] ?? errData['message'] ?? 'Unknown error';
      throw Exception('$errMsg (HTTP ${response.statusCode})');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('License generation failed: HTTP ${response.statusCode}');
    }
  }

  /// List all licenses
  Future<List<LicenseData>> listLicenses() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/license/list'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        final list = data['data'] as List<dynamic>;
        return list.map((e) => LicenseData.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    throw Exception('Failed to load licenses: ${response.statusCode}');
  }

  /// Get license details
  Future<Map<String, dynamic>> getLicenseDetails(String licenseKey) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/license/$licenseKey'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        return data['data'] as Map<String, dynamic>;
      }
    }
    throw Exception('Failed to load license details: ${response.statusCode}');
  }

  /// Upgrade license plan
  Future<void> upgradeLicense(String licenseKey, String newPlan, {int? maxDevices}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/license/upgrade'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'licenseKey': licenseKey,
        'plan': newPlan,
        ...{'maxDevices': maxDevices},
      }),
    );
    _checkResponse(response, 'upgrade');
  }

  /// Extend license duration
  Future<void> extendLicense(String licenseKey, String duration) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/license/extend'),
      headers: await _getHeaders(),
      body: jsonEncode({'licenseKey': licenseKey, 'duration': duration}),
    );
    _checkResponse(response, 'extend');
  }

  /// Change license status (deactivate, suspend, revoke, reactivate)
  Future<void> changeLicenseStatus(String tenantId, String action, {String? reason}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/license/manage'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'tenantId': tenantId,
        'action': action,
        'reason': ?reason,
      }),
    );
    _checkResponse(response, action);
  }

  /// Transfer license to new tenant
  Future<void> transferLicense(String licenseKey, String newTenantId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/license/transfer'),
      headers: await _getHeaders(),
      body: jsonEncode({'licenseKey': licenseKey, 'newTenantId': newTenantId}),
    );
    _checkResponse(response, 'transfer');
  }

  /// Update owner details
  Future<void> updateOwnerDetails(String licenseKey, {
    String? ownerName, String? ownerEmail, String? ownerPhone, String? businessName,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/license/$licenseKey/owner'),
      headers: await _getHeaders(),
      body: jsonEncode({
        ...{'ownerName': ownerName},
        ...{'ownerEmail': ownerEmail},
        ...{'ownerPhone': ownerPhone},
        ...{'businessName': businessName},
      }),
    );
    _checkResponse(response, 'update owner');
  }

  /// Update business type
  Future<void> updateBusinessType(String licenseKey, String businessType) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/license/$licenseKey/business-type'),
      headers: await _getHeaders(),
      body: jsonEncode({'businessType': businessType}),
    );
    _checkResponse(response, 'update business type');
  }

  /// Update max devices
  Future<void> updateMaxDevices(String licenseKey, int maxDevices) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/license/$licenseKey/devices'),
      headers: await _getHeaders(),
      body: jsonEncode({'maxDevices': maxDevices}),
    );
    _checkResponse(response, 'update devices');
  }

  /// Update notes
  Future<void> updateNotes(String licenseKey, String notes) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/license/$licenseKey/notes'),
      headers: await _getHeaders(),
      body: jsonEncode({'notes': notes}),
    );
    _checkResponse(response, 'update notes');
  }

  /// Get audit history timeline for a license
  Future<List<AuditEntry>> getLicenseHistory(String licenseKey) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/license/$licenseKey/history'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success' && data['data'] != null) {
        final list = data['data'] as List<dynamic>;
        return list.map((e) => AuditEntry.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    return []; // Non-critical — return empty on failure
  }

  /// Get system-wide stats for admin dashboard
  Future<Map<String, dynamic>> getSystemStats() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/audit/stats'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success' || data['success'] == true) {
        return Map<String, dynamic>.from(data['stats'] ?? data['data'] ?? {});
      }
    }
    throw Exception('Failed to load system stats: ${response.statusCode}');
  }

  /// Get recent system activities for admin dashboard
  Future<List<Map<String, dynamic>>> getRecentActivities({int limit = 20}) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/audit/recent?limit=$limit'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success' || data['success'] == true) {
        final activities = data['activities'] ?? data['data'] ?? [];
        return List<Map<String, dynamic>>.from(activities);
      }
    }
    throw Exception('Failed to load recent activities: ${response.statusCode}');
  }

  void _checkResponse(http.Response response, String action) {
    if (response.statusCode != 200) {
      try {
        final data = jsonDecode(response.body);
        throw Exception(data['error']?['message'] ?? data['message'] ?? 'Failed to $action');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('Failed to $action: HTTP ${response.statusCode}');
      }
    }
  }
}
