/// DebouncedSearchController — Reusable debounced text search with latest-query-wins.
///
/// Debounces text input by a configurable delay, cancels stale queries,
/// and only processes the latest query. Integrates with [SearchBounds]
/// from the documented configuration.
///
/// Requirements: 11.9, 6.14
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../config/bounds_config.dart';

/// Callback that executes the actual search/filter logic for a query.
typedef SearchExecutor<T> = Future<T> Function(String query);

/// Reusable controller that debounces text input, cancels stale queries,
/// and ensures only the latest query result is delivered (latest-query-wins).
///
/// Usage:
/// ```dart
/// final controller = DebouncedSearchController<List<Item>>(
///   executor: (query) => repository.search(query),
///   onResult: (results) => setState(() => _items = results),
/// );
/// // In TextField.onChanged:
/// controller.onQueryChanged(value);
/// ```
class DebouncedSearchController<T> {
  /// The search executor that runs the actual query.
  final SearchExecutor<T> executor;

  /// Callback invoked with results from the latest query only.
  final ValueChanged<T> onResult;

  /// Callback invoked when search starts (for loading indicators).
  final VoidCallback? onSearchStart;

  /// Callback invoked on error.
  final ValueChanged<Object>? onError;

  /// Debounce duration. Defaults to the value from [SearchBounds.debounceMs].
  final Duration debounceDuration;

  /// Minimum query length before executing. Shorter queries clear results.
  final int minQueryLength;

  /// Callback invoked when query is cleared or below minimum length.
  final VoidCallback? onCleared;

  Timer? _debounceTimer;
  int _querySequence = 0;
  String _lastExecutedQuery = '';

  DebouncedSearchController({
    required this.executor,
    required this.onResult,
    this.onSearchStart,
    this.onError,
    this.onCleared,
    Duration? debounceDuration,
    int? minQueryLength,
  }) : debounceDuration =
           debounceDuration ??
           Duration(milliseconds: kBoundsConfig.search.debounceMs),
       minQueryLength = minQueryLength ?? kBoundsConfig.search.minQueryLength;

  /// The last query that was actually executed.
  String get lastExecutedQuery => _lastExecutedQuery;

  /// Whether a debounce timer is currently pending.
  bool get isPending => _debounceTimer?.isActive ?? false;

  /// Called on every text change. Debounces and applies latest-query-wins.
  void onQueryChanged(String query) {
    _debounceTimer?.cancel();

    final trimmed = query.trim();

    // Clear immediately if below minimum length.
    if (trimmed.length < minQueryLength) {
      _querySequence++;
      _lastExecutedQuery = '';
      onCleared?.call();
      return;
    }

    // Skip if unchanged from last executed query (avoids rescans — Req 11.11).
    if (trimmed == _lastExecutedQuery) return;

    _debounceTimer = Timer(debounceDuration, () {
      _executeQuery(trimmed);
    });
  }

  /// Force-execute a query immediately, bypassing debounce.
  void executeImmediate(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < minQueryLength) {
      _querySequence++;
      _lastExecutedQuery = '';
      onCleared?.call();
      return;
    }
    _executeQuery(trimmed);
  }

  /// Cancel any pending debounce without executing.
  void cancel() {
    _debounceTimer?.cancel();
  }

  /// Reset the controller state entirely.
  void reset() {
    _debounceTimer?.cancel();
    _querySequence++;
    _lastExecutedQuery = '';
  }

  /// Dispose of timers. Call from widget's dispose().
  void dispose() {
    _debounceTimer?.cancel();
  }

  Future<void> _executeQuery(String query) async {
    final sequence = ++_querySequence;
    _lastExecutedQuery = query;
    onSearchStart?.call();

    try {
      final result = await executor(query);
      // Latest-query-wins: only deliver if this is still the latest query.
      if (sequence == _querySequence) {
        onResult(result);
      }
    } catch (e) {
      if (sequence == _querySequence) {
        onError?.call(e);
      }
    }
  }
}
