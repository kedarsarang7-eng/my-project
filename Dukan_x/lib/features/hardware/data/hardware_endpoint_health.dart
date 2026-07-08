// ============================================================================
// HARDWARE ENDPOINT HEALTH — Version Negotiation & Availability Detection
// ============================================================================
// Solves HARDWARE-004: When a hardware-specific endpoint returns 404/501/503,
// distinguish "endpoint unavailable" from "no data" (empty results).
//
// Previously, a missing endpoint would surface as an empty list or a generic
// error message indistinguishable from "zero records." Now the UI can render
// a distinct "endpoint unavailable" widget.
//
// Preservation: When endpoints ARE deployed and return 200, this utility is
// invisible — the success path is unchanged.
// ============================================================================

import 'hardware_ops_repository.dart';

/// The health/availability status of a hardware API endpoint.
enum EndpointHealthStatus {
  /// Endpoint responded successfully (2xx). Data may be empty but the
  /// endpoint itself is deployed and reachable.
  available,

  /// Endpoint returned zero records with a 2xx response. The endpoint is
  /// deployed but there is no data to show.
  emptyData,

  /// Endpoint returned 404, 501, or 503 — the endpoint is not deployed,
  /// not implemented, or temporarily unavailable. This is a distinct state
  /// from "empty data" and should render a different UI.
  unavailable,

  /// Endpoint returned a non-availability error (e.g., 500, 400, 422).
  /// This is a transient or logic error, not an endpoint-unavailable state.
  error,
}

/// Utility for classifying hardware endpoint responses into distinct
/// availability states so the UI can render appropriate feedback.
class HardwareEndpointHealth {
  HardwareEndpointHealth._();

  /// HTTP status codes that indicate the endpoint itself is unavailable
  /// (not deployed, not implemented, or the service is down).
  static const Set<int> _unavailableStatusCodes = {404, 501, 503};

  /// Returns `true` if the given [exception] indicates that the hardware
  /// endpoint is unavailable (as opposed to a data error or empty result).
  static bool isEndpointUnavailable(HardwareOpsException exception) {
    final code = exception.statusCode;
    if (code == null) return false;
    return _unavailableStatusCodes.contains(code);
  }

  /// Classify a [HardwareOpsException] into an [EndpointHealthStatus].
  static EndpointHealthStatus classifyException(
    HardwareOpsException exception,
  ) {
    if (isEndpointUnavailable(exception)) {
      return EndpointHealthStatus.unavailable;
    }
    return EndpointHealthStatus.error;
  }

  /// Given a successful load result (no exception), classify based on
  /// whether data is empty or populated.
  static EndpointHealthStatus classifySuccess<T>(List<T> data) {
    return data.isEmpty
        ? EndpointHealthStatus.emptyData
        : EndpointHealthStatus.available;
  }

  /// User-facing message for the "unavailable" state.
  static String unavailableMessage(String sectionName) {
    return '$sectionName endpoint is not available. '
        'This feature may not be deployed yet for your account.';
  }

  /// User-facing short label for the unavailable badge.
  static const String unavailableBadgeLabel = 'Endpoint Unavailable';
}
