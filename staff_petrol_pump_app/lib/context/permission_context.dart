import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/token_storage.dart';

class PermissionState {
  final String role;
  final String businessType;
  final String businessName;
  final String licenseKey;
  final List<String> licensedBusinessTypes;
  final List<String> permissions;
  final DateTime? expiresAt;

  const PermissionState({
    required this.role,
    required this.businessType,
    required this.businessName,
    required this.licenseKey,
    required this.licensedBusinessTypes,
    required this.permissions,
    required this.expiresAt,
  });

  const PermissionState.empty()
      : role = '',
        businessType = '',
        businessName = '',
        licenseKey = '',
        licensedBusinessTypes = const [],
        permissions = const [],
        expiresAt = null;

  bool get isAuthenticated => expiresAt != null && expiresAt!.isAfter(DateTime.now());

  bool can(String module, String action) => permissions.contains('$module.$action');

  bool canAny(List<List<String>> checks) => checks.any((check) => can(check[0], check[1]));

  bool canAll(List<List<String>> checks) => checks.every((check) => can(check[0], check[1]));
}

final permissionProvider = StateNotifierProvider<PermissionNotifier, PermissionState>(
  (ref) => PermissionNotifier(),
);

class PermissionNotifier extends StateNotifier<PermissionState> {
  PermissionNotifier() : super(const PermissionState.empty()) {
    loadFromCookieMirror();
  }

  String _normalizeRole(String raw) {
    final value = raw.trim().toLowerCase();
    switch (value) {
      case 'chartered_accountant':
      case 'accountant':
        return 'ca';
      case 'business_owner':
        return 'admin';
      default:
        return value;
    }
  }

  String _normalizeBusinessType(String raw) {
    final value = raw.trim().toLowerCase();
    switch (value) {
      case 'vegetable_broker':
        return 'vegetables_broker';
      case 'jewelry':
        return 'jewellery';
      case 'clothing_store':
        return 'clothing';
      default:
        return value;
    }
  }

  Future<void> loadFromCookieMirror() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) {
      state = const PermissionState.empty();
      return;
    }

    final parts = token.split('.');
    if (parts.length != 3) {
      state = const PermissionState.empty();
      return;
    }

    final payloadMap = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    ) as Map<String, dynamic>;

    final exp = payloadMap['exp'] is int
        ? DateTime.fromMillisecondsSinceEpoch((payloadMap['exp'] as int) * 1000)
        : null;

    state = PermissionState(
      role: _normalizeRole((payloadMap['roleName'] ?? payloadMap['custom:role'] ?? '').toString()),
      businessType: _normalizeBusinessType(
        (payloadMap['businessType'] ?? payloadMap['custom:business_type'] ?? '').toString(),
      ),
      businessName: payloadMap['businessName']?.toString() ?? '',
      licenseKey: payloadMap['licenseKey']?.toString() ?? '',
      licensedBusinessTypes: (payloadMap['licensedBusinessTypes'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      permissions: (payloadMap['permissions'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      expiresAt: exp,
    );
  }

  Future<void> clear() async {
    state = const PermissionState.empty();
  }
}
