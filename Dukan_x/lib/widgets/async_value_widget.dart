import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

/// A reusable widget to handle Riverpod AsyncValue states globally.
/// Provides a consistent Loading (Shimmer) and Error (Fallback UI) experience.
class AsyncValueWidget<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T) data;
  final Widget? loading;
  final Widget Function(Object, StackTrace)? error;
  final VoidCallback? onRetry;
  final bool compactError;

  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
    this.onRetry,
    this.compactError = false,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => loading ?? const _DefaultShimmerLoading(),
      error: (e, st) {
        if (error != null) return error!(e, st);
        return _DefaultErrorWidget(
          error: e,
          onRetry: onRetry,
          compact: compactError,
        );
      },
    );
  }
}

class _DefaultShimmerLoading extends StatelessWidget {
  const _DefaultShimmerLoading();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Container(
            height: 72.0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
        ),
      ),
    );
  }
}

class _DefaultErrorWidget extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  const _DefaultErrorWidget({
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[400]),
              const SizedBox(height: 4),
              Text(
                'Failed to load data',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Retry', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: Colors.orange[600],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Data Unavailable',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Could not retrieve the required data. This could be due to a local database issue or network timeout.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                error.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.grey[800],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
