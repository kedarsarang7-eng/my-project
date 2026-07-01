// ============================================================================
// LOADING STATES (Async Value Pattern)
// ============================================================================
// Unified loading state system to prevent black screens.
// Similar to Riverpod's AsyncValue but framework-agnostic.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import '../error/error_handler.dart';

/// Sealed class for async states
/// Ensures ALL possible states are handled (loading, data, error)
sealed class AsyncValue<T> {
  const AsyncValue();

  /// Whether this is a loading state
  bool get isLoading => this is AsyncLoading<T>;

  /// Whether this has data
  bool get hasData => this is AsyncData<T>;

  /// Whether this is an error state
  bool get hasError => this is AsyncError<T>;

  /// Get data or null
  T? get dataOrNull {
    if (this is AsyncData<T>) {
      return (this as AsyncData<T>).data;
    }
    return null;
  }

  /// Get error or null
  AppError? get errorOrNull {
    if (this is AsyncError<T>) {
      return (this as AsyncError<T>).error;
    }
    return null;
  }

  /// Map to another type
  R when<R>({
    required R Function() loading,
    required R Function(T value) onData,
    required R Function(AppError err) onError,
  }) {
    return switch (this) {
      AsyncLoading<T>() => loading(),
      AsyncData<T> asyncData => onData(asyncData.data),
      AsyncError<T> asyncError => onError(asyncError.error),
    };
  }

  /// Map with optional handlers (uses defaults if not provided)
  R maybeWhen<R>({
    R Function()? loading,
    R Function(T value)? data,
    R Function(AppError err)? error,
    required R Function() orElse,
  }) {
    return switch (this) {
      AsyncLoading<T>() => loading?.call() ?? orElse(),
      AsyncData<T> asyncData => data?.call(asyncData.data) ?? orElse(),
      AsyncError<T> asyncError => error?.call(asyncError.error) ?? orElse(),
    };
  }
}

/// Loading state
class AsyncLoading<T> extends AsyncValue<T> {
  final String? message;
  final double? progress;

  const AsyncLoading({this.message, this.progress});
}

/// Data loaded successfully
class AsyncData<T> extends AsyncValue<T> {
  final T data;

  const AsyncData(this.data);
}

/// Error occurred
class AsyncError<T> extends AsyncValue<T> {
  final AppError error;
  final T? previousData; // Keep previous data for optimistic UI

  const AsyncError(this.error, {this.previousData});
}

// ============================================================================
// WIDGET BUILDERS
// ============================================================================

/// Widget builder that NEVER shows black screen
/// Always provides a visual state for every possibility
Widget asyncBuilder<T>({
  required AsyncValue<T> state,
  required Widget Function(T data) builder,
  Widget? loading,
  Widget Function(AppError error)? error,
  Widget Function(String message, double? progress)? loadingWithProgress,
}) {
  return switch (state) {
    AsyncLoading(:final message, :final progress) =>
      loadingWithProgress?.call(message ?? 'Loading...', progress) ??
          loading ??
          const DefaultLoadingWidget(),
    AsyncData(:final data) => builder(data),
    AsyncError<T> asyncError =>
      asyncError.previousData != null
          ? builder(
              asyncError.previousData as T,
            ) // Show stale data with error indicator
          : error?.call(asyncError.error) ??
                DefaultErrorWidget(error: asyncError.error),
  };
}

/// AnimatedSwitcher-based async builder for smooth transitions
class AsyncBuilderWidget<T> extends StatelessWidget {
  final AsyncValue<T> state;
  final Widget Function(T data) builder;
  final Widget? loading;
  final Widget Function(AppError error)? error;
  final Duration transitionDuration;

  const AsyncBuilderWidget({
    super.key,
    required this.state,
    required this.builder,
    this.loading,
    this.error,
    this.transitionDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: transitionDuration,
      child: asyncBuilder(
        state: state,
        builder: builder,
        loading: loading,
        error: error,
      ),
    );
  }
}

// ============================================================================
// DEFAULT WIDGETS
// ============================================================================

/// Default loading widget with shimmer effect
class DefaultLoadingWidget extends StatelessWidget {
  final String? message;

  const DefaultLoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: theme.colorScheme.primary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Default error widget with retry option
class DefaultErrorWidget extends StatelessWidget {
  final AppError error;
  final VoidCallback? onRetry;

  const DefaultErrorWidget({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmer loading placeholder for lists
class ShimmerLoadingList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const ShimmerLoadingList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 72,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ShimmerPlaceholder(height: itemHeight),
      ),
    );
  }
}

/// Single shimmer placeholder box
class ShimmerPlaceholder extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerPlaceholder({
    super.key,
    this.width,
    this.height = 20,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(1.0 + 2.0 * _controller.value, 0),
              colors: isDark
                  ? [
                      Colors.grey.shade800,
                      Colors.grey.shade700,
                      Colors.grey.shade800,
                    ]
                  : [
                      Colors.grey.shade200,
                      Colors.grey.shade100,
                      Colors.grey.shade200,
                    ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// UTILITY EXTENSIONS
// ============================================================================

extension FutureToAsyncValue<T> on Future<T> {
  /// Convert a Future to AsyncValue stream
  Stream<AsyncValue<T>> toAsyncValueStream() async* {
    yield const AsyncLoading();
    try {
      final data = await this;
      yield AsyncData(data);
    } catch (e, stack) {
      yield AsyncError(ErrorHandler.createAppError(e, stack));
    }
  }
}
