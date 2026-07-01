// ============================================================================
// STANDARDIZED LOADING STATES - Unified Loading UI Components (P1 FIX)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/futuristic_colors.dart';

/// Loading state types
enum LoadingState {
  initial,
  loading,
  success,
  error,
  empty,
}

/// Standardized loading state widget
class AsyncStateWrapper<T> extends StatelessWidget {
  final AsyncSnapshot<T> snapshot;
  final Widget Function(T data) builder;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? emptyWidget;
  final VoidCallback? onRetry;
  final String? emptyMessage;
  final String? errorMessage;

  const AsyncStateWrapper({
    super.key,
    required this.snapshot,
    required this.builder,
    this.loadingWidget,
    this.errorWidget,
    this.emptyWidget,
    this.onRetry,
    this.emptyMessage,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return loadingWidget ?? const AppLoadingIndicator();
    }

    if (snapshot.hasError) {
      return errorWidget ?? AppErrorState(
        message: errorMessage ?? snapshot.error.toString(),
        onRetry: onRetry,
      );
    }

    if (!snapshot.hasData || snapshot.data == null) {
      return emptyWidget ?? AppEmptyState(
        message: emptyMessage ?? 'No data available',
      );
    }

    // Handle empty collections
    if (snapshot.data is List && (snapshot.data as List).isEmpty) {
      return emptyWidget ?? AppEmptyState(
        message: emptyMessage ?? 'No items found',
      );
    }

    return builder(snapshot.data as T);
  }
}

/// Standard app loading indicator with branding
class AppLoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;
  final bool fullscreen;

  const AppLoadingIndicator({
    super.key,
    this.message,
    this.size = 48,
    this.fullscreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              FuturisticColors.accent1,
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: TextStyle(
              fontSize: 14,
              color: FuturisticColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (fullscreen) {
      return Container(
        color: FuturisticColors.background,
        child: Center(child: content),
      );
    }

    return Center(child: content);
  }
}

/// Skeleton loading widget with shimmer effect
class SkeletonLoader extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsets padding;
  final bool enabled;

  const SkeletonLoader({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 72,
    this.padding = const EdgeInsets.all(16),
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();

    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: padding,
        itemCount: itemCount,
        itemBuilder: (context, index) => SkeletonListItem(height: itemHeight),
      ),
    );
  }
}

/// Individual skeleton list item
class SkeletonListItem extends StatelessWidget {
  final double height;
  final bool showAvatar;

  const SkeletonListItem({
    super.key,
    this.height = 72,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (showAvatar)
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 12,
                  margin: const EdgeInsets.only(right: 16, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: 150,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card skeleton loader
class SkeletonCard extends StatelessWidget {
  final double height;
  final double width;

  const SkeletonCard({
    super.key,
    this.height = 120,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Grid skeleton loader
class SkeletonGrid extends StatelessWidget {
  final int crossAxisCount;
  final int itemCount;
  final double childAspectRatio;

  const SkeletonGrid({
    super.key,
    this.crossAxisCount = 2,
    this.itemCount = 6,
    this.childAspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Empty state widget
class AppEmptyState extends StatelessWidget {
  final String message;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const AppEmptyState({
    super.key,
    required this.message,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: FuturisticColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: FuturisticColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 14,
                  color: FuturisticColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state widget
class AppErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const AppErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: FuturisticColors.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: FuturisticColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: FuturisticColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pull-to-refresh wrapper
class PullToRefreshWrapper extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? color;
  final Color? backgroundColor;

  const PullToRefreshWrapper({
    super.key,
    required this.child,
    required this.onRefresh,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color ?? FuturisticColors.accent1,
      backgroundColor: backgroundColor ?? FuturisticColors.surface,
      child: child,
    );
  }
}

/// Loading overlay for blocking operations
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: AppLoadingIndicator(
                message: message ?? 'Please wait...',
                fullscreen: false,
              ),
            ),
          ),
      ],
    );
  }
}

/// Button with loading state
class LoadingButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final ButtonStyle? style;

  const LoadingButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: (isLoading || isDisabled) ? null : onPressed,
      style: style,
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(label),
              ],
            ),
    );
  }
}
