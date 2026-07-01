// Vendor Profile Model
// Single source of truth for vendor business details used in invoices
//
// Created: 2024-12-25
// Author: DukanX Team

import 'package:dukanx/core/compat/firestore_compat.dart';

/// Complete vendor profile for invoice generation
class VendorProfile {
  final String id;

  // Personal Details
  final String vendorName;
  final String mobileNumber;
  final String? email;

  // Shop/Business Details
  final String shopName;
  final String shopAddress;
  final String shopMobile;
  final String? gstin;
  final String? shopLogoUrl;
  final AvatarData? avatar;

  // Invoice-specific fields
  final String? fssaiNumber; // For food businesses
  final String? businessTagline; // Optional shop tagline
  final String? stampImageUrl; // Stamp image for invoices
  final String? signatureImageUrl; // Digital signature
  final String? returnPolicy; // Return policy text
  final String? businessType; // grocery/pharmacy/restaurant etc.
  final String? upiId; // For QR code on invoices

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version; // For version history tracking

  VendorProfile({
    required this.id,
    required this.vendorName,
    required this.mobileNumber,
    this.email,
    required this.shopName,
    required this.shopAddress,
    required this.shopMobile,
    this.gstin,
    this.shopLogoUrl,
    this.avatar,
    this.fssaiNumber,
    this.businessTagline,
    this.stampImageUrl,
    this.signatureImageUrl,
    this.returnPolicy,
    this.businessType,
    this.upiId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.version = 1,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Empty profile for new vendors
  factory VendorProfile.empty(String vendorId) {
    return VendorProfile(
      id: vendorId,
      vendorName: '',
      mobileNumber: '',
      shopName: '',
      shopAddress: '',
      shopMobile: '',
    );
  }

  static DateTime? _parseDateTime(dynamic val) {
  if (val == null) return null;
  if (val is Timestamp) return val.toDate();
  if (val is String) return DateTime.tryParse(val);
  if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
  try {
    return (val as dynamic).toDate();
  } catch (_) {}
  return null;
}

  /// Create from Firestore document
  factory VendorProfile.fromFirestore(dynamic doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return VendorProfile(
      id: doc.id,
      vendorName: data['vendorName'] ?? data['name'] ?? '',
      mobileNumber: data['mobileNumber'] ?? data['mobile'] ?? '',
      email: data['email'],
      shopName: data['shopName'] ?? '',
      shopAddress: data['shopAddress'] ?? data['address'] ?? '',
      shopMobile: data['shopMobile'] ?? data['mobileNumber'] ?? '',
      gstin: data['gstin'],
      shopLogoUrl: data['shopLogoUrl'],
      avatar: data['avatar'] != null
          ? AvatarData.fromMap(data['avatar'])
          : null,
      fssaiNumber: data['fssaiNumber'],
      businessTagline: data['businessTagline'],
      stampImageUrl: data['stampImageUrl'],
      signatureImageUrl: data['signatureImageUrl'],
      returnPolicy: data['returnPolicy'],
      businessType: data['businessType'],
      upiId: data['upiId'],
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(data['updatedAt']) ?? DateTime.now(),
      version: data['version'] ?? 1,
    );
  }

  /// Create from Map (for local storage)
  factory VendorProfile.fromMap(Map<String, dynamic> map) {
    return VendorProfile(
      id: map['id'] ?? '',
      vendorName: map['vendorName'] ?? '',
      mobileNumber: map['mobileNumber'] ?? '',
      email: map['email'],
      shopName: map['shopName'] ?? '',
      shopAddress: map['shopAddress'] ?? '',
      shopMobile: map['shopMobile'] ?? '',
      gstin: map['gstin'],
      shopLogoUrl: map['shopLogoUrl'],
      avatar: map['avatar'] != null ? AvatarData.fromMap(map['avatar']) : null,
      fssaiNumber: map['fssaiNumber'],
      businessTagline: map['businessTagline'],
      stampImageUrl: map['stampImageUrl'],
      signatureImageUrl: map['signatureImageUrl'],
      returnPolicy: map['returnPolicy'],
      businessType: map['businessType'],
      upiId: map['upiId'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
      version: map['version'] ?? 1,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'vendorName': vendorName,
      'mobileNumber': mobileNumber,
      'email': email,
      'shopName': shopName,
      'shopAddress': shopAddress,
      'shopMobile': shopMobile,
      'gstin': gstin,
      'shopLogoUrl': shopLogoUrl,
      'avatar': avatar?.toMap(),
      'fssaiNumber': fssaiNumber,
      'businessTagline': businessTagline,
      'stampImageUrl': stampImageUrl,
      'signatureImageUrl': signatureImageUrl,
      'returnPolicy': returnPolicy,
      'businessType': businessType,
      'upiId': upiId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'version': version,
    };
  }

  /// Convert to Map (for local storage)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendorName': vendorName,
      'mobileNumber': mobileNumber,
      'email': email,
      'shopName': shopName,
      'shopAddress': shopAddress,
      'shopMobile': shopMobile,
      'gstin': gstin,
      'shopLogoUrl': shopLogoUrl,
      'avatar': avatar?.toMap(),
      'fssaiNumber': fssaiNumber,
      'businessTagline': businessTagline,
      'stampImageUrl': stampImageUrl,
      'signatureImageUrl': signatureImageUrl,
      'returnPolicy': returnPolicy,
      'businessType': businessType,
      'upiId': upiId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'version': version,
    };
  }

  VendorProfile copyWith({
    String? id,
    String? vendorName,
    String? mobileNumber,
    String? email,
    String? shopName,
    String? shopAddress,
    String? shopMobile,
    String? gstin,
    String? shopLogoUrl,
    AvatarData? avatar,
    String? fssaiNumber,
    String? businessTagline,
    String? stampImageUrl,
    String? signatureImageUrl,
    String? returnPolicy,
    String? businessType,
    String? upiId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  }) {
    return VendorProfile(
      id: id ?? this.id,
      vendorName: vendorName ?? this.vendorName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      shopName: shopName ?? this.shopName,
      shopAddress: shopAddress ?? this.shopAddress,
      shopMobile: shopMobile ?? this.shopMobile,
      gstin: gstin ?? this.gstin,
      shopLogoUrl: shopLogoUrl ?? this.shopLogoUrl,
      avatar: avatar ?? this.avatar,
      fssaiNumber: fssaiNumber ?? this.fssaiNumber,
      businessTagline: businessTagline ?? this.businessTagline,
      stampImageUrl: stampImageUrl ?? this.stampImageUrl,
      signatureImageUrl: signatureImageUrl ?? this.signatureImageUrl,
      returnPolicy: returnPolicy ?? this.returnPolicy,
      businessType: businessType ?? this.businessType,
      upiId: upiId ?? this.upiId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      version: version ?? this.version + 1,
    );
  }

  /// Check if profile is complete enough for invoices
  bool get isComplete =>
      vendorName.isNotEmpty &&
      shopName.isNotEmpty &&
      shopAddress.isNotEmpty &&
      shopMobile.isNotEmpty;

  /// Validation helpers
  static bool isValidMobile(String mobile) {
    final regex = RegExp(r'^[6-9]\d{9}$');
    return regex.hasMatch(mobile.replaceAll(RegExp(r'[^\d]'), ''));
  }

  static bool isValidGstin(String gstin) {
    // GSTIN format: 2 digits state code + 10 char PAN + 1 entity code + Z + 1 checksum
    final regex = RegExp(
      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
      caseSensitive: false,
    );
    return gstin.isEmpty || regex.hasMatch(gstin.toUpperCase());
  }

  static bool isValidEmail(String email) {
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return email.isEmpty || regex.hasMatch(email);
  }

  @override
  String toString() {
    return 'VendorProfile(id: $id, shopName: $shopName, vendorName: $vendorName)';
  }
}

/// Profile history entry for version tracking
class ProfileHistoryEntry {
  final int version;
  final DateTime timestamp;
  final Map<String, dynamic> changes;
  final String? changedBy;

  ProfileHistoryEntry({
    required this.version,
    required this.timestamp,
    required this.changes,
    this.changedBy,
  });

  factory ProfileHistoryEntry.fromMap(Map<String, dynamic> map) {
    return ProfileHistoryEntry(
      version: map['version'] ?? 0,
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      changes: Map<String, dynamic>.from(map['changes'] ?? {}),
      changedBy: map['changedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'timestamp': Timestamp.fromDate(timestamp),
      'changes': changes,
      'changedBy': changedBy,
    };
  }
}

/// Avatar data stored in profile
class AvatarData {
  final String avatarId;
  final String category;

  const AvatarData({required this.avatarId, required this.category});

  factory AvatarData.fromMap(Map<String, dynamic> map) {
    return AvatarData(
      avatarId: map['avatarId'] ?? '',
      category: map['category'] ?? 'neutral',
    );
  }

  Map<String, dynamic> toMap() {
    return {'avatarId': avatarId, 'category': category};
  }

  // Helper to get asset path dynamically
  String get assetPath => 'assets/avatars/$avatarId.png';
}
