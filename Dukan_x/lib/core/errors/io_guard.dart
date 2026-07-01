// IoGuard — central wrapper for I/O-heavy service calls.
//
// Per `bugfix.md` clause 2.12, every I/O call site (HTTP, file, PDF
// render, scanner, camera, print) must:
//   * never let a raw stack trace escape to the user,
//   * never freeze the UI,
//   * surface a localized message via the existing toast/snackbar
//     helpers, and
//   * give the caller a clear retry / fallback hook.
//
// `IoGuard.run` wraps any `Future<T>` operation, captures the exception,
// records a structured log entry, and rethrows a typed `IoFailure` so
// callers can pattern-match on it. Callers that previously did
//
//     final pdf = await doc.save();
//
// switch to
//
//     final pdf = await IoGuard.run(
//       op: () => doc.save(),
//       label: 'thermal_print.render',
//       userMessage: 'Could not render the receipt. Please try again.',
//     );
//
// `userMessage` is intentionally a plain string here — services should
// pass a localized string from `AppLocalizations` when they have access
// to a `BuildContext`. When called from non-UI code the fallback is a
// short, user-safe English string.

import 'dart:async';
import 'dart:developer' as developer;

/// Typed failure surface for any I/O wrapped by `IoGuard.run`. Callers
/// catch `IoFailure` to display the user message, log structured fields,
/// or trigger a retry.
class IoFailure implements Exception {
  IoFailure({
    required this.label,
    required this.userMessage,
    required this.cause,
    required this.stackTrace,
  });

  /// Stable label for the failing operation, e.g. `thermal_print.render`.
  /// Used as the log tag and as a programmatic identifier.
  final String label;

  /// Localized, user-safe message. Never contains raw stack traces.
  final String userMessage;

  /// The original error or exception that was thrown.
  final Object cause;

  /// Captured stack trace for structured logs.
  final StackTrace stackTrace;

  @override
  String toString() => 'IoFailure($label): $userMessage (cause: $cause)';
}

/// Wraps an async I/O operation, logs structured failures, and rethrows
/// a typed `IoFailure`. The original exception is preserved on
/// `IoFailure.cause` so callers can branch on `TimeoutException`,
/// `FileSystemException`, etc. when needed.
class IoGuard {
  IoGuard._();

  static Future<T> run<T>({
    required Future<T> Function() op,
    required String label,
    required String userMessage,
  }) async {
    try {
      return await op();
    } catch (e, st) {
      developer.log(
        'I/O failure in $label: $e',
        name: 'IoGuard',
        error: e,
        stackTrace: st,
      );
      throw IoFailure(
        label: label,
        userMessage: userMessage,
        cause: e,
        stackTrace: st,
      );
    }
  }

  /// Variant that swallows the failure and returns a fallback value.
  /// Use only when the operation is non-critical (e.g., optional cache
  /// hydration). The structured log is still emitted so the failure is
  /// observable.
  static Future<T> runOrElse<T>({
    required Future<T> Function() op,
    required String label,
    required T fallback,
  }) async {
    try {
      return await op();
    } catch (e, st) {
      developer.log(
        'I/O failure (suppressed) in $label: $e',
        name: 'IoGuard',
        error: e,
        stackTrace: st,
      );
      return fallback;
    }
  }
}
