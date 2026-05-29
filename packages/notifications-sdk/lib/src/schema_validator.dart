// ============================================================================
// SchemaValidator — client-side Event_Contract validation.
// ----------------------------------------------------------------------------
// Loads the canonical schema bundled at packages/notifications-sdk/
// event-contract.schema.json and validates every emit() payload before the
// SDK sends it on the wire (REQ 8.1, 8.7, 3.6).
//
// The constructor accepts a raw schema string so consumers (Flutter app, Dart
// CLI, server-side Dart) can load the asset using whichever asset-loading
// mechanism fits their environment. A `loadFromFile` convenience is provided
// for non-Flutter consumers.
// ============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';

/// One field-level error produced by JSON Schema validation.
///
/// Kept lightweight so callers don't need to depend on the underlying
/// `json_schema` package types.
class SchemaError {
  /// JSON pointer to the offending location, e.g. `/recipients/0/role`.
  final String path;

  /// Human-readable message from the underlying validator.
  final String message;

  const SchemaError({required this.path, required this.message});

  @override
  String toString() => '$path: $message';
}

/// Result of a single validate call.
class SchemaValidationResult {
  final bool isValid;
  final List<SchemaError> errors;

  const SchemaValidationResult({required this.isValid, required this.errors});

  bool get hasErrors => errors.isNotEmpty;
}

/// Thrown by [NotificationsSdk.emit] when client-side validation fails.
///
/// The schema-invalid event is NOT enqueued and NOT buffered to the outbox —
/// this matches REQ 3.6 / 8.7: invalid publishes are rejected with a
/// structured validation error and the system persists nothing.
class SchemaValidationException implements Exception {
  final List<SchemaError> errors;

  const SchemaValidationException(this.errors);

  @override
  String toString() {
    final joined = errors.map((e) => e.toString()).join('; ');
    return 'SchemaValidationException: $joined';
  }
}

/// Wraps a compiled JSON Schema (Draft 2020-12) for the Event_Contract.
class SchemaValidator {
  final JsonSchema _schema;

  SchemaValidator._(this._schema);

  /// Build a validator from the raw schema JSON string. Use this when the
  /// schema text is loaded via a Flutter asset bundle or HTTP fetch.
  factory SchemaValidator.fromString(String schemaJson) {
    final parsed = jsonDecode(schemaJson);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException(
        'Event_Contract schema must decode to a JSON object',
      );
    }
    final schema = JsonSchema.create(
      parsed,
      schemaVersion: SchemaVersion.draft2020_12,
    );
    return SchemaValidator._(schema);
  }

  /// Build a validator from a file path. Convenient for plain-Dart hosts that
  /// can hit the filesystem (tests, CLI tools, server-side adapters).
  factory SchemaValidator.fromFile(String path) {
    final raw = File(path).readAsStringSync();
    return SchemaValidator.fromString(raw);
  }

  /// Validate an already-JSON-encoded event payload.
  SchemaValidationResult validate(Map<String, dynamic> json) {
    final result = _schema.validate(json);
    if (result.isValid) {
      return const SchemaValidationResult(isValid: true, errors: []);
    }
    final errors = result.errors
        .map((e) => SchemaError(
              path: e.instancePath.isEmpty ? '/' : e.instancePath,
              message: e.message,
            ))
        .toList();
    return SchemaValidationResult(isValid: false, errors: errors);
  }

  /// Validate or throw. Used inline by [NotificationsSdk.emit].
  void validateOrThrow(Map<String, dynamic> json) {
    final result = validate(json);
    if (!result.isValid) {
      throw SchemaValidationException(result.errors);
    }
  }
}
