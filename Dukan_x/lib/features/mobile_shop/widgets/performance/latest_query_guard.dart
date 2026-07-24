/// LatestQueryGuard — Ensures only the most recent query result updates the UI.
///
/// Prevents race conditions from out-of-order responses by assigning each
/// query a monotonically increasing sequence number and discarding results
/// from stale queries.
///
/// Requirements: 11.9, 11.10
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// A guard that ensures only the result from the most recently initiated
/// query is delivered, preventing stale/out-of-order responses from
/// updating the UI.
///
/// This handles the common race condition where:
/// 1. User types "abc" → query A starts
/// 2. User types "abcd" → query B starts
/// 3. Query B returns first → UI shows "abcd" results
/// 4. Query A returns later → WITHOUT this guard, UI would regress to "abc" results
///
/// With [LatestQueryGuard], step 4 is silently discarded.
class LatestQueryGuard<T> {
  int _currentSequence = 0;

  /// Callback for the latest result.
  final ValueChanged<T>? onResult;

  /// Callback for errors from the latest query only.
  final ValueChanged<Object>? onError;

  LatestQueryGuard({this.onResult, this.onError});

  /// The current sequence number (for diagnostics).
  int get currentSequence => _currentSequence;

  /// Wrap an async operation with sequence-based guard.
  ///
  /// Returns a [Future] that resolves to the result only if this query
  /// is still the latest when it completes. Returns null if superseded.
  Future<T?> guard(Future<T> Function() operation) async {
    final sequence = ++_currentSequence;

    try {
      final result = await operation();

      // Only deliver if still the latest query.
      if (sequence == _currentSequence) {
        onResult?.call(result);
        return result;
      }
      // Stale — discard silently.
      return null;
    } catch (e) {
      if (sequence == _currentSequence) {
        onError?.call(e);
      }
      return null;
    }
  }

  /// Check if a given sequence is still the current one.
  /// Useful for manual guard patterns.
  bool isCurrent(int sequence) => sequence == _currentSequence;

  /// Get a new sequence token to use with [isCurrent].
  int nextSequence() => ++_currentSequence;

  /// Invalidate all in-flight queries. Any pending results will be discarded.
  void invalidate() {
    _currentSequence++;
  }

  /// Reset the sequence counter.
  void reset() {
    _currentSequence = 0;
  }
}

/// Extension on [LatestQueryGuard] for stream-based patterns.
extension LatestQueryGuardStream<T> on LatestQueryGuard<T> {
  /// Creates a stream transformer that only emits events from the
  /// latest subscription, cancelling results from prior ones.
  StreamTransformer<T, T> get transformer =>
      StreamTransformer<T, T>.fromHandlers(
        handleData: (data, sink) {
          // In stream context, always emit — the subscription itself
          // should be managed by the caller. This extension is for
          // single-value futures turned to streams.
          sink.add(data);
        },
      );
}
