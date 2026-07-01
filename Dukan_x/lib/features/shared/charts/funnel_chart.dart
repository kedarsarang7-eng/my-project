import 'package:flutter/material.dart';

import '../widgets/error_retry_widget.dart';
import '../widgets/illustrated_empty_state.dart';
import '../widgets/shimmer_loading.dart';

class FunnelStageData {
  final String label;
  final int count;
  final Color? color;

  const FunnelStageData({required this.label, required this.count, this.color});

  double percentageOf(int total) => total == 0 ? 0 : (count / total) * 100;
}

class FunnelChart extends StatelessWidget {
  final List<FunnelStageData>? stages;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final ValueChanged<int>? onStageTapped;

  const FunnelChart({
    super.key,
    this.stages,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.onStageTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const ShimmerChartArea(height: 280);
    if (error != null) {
      return ErrorRetryWidget(message: error!, onRetry: onRetry ?? () {});
    }

    final items = stages ?? const [];
    if (items.isEmpty) {
      return const IllustratedEmptyState(
        icon: Icons.call_split,
        title: 'No funnel data yet',
        subtitle: 'Stages will appear once workflow metrics are tracked.',
      );
    }

    final total = items.fold<int>(0, (sum, item) => sum + item.count);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 10),
            child: _FunnelStageTile(
              stage: items[i],
              total: total,
              color: items[i].color ?? Color.lerp(const Color(0xFF6366F1), colorScheme.error, i / (items.length == 1 ? 1 : items.length - 1))!,
              onTap: onStageTapped == null ? null : () => onStageTapped!(i),
            ),
          ),
      ],
    );
  }
}

class _FunnelStageTile extends StatelessWidget {
  final FunnelStageData stage;
  final int total;
  final Color color;
  final VoidCallback? onTap;

  const _FunnelStageTile({
    required this.stage,
    required this.total,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = stage.percentageOf(total);
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _FunnelPainter(color: color),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  stage.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                '${stage.count}  •  ${pct.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FunnelPainter extends CustomPainter {
  final Color color;

  _FunnelPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * 0.9, size.height)
      ..lineTo(size.width * 0.1, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FunnelPainter oldDelegate) => oldDelegate.color != color;
}
