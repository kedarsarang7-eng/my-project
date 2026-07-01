// Jewellery Certificate Model - Certificate & Certification Tracking
// Feature: Certificate tracking for jewellery items (hallmark, assay, valuation, insurance, appraisal)
// Requirement 16.5: Certificate and certification tracking model and screen

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'jewellery_certificate_model.freezed.dart';
part 'jewellery_certificate_model.g.dart';

/// Certificate type - the kind of certification document
enum CertificateType {
  hallmark, // BIS hallmark certificate
  assay, // Assay/purity test certificate
  valuation, // Valuation report from certified valuer
  insurance, // Insurance certificate for jewellery
  appraisal, // Appraisal/grading certificate
}

extension CertificateTypeExtension on CertificateType {
  String get displayName {
    switch (this) {
      case CertificateType.hallmark:
        return 'Hallmark';
      case CertificateType.assay:
        return 'Assay';
      case CertificateType.valuation:
        return 'Valuation';
      case CertificateType.insurance:
        return 'Insurance';
      case CertificateType.appraisal:
        return 'Appraisal';
    }
  }

  String get description {
    switch (this) {
      case CertificateType.hallmark:
        return 'BIS Hallmark purity certification';
      case CertificateType.assay:
        return 'Assay/purity test report';
      case CertificateType.valuation:
        return 'Valuation report from certified valuer';
      case CertificateType.insurance:
        return 'Insurance coverage certificate';
      case CertificateType.appraisal:
        return 'Appraisal/grading certificate';
    }
  }

  IconData get icon {
    switch (this) {
      case CertificateType.hallmark:
        return Icons.verified;
      case CertificateType.assay:
        return Icons.science;
      case CertificateType.valuation:
        return Icons.price_change;
      case CertificateType.insurance:
        return Icons.shield;
      case CertificateType.appraisal:
        return Icons.assessment;
    }
  }

  Color get color {
    switch (this) {
      case CertificateType.hallmark:
        return Colors.green;
      case CertificateType.assay:
        return Colors.blue;
      case CertificateType.valuation:
        return Colors.orange;
      case CertificateType.insurance:
        return Colors.purple;
      case CertificateType.appraisal:
        return Colors.teal;
    }
  }
}

/// Jewellery Certificate - Tracks certificates/certifications for jewellery items
@freezed
abstract class JewelleryCertificate with _$JewelleryCertificate {
  @HiveType(typeId: 71)
  const factory JewelleryCertificate({
    // Core identifiers (RID pattern: {tenantId}-{timestamp_ms}-{uuid_v4_short})
    @HiveField(0) required String id,
    @HiveField(1) required String tenantId,

    // Product/HUID link
    @HiveField(2) required String productId,
    @HiveField(3) String? huid, // Optional BIS HUID link
    // Certificate details
    @HiveField(4) required CertificateType type,
    @HiveField(5) required String issuer, // Issuing authority/organization
    @HiveField(6) required DateTime issueDate,
    @HiveField(7) DateTime? expiryDate,

    // Document reference
    @HiveField(8) String? documentUrl, // URL/path to certificate document
    // Valuation in integer paise (Requirement 1.1: integer paise for money)
    @HiveField(9) @Default(0) int valuationPaisa,

    // Additional info
    @HiveField(10) String? notes,
    @HiveField(11) @Default(true) bool isActive,

    // Metadata
    @HiveField(12) required DateTime createdAt,

    // Sync tracking
    @HiveField(13) @Default(true) bool synced,
    @HiveField(14) DateTime? lastSyncedAt,
    @HiveField(15) String? pendingOperation,
  }) = _JewelleryCertificate;

  const JewelleryCertificate._();

  factory JewelleryCertificate.fromJson(Map<String, dynamic> json) =>
      _$JewelleryCertificateFromJson(json);

  /// Display valuation in rupees
  double get displayValuation => valuationPaisa / 100;

  /// Whether the certificate has expired
  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  /// Whether the certificate is expiring soon (within 30 days)
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final daysUntilExpiry = expiryDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry > 0 && daysUntilExpiry <= 30;
  }

  /// Days until expiry (negative if expired)
  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }
}
