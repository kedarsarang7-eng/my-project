// ============================================================================
// DECORATION & CATERING — connectivity-aware error copy (Requirement 2.6 AC7)
// ============================================================================
// WHERE a write operation (booking/invoice create or update) is attempted
// while offline, the DC vertical keeps its EXISTING try/catch UI error
// path — no offline write queuing, optimistic writes, or conflict
// resolution is added (explicitly out of scope, AC8). The only change is
// wording: when the underlying error clearly indicates a connectivity
// failure, the displayed message says so instead of a generic
// "Failed to save booking: Exception: ..." string.
//
// `DcRepository`'s `_ensureSuccess` already surfaces `ApiResponse
// .userMessage` (which itself contains connectivity-specific wording such
// as "No internet connection...", "Network error...", "Request timed
// out...", "Connection failed...") for network-layer failures. This helper
// pattern-matches on that same wording (plus the raw `SocketException`/
// `TimeoutException` types that can otherwise reach a UI catch block
// unwrapped) so any DC write-path catch block can prefix its message
// consistently.
// ============================================================================

import 'dart:async';
import 'dart:io';

/// Returns `true` if [error] appears to represent a connectivity failure
/// (as opposed to a validation error, a business-rule rejection, or a
/// genuine backend/server error).
bool isDcConnectivityError(Object error) {
  if (error is SocketException || error is TimeoutException) return true;
  final msg = error.toString().toLowerCase();
  return msg.contains('no internet connection') ||
      msg.contains('network error') ||
      msg.contains('request timed out') ||
      msg.contains('connection failed') ||
      msg.contains('connection timed out') ||
      msg.contains('socketexception') ||
      msg.contains('timeoutexception');
}

/// Builds a user-facing error message for [action] (e.g. `'save booking'`,
/// `'save invoice'`) given the caught [error], mentioning connectivity
/// explicitly when [isDcConnectivityError] identifies the error as such.
String dcWriteErrorMessage(String action, Object error) {
  if (isDcConnectivityError(error)) {
    return 'Could not $action — check your internet connection and try '
        'again.';
  }
  return 'Failed to $action: $error';
}
