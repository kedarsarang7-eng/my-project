/// Model Version Configuration (Flutter)
///
/// Defines supported data-model versions and API versions for the client.
/// Used to determine compatibility with backend responses and queued mutations.
///
/// Requirements: 6.20, 6.33–6.36
library;

import 'package:flutter/foundation.dart';

/// Model version configuration.
@immutable
class ModelVersionConfig {
  /// Current data model version the client writes.
  final int currentVersion;

  /// Minimum data model version the client can read.
  final int minSupportedVersion;

  /// Maximum data model version the client supports.
  final int maxSupportedVersion;

  /// Minimum API version the client sends.
  final int minSupportedApiVersion;

  /// Current API version the client sends.
  final int currentApiVersion;

  /// Queued mutations older than this version delta are rejected on push.
  final int queuedMutationMaxAge;

  const ModelVersionConfig({
    required this.currentVersion,
    required this.minSupportedVersion,
    required this.maxSupportedVersion,
    required this.minSupportedApiVersion,
    required this.currentApiVersion,
    required this.queuedMutationMaxAge,
  });

  /// Whether [version] is within the supported read window.
  bool isVersionSupported(int version) {
    return version >= minSupportedVersion && version <= maxSupportedVersion;
  }

  /// Whether a queued mutation at [mutationVersion] is still valid.
  bool isMutationVersionValid(int mutationVersion) {
    return (currentVersion - mutationVersion).abs() <= queuedMutationMaxAge;
  }
}

/// Default model version configuration.
const kModelVersionConfig = ModelVersionConfig(
  currentVersion: 1,
  minSupportedVersion: 1,
  maxSupportedVersion: 1,
  minSupportedApiVersion: 1,
  currentApiVersion: 1,
  queuedMutationMaxAge: 1,
);
