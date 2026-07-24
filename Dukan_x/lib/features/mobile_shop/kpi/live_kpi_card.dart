// ============================================================================
// MOBILE SHOP — LIVE KPI CARD WIDGET
// ============================================================================
// Renders a single KPI metric with explicit state indicators for:
// loading, current, empty, stale, unavailable, and error states.
//
// Each state has distinct visual and semantic treatment:
// - Loading: skeleton/shimmer placeholder
// - Current: value with freshness indicator (green dot)
// - Empty: zero or dash with confirmed-empty label
// - Stale: value with amber stale indicator and last-confirmed time
// - Unavailable: disabled appearance with reason
// - Error: error indicator with optional stale value
//
// Tapping a current/stale/empty card opens the permission-gated filter view
// matching the displayed metric (Req 9.8).
//
// Requirements: 2.7, 9.1–9.8, 9.13, 12.10; Audit: AF-33, AF-47
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'kpi_metric.dart';
import 'kpi_state.dart';

/// A Live KPI card that renders a metric with confirmation-aware state
/// indicators and watermark/freshness metadata.
///
/// Unlike the old hardcoded status cards, this widget:
/// - Never shows a value as "current" unless backed by confirmed data
/// - Shows distinct visual states for all six KPI states
/// - Includes watermark info showing data freshness
/// - Only navigates to filter views when data is actionable
class LiveKpiCard extends StatelessWidget {
  /// The metric configuration for display and navigation.
  final KpiMetricConfig config;

  /// The current state of this KPI metric.
  final KpiState<int> kpiState;

  /// Optional callback invoked after navigation.
  final VoidCallback? onNavigated;

  const LiveKpiCard({
    super.key,
    required this.config,
    required this.kpiState,
    this.onNavigated,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNavigable = _isNavigable;

    final cardContent = _buildCardContent(context, theme);

    if (isNavigable) {
      return Semantics(
        button: true,
        label: _semanticLabel,
        child: InkWell(
          onTap: () => _navigateToFilter(context),
          borderRadius: BorderRadius.circular(12),
          child: cardContent,
        ),
      );
    }

    return Semantics(label: _semanticLabel, child: cardContent);
  }

  /// Whether this card supports navigation (current, empty, or stale).
  bool get _isNavigable => switch (kpiState) {
    KpiCurrent() => true,
    KpiEmpty() => true,
    KpiStale() => true,
    KpiLoading() => false,
    KpiUnavailable() => false,
    KpiError() => false,
  };

  /// Generates an appropriate semantic label for accessibility.
  String get _semanticLabel => switch (kpiState) {
    KpiLoading() => '${config.title}: Loading',
    KpiCurrent(:final value, :final watermark) =>
      '${config.title}: $value. '
          'Current as of ${_formatTime(watermark.refreshedAt)}. '
          'Tap to view details.',
    KpiEmpty(:final showZero) =>
      '${config.title}: ${showZero ? "0" : "No data"}. '
          'Confirmed empty. Tap to view details.',
    KpiStale(:final lastValue, :final lastWatermark) =>
      '${config.title}: $lastValue (stale). '
          'Last confirmed ${_formatTime(lastWatermark.refreshedAt)}. '
          'Tap to view details.',
    KpiUnavailable(:final reason) => '${config.title}: Unavailable. $reason.',
    KpiError(:final error, :final lastValue) =>
      '${config.title}: Error${lastValue != null ? ", last value $lastValue" : ""}. '
          '${error.message}.',
  };

  Widget _buildCardContent(BuildContext context, ThemeData theme) {
    return Card(
      elevation: _isNavigable ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: _isNavigable
            ? BorderSide.none
            : BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildIcon(theme),
            const SizedBox(width: 12),
            Expanded(child: _buildContent(theme)),
            _buildTrailing(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(ThemeData theme) {
    final color = _iconColor(theme);
    return Icon(config.icon, size: 32, color: color);
  }

  Widget _buildContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title row with state indicator
        Row(
          children: [
            Expanded(
              child: Text(
                config.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildStateIndicator(theme),
          ],
        ),
        const SizedBox(height: 4),
        // Value row
        _buildValueDisplay(theme),
        // Watermark/freshness info
        if (_watermarkText != null) ...[
          const SizedBox(height: 2),
          Text(
            _watermarkText!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildValueDisplay(ThemeData theme) {
    return switch (kpiState) {
      KpiLoading() => _buildLoadingPlaceholder(theme),
      KpiCurrent(:final value) => Text(
        _formatValue(value),
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      KpiEmpty(:final showZero) => Text(
        showZero ? '0' : '—',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      KpiStale(:final lastValue) => Text(
        _formatValue(lastValue),
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      KpiUnavailable() => Text(
        '—',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface.withOpacity(0.3),
        ),
      ),
      KpiError(:final lastValue) => Text(
        lastValue != null ? _formatValue(lastValue) : '!',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.error,
        ),
      ),
    };
  }

  /// State indicator dot/badge showing the KPI freshness state.
  Widget _buildStateIndicator(ThemeData theme) {
    final (color, tooltip) = switch (kpiState) {
      KpiLoading() => (Colors.grey, 'Loading...'),
      KpiCurrent() => (Colors.green, 'Current'),
      KpiEmpty() => (Colors.green.shade300, 'Empty (confirmed)'),
      KpiStale(:final refreshStatus) => (
        Colors.amber,
        switch (refreshStatus) {
          KpiRefreshStatus.refreshing => 'Refreshing...',
          KpiRefreshStatus.retryPending => 'Refresh pending',
          KpiRefreshStatus.notAttempted => 'Stale',
        },
      ),
      KpiUnavailable() => (Colors.grey.shade400, 'Unavailable'),
      KpiError() => (theme.colorScheme.error, 'Error'),
    };

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  Widget _buildTrailing(ThemeData theme) {
    if (_isNavigable) {
      return Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant,
      );
    }
    if (kpiState is KpiUnavailable) {
      return Icon(
        Icons.block,
        size: 16,
        color: theme.colorScheme.onSurface.withOpacity(0.3),
      );
    }
    if (kpiState is KpiError) {
      return Icon(
        Icons.error_outline,
        size: 16,
        color: theme.colorScheme.error,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildLoadingPlaceholder(ThemeData theme) {
    return Container(
      height: 20,
      width: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Color _iconColor(ThemeData theme) => switch (kpiState) {
    KpiLoading() => theme.colorScheme.onSurface.withOpacity(0.3),
    KpiCurrent() => theme.colorScheme.primary,
    KpiEmpty() => theme.colorScheme.onSurfaceVariant,
    KpiStale() => theme.colorScheme.primary.withOpacity(0.6),
    KpiUnavailable() => theme.colorScheme.onSurface.withOpacity(0.2),
    KpiError() => theme.colorScheme.error.withOpacity(0.7),
  };

  /// Watermark text showing data freshness.
  String? get _watermarkText => switch (kpiState) {
    KpiCurrent(:final watermark) =>
      'v${watermark.dataVersion} • ${_formatTime(watermark.refreshedAt)}',
    KpiStale(:final lastWatermark, :final refreshStatus) =>
      'Last: ${_formatTime(lastWatermark.refreshedAt)} • ${refreshStatus.name}',
    KpiError(:final lastWatermark) =>
      lastWatermark != null
          ? 'Last: ${_formatTime(lastWatermark.refreshedAt)}'
          : null,
    _ => null,
  };

  /// Formats an integer value (with ₹ prefix for paise-based metrics).
  String _formatValue(int value) {
    if (config.metric == KpiMetric.exchangeValuePaise) {
      // Convert paise to rupees for display.
      final rupees = value / 100;
      if (rupees >= 100000) {
        return '₹${(rupees / 100000).toStringAsFixed(1)}L';
      }
      if (rupees >= 1000) {
        return '₹${(rupees / 1000).toStringAsFixed(1)}K';
      }
      return '₹${rupees.toStringAsFixed(0)}';
    }
    return value.toString();
  }

  /// Formats a DateTime for display in watermark text.
  static String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Navigates to the exact permission-gated filter view (Req 9.8).
  void _navigateToFilter(BuildContext context) {
    final uri = Uri(
      path: config.filterRoute,
      queryParameters: config.filterParams.isNotEmpty
          ? config.filterParams
          : null,
    );
    GoRouter.of(context).go(uri.toString());
    onNavigated?.call();
  }
}
