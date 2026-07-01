import 'package:flutter/widgets.dart';

/// SM-03 FIX: Mixin for safe async operations in StatefulWidget State classes.
///
/// Provides [safeSetState] and [guardContext] to prevent:
/// - setState() called on disposed widget crashes
/// - BuildContext used after widget is unmounted
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with SafeAsyncStateMixin {
///   Future<void> _loadData() async {
///     final data = await api.fetchData();
///     safeSetState(() => _data = data);
///   }
///
///   Future<void> _onSubmit() async {
///     final result = await api.submit();
///     guardContext((context) {
///       ScaffoldMessenger.of(context).showSnackBar(...);
///       Navigator.of(context).pop(result);
///     });
///   }
/// }
/// ```
mixin SafeAsyncStateMixin<T extends StatefulWidget> on State<T> {
  /// Calls [setState] only if the widget is still mounted.
  /// Prevents "setState() called after dispose()" crashes.
  void safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  /// Executes [callback] with the current [BuildContext] only if mounted.
  /// Prevents "Looking up a deactivated widget's ancestor" crashes.
  ///
  /// Returns true if the callback was executed, false if widget was unmounted.
  bool guardContext(void Function(BuildContext context) callback) {
    if (mounted) {
      callback(context);
      return true;
    }
    return false;
  }

  /// Async version of [guardContext] that awaits the callback.
  Future<bool> guardContextAsync(
    Future<void> Function(BuildContext context) callback,
  ) async {
    if (mounted) {
      await callback(context);
      return true;
    }
    return false;
  }
}
