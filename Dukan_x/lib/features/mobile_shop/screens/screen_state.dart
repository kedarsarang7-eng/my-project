/// MobileShop Screen State — Typed Loading/Empty/Error/Session States (Dart)
///
/// A sealed class hierarchy representing every possible screen state.
/// Screens use this instead of ad-hoc booleans, ensuring typed states
/// for loading, data, empty, error, and session-lost conditions.
///
/// Requirements: 5.9–5.11, 9.1–9.6, 11.7, 12.4
library;

import 'package:flutter/foundation.dart';

/// Typed screen state for any MobileShop list/detail screen.
///
/// Each state carries only the data relevant to that state, preventing
/// impossible combinations (e.g., data + error simultaneously).
@immutable
sealed class ScreenState<T> {
  const ScreenState();
}

/// Initial loading state — no data yet, no error.
final class ScreenLoading<T> extends ScreenState<T> {
  const ScreenLoading();
}

/// Data loaded successfully.
final class ScreenData<T> extends ScreenState<T> {
  final T data;
  final bool isStale;
  final DateTime? lastRefreshed;

  const ScreenData({
    required this.data,
    this.isStale = false,
    this.lastRefreshed,
  });
}

/// Data source returned zero results (confirmed empty, not an error).
final class ScreenEmpty<T> extends ScreenState<T> {
  /// Optional message describing why it's empty (e.g., filter applied).
  final String? message;

  const ScreenEmpty({this.message});
}

/// A typed error occurred while fetching data.
final class ScreenError<T> extends ScreenState<T> {
  final String errorCode;
  final String message;
  final bool isRetryable;
  final String? correlationId;

  const ScreenError({
    required this.errorCode,
    required this.message,
    this.isRetryable = false,
    this.correlationId,
  });
}

/// Session is missing or expired — no domain access allowed.
final class ScreenSessionLost<T> extends ScreenState<T> {
  final String message;

  const ScreenSessionLost({
    this.message = 'Your session has expired. Please sign in again.',
  });
}

/// Extension helpers for pattern-matching screen state in widgets.
extension ScreenStateX<T> on ScreenState<T> {
  bool get isLoading => this is ScreenLoading<T>;
  bool get hasData => this is ScreenData<T>;
  bool get isEmpty => this is ScreenEmpty<T>;
  bool get hasError => this is ScreenError<T>;
  bool get isSessionLost => this is ScreenSessionLost<T>;

  /// Returns data if in [ScreenData] state, null otherwise.
  T? get dataOrNull => switch (this) {
    ScreenData(:final data) => data,
    _ => null,
  };

  /// Pattern-match all states with a builder.
  R when<R>({
    required R Function() loading,
    required R Function(T data, bool isStale, DateTime? lastRefreshed) onData,
    required R Function(String? message) empty,
    required R Function(String code, String message, bool isRetryable) error,
    required R Function(String message) sessionLost,
  }) => switch (this) {
    ScreenLoading() => loading(),
    ScreenData(:final data, :final isStale, :final lastRefreshed) => onData(
      data,
      isStale,
      lastRefreshed,
    ),
    ScreenEmpty(:final message) => empty(message),
    ScreenError(:final errorCode, :final message, :final isRetryable) => error(
      errorCode,
      message,
      isRetryable,
    ),
    ScreenSessionLost(:final message) => sessionLost(message),
  };
}
