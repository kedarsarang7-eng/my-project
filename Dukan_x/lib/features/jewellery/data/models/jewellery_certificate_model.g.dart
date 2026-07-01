// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jewellery_certificate_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_JewelleryCertificate _$JewelleryCertificateFromJson(
  Map<String, dynamic> json,
) => _JewelleryCertificate(
  id: json['id'] as String,
  tenantId: json['tenantId'] as String,
  productId: json['productId'] as String,
  huid: json['huid'] as String?,
  type: $enumDecode(_$CertificateTypeEnumMap, json['type']),
  issuer: json['issuer'] as String,
  issueDate: DateTime.parse(json['issueDate'] as String),
  expiryDate: json['expiryDate'] == null
      ? null
      : DateTime.parse(json['expiryDate'] as String),
  documentUrl: json['documentUrl'] as String?,
  valuationPaisa: (json['valuationPaisa'] as num?)?.toInt() ?? 0,
  notes: json['notes'] as String?,
  isActive: json['isActive'] as bool? ?? true,
  createdAt: DateTime.parse(json['createdAt'] as String),
  synced: json['synced'] as bool? ?? true,
  lastSyncedAt: json['lastSyncedAt'] == null
      ? null
      : DateTime.parse(json['lastSyncedAt'] as String),
  pendingOperation: json['pendingOperation'] as String?,
);

Map<String, dynamic> _$JewelleryCertificateToJson(
  _JewelleryCertificate instance,
) => <String, dynamic>{
  'id': instance.id,
  'tenantId': instance.tenantId,
  'productId': instance.productId,
  'huid': instance.huid,
  'type': _$CertificateTypeEnumMap[instance.type]!,
  'issuer': instance.issuer,
  'issueDate': instance.issueDate.toIso8601String(),
  'expiryDate': instance.expiryDate?.toIso8601String(),
  'documentUrl': instance.documentUrl,
  'valuationPaisa': instance.valuationPaisa,
  'notes': instance.notes,
  'isActive': instance.isActive,
  'createdAt': instance.createdAt.toIso8601String(),
  'synced': instance.synced,
  'lastSyncedAt': instance.lastSyncedAt?.toIso8601String(),
  'pendingOperation': instance.pendingOperation,
};

const _$CertificateTypeEnumMap = {
  CertificateType.hallmark: 'hallmark',
  CertificateType.assay: 'assay',
  CertificateType.valuation: 'valuation',
  CertificateType.insurance: 'insurance',
  CertificateType.appraisal: 'appraisal',
};
