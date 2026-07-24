/// MobileShop Endpoint — Typed Endpoint Descriptor (Dart)
///
/// Describes an arbitrary MobileShop API endpoint with its method,
/// path, body, query parameters, and response parser.
///
/// Requirements: 6.3–6.4, 12.9
library;

import 'package:flutter/foundation.dart';

/// HTTP method for the endpoint.
enum HttpMethod { get, post, put, delete, patch }

/// A typed endpoint descriptor for the generic `command<T>` method.
///
/// Each endpoint declares its HTTP method, relative path, whether it is
/// a mutation (requires operation headers), and how to parse the response.
@immutable
class MobileEndpoint<T> {
  /// HTTP method.
  final HttpMethod method;

  /// Relative path under the base URL (e.g., `/units/{id}`).
  final String path;

  /// Whether this is a mutation (requires operation ID, fingerprint headers).
  final bool isMutation;

  /// Request body as JSON-encodable map (null for GET/DELETE).
  final Map<String, dynamic>? body;

  /// Query parameters for GET/list requests.
  final Map<String, String>? queryParams;

  /// Operation ID for mutations.
  final String? operationId;

  /// Mutation fingerprint for mutations.
  final String? mutationFingerprint;

  /// Expected entity versions for optimistic concurrency.
  final Map<String, int>? expectedVersions;

  /// Data model version for mutation body.
  final int? dataModelVersion;

  /// Parser to convert JSON response body to typed result.
  final T Function(Map<String, dynamic> json) parser;

  const MobileEndpoint({
    required this.method,
    required this.path,
    required this.isMutation,
    this.body,
    this.queryParams,
    this.operationId,
    this.mutationFingerprint,
    this.expectedVersions,
    this.dataModelVersion,
    required this.parser,
  });
}
