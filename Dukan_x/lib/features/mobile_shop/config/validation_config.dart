/// Validation Precedence Configuration (Flutter)
///
/// Defines the order in which validation rules fire and associated field codes.
/// The same precedence is shared by UI, repository, synchronization, and backend.
///
/// Requirements: 3.2, 3.12
library;

import 'package:flutter/foundation.dart';

/// A single validation rule with priority ordering.
@immutable
class ValidationPrecedenceRule {
  /// Stable rule identifier.
  final String code;

  /// Evaluation order (ascending — lower fires first).
  final int priority;

  /// Human-readable description.
  final String description;

  /// Associated input field(s) for field-level error association.
  final List<String> fields;

  const ValidationPrecedenceRule({
    required this.code,
    required this.priority,
    required this.description,
    required this.fields,
  });
}

/// Typed validation configuration.
@immutable
class ValidationConfig {
  /// Ordered validation rules for IMEI submission.
  final List<ValidationPrecedenceRule> imeiValidation;

  /// Ordered validation rules for device-sale submission.
  final List<ValidationPrecedenceRule> saleMutation;

  /// Ordered validation rules for second-hand intake.
  final List<ValidationPrecedenceRule> secondHandIntake;

  /// Ordered validation rules for service-job submission.
  final List<ValidationPrecedenceRule> serviceJob;

  /// Characters treated as presentation separators (removed during normalization).
  final List<String> imeiSeparators;

  /// Required IMEI digit length after normalization.
  final int imeiLength;

  const ValidationConfig({
    required this.imeiValidation,
    required this.saleMutation,
    required this.secondHandIntake,
    required this.serviceJob,
    required this.imeiSeparators,
    required this.imeiLength,
  });
}

/// Default validation configuration.
const kValidationConfig = ValidationConfig(
  imeiSeparators: ['-', ' ', '.'],
  imeiLength: 15,
  imeiValidation: [
    ValidationPrecedenceRule(
      code: 'IMEI_REQUIRED',
      priority: 10,
      description: 'IMEI field must not be empty',
      fields: ['imei'],
    ),
    ValidationPrecedenceRule(
      code: 'IMEI_FORMAT',
      priority: 20,
      description: 'Must contain only ASCII digits after separator removal',
      fields: ['imei'],
    ),
    ValidationPrecedenceRule(
      code: 'IMEI_LENGTH',
      priority: 30,
      description: 'Must be exactly 15 digits after normalization',
      fields: ['imei'],
    ),
    ValidationPrecedenceRule(
      code: 'IMEI_LUHN',
      priority: 40,
      description: 'Must pass Luhn checksum',
      fields: ['imei'],
    ),
    ValidationPrecedenceRule(
      code: 'IMEI_UNIQUENESS',
      priority: 50,
      description: 'Must be unique within the tenant scope',
      fields: ['imei'],
    ),
    ValidationPrecedenceRule(
      code: 'IMEI_LIFECYCLE',
      priority: 60,
      description: 'Must be in a saleable lifecycle state',
      fields: ['imei'],
    ),
  ],
  saleMutation: [
    ValidationPrecedenceRule(
      code: 'AUTH_REQUIRED',
      priority: 1,
      description: 'Authentication must be valid',
      fields: [],
    ),
    ValidationPrecedenceRule(
      code: 'BUSINESS_TYPE_REQUIRED',
      priority: 2,
      description: 'Business type must be mobile_shop',
      fields: [],
    ),
    ValidationPrecedenceRule(
      code: 'PERMISSION_REQUIRED',
      priority: 3,
      description: 'Caller must have sale permission',
      fields: [],
    ),
    ValidationPrecedenceRule(
      code: 'TENANT_CONTEXT',
      priority: 4,
      description: 'Tenant context must resolve',
      fields: [],
    ),
    ValidationPrecedenceRule(
      code: 'SCHEMA_VALID',
      priority: 5,
      description: 'Request schema must validate',
      fields: [],
    ),
    ValidationPrecedenceRule(
      code: 'OPERATION_ID_PRESENT',
      priority: 10,
      description: 'Operation ID must be present',
      fields: ['operationId'],
    ),
    ValidationPrecedenceRule(
      code: 'FINGERPRINT_VALID',
      priority: 11,
      description: 'Mutation fingerprint must be present',
      fields: ['mutationFingerprint'],
    ),
    ValidationPrecedenceRule(
      code: 'INVOICE_VALID',
      priority: 20,
      description: 'Invoice draft must pass validation',
      fields: ['invoice'],
    ),
    ValidationPrecedenceRule(
      code: 'DEVICE_LINES_VALID',
      priority: 30,
      description: 'Device lines must be non-empty with valid IMEIs',
      fields: ['deviceLines'],
    ),
    ValidationPrecedenceRule(
      code: 'VERSIONS_EXPECTED',
      priority: 40,
      description: 'Expected entity versions must be present',
      fields: ['expectedVersions'],
    ),
    ValidationPrecedenceRule(
      code: 'LIFECYCLE_PRECONDITION',
      priority: 50,
      description: 'All IMEIs must be in allowed lifecycle states',
      fields: ['deviceLines'],
    ),
  ],
  secondHandIntake: [
    ValidationPrecedenceRule(
      code: 'AUTH_REQUIRED',
      priority: 1,
      description: 'Authentication must be valid',
      fields: [],
    ),
    ValidationPrecedenceRule(
      code: 'IMEI_VALID',
      priority: 10,
      description: 'Normalized IMEI must pass all checks',
      fields: ['imei'],
    ),
    ValidationPrecedenceRule(
      code: 'SELLER_IDENTITY',
      priority: 20,
      description: 'Seller identity reference must be present',
      fields: ['sellerId'],
    ),
    ValidationPrecedenceRule(
      code: 'OWNERSHIP_EVIDENCE',
      priority: 30,
      description: 'Ownership evidence status must be present',
      fields: ['ownershipEvidence'],
    ),
    ValidationPrecedenceRule(
      code: 'INSPECTION_RESULT',
      priority: 40,
      description: 'Inspection result must be recorded',
      fields: ['inspectionResult'],
    ),
    ValidationPrecedenceRule(
      code: 'VALUATION_APPROVAL',
      priority: 50,
      description: 'Valuation must be approved',
      fields: ['valuation'],
    ),
    ValidationPrecedenceRule(
      code: 'POLICY_CHECK',
      priority: 60,
      description: 'Device must not be prohibited by documented policy',
      fields: ['imei'],
    ),
    ValidationPrecedenceRule(
      code: 'LIFECYCLE_COMPATIBLE',
      priority: 70,
      description: 'IMEI must not be active in incompatible state',
      fields: ['imei'],
    ),
  ],
  serviceJob: [
    ValidationPrecedenceRule(
      code: 'AUTH_REQUIRED',
      priority: 1,
      description: 'Authentication must be valid',
      fields: [],
    ),
    ValidationPrecedenceRule(
      code: 'UNIT_OWNED',
      priority: 10,
      description: 'IMEI unit must be tenant-owned',
      fields: ['unitId'],
    ),
    ValidationPrecedenceRule(
      code: 'CUSTOMER_VALID',
      priority: 20,
      description: 'Customer reference must be valid',
      fields: ['customerId'],
    ),
    ValidationPrecedenceRule(
      code: 'FAULT_DESCRIBED',
      priority: 30,
      description: 'Fault description must be present',
      fields: ['fault'],
    ),
    ValidationPrecedenceRule(
      code: 'ESTIMATE_VALID',
      priority: 40,
      description: 'Estimate must be a valid minor-unit amount',
      fields: ['estimateMinorUnits'],
    ),
    ValidationPrecedenceRule(
      code: 'TECHNICIAN_ASSIGNED',
      priority: 50,
      description: 'Technician reference must be present',
      fields: ['technicianId'],
    ),
    ValidationPrecedenceRule(
      code: 'WARRANTY_STATUS',
      priority: 60,
      description: 'Warranty status must be determined',
      fields: ['warrantyStatus'],
    ),
  ],
);
