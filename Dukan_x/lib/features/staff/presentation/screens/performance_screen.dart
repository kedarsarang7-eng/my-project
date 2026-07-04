import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import 'package:dukanx/core/localization/app_l10n.dart';
import '../../data/models/performance_score_model.dart';
import '../widgets/staff_loading_skeleton.dart';

/// Performance Screen — displays staff performance scores with factors.
///
/// Material 3, dark/light mode (Req 14.2).
/// Loading/empty/error states (Req 14.5).
/// All strings from l10n (Req 14.6).
/// Responsive layout (Req 14.3, 14.4).
class PerformanceScreen extends ConsumerStatefulWidget {
  const PerformanceScreen({super.key});

  @override
  ConsumerState<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends ConsumerState<PerformanceScreen> {
  List<PerformanceScoreModel> _scores = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPerformance();
  }

  Future<void> _loadPerformance() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        _scores = [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return AdaptiveScaffold(
      appBar: AppBar(title: Text(l10n.staffPerformance), centerTitle: false),
      body: _isLoading
          ? const StaffLoadingSkeleton(showHeader: false, itemCount: 6)
          : _error != null
          ? StaffErrorState(
              message: l10n.staffErrorLoading,
              onRetry: _loadPerformance,
            )
          : _scores.isEmpty
          ? StaffEmptyState(
              icon: Icons.trending_up,
              title: l10n.staffNoPerformance,
              description: l10n.staffNoPerformanceDesc,
            )
          : RefreshIndicator(
              onRefresh: _loadPerformance,
              child: BoundedBox(
                maxWidth: 900,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _scores.length,
                  itemBuilder: (context, index) =>
                      _buildScoreCard(_scores[index], l10n, colorScheme),
                ),
              ),
            ),
    );
  }

  Widget _buildScoreCard(
    PerformanceScoreModel score,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: _buildScoreAvatar(score.score, colorScheme),
        title: AdaptiveText(
          score.employeeId,
          maxLines: 1,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: AdaptiveText(
          '${l10n.staffPeriod}: ${score.period}',
          maxLines: 1,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        trailing: Text(
          score.score.toStringAsFixed(1),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _scoreColor(score.score),
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          if (score.factors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: score.factors.map((factor) {
                  return _buildFactorRow(factor, colorScheme);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreAvatar(double score, ColorScheme colorScheme) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: _scoreColor(score).withOpacity(0.1),
      child: Icon(_scoreIcon(score), color: _scoreColor(score), size: 20),
    );
  }

  Widget _buildFactorRow(PerformanceFactor factor, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: AdaptiveText(
              factor.name,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 2,
            child: LinearProgressIndicator(
              value: (factor.value / 100).clamp(0.0, 1.0),
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(_scoreColor(factor.value)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: AdaptiveText(
              factor.value.toStringAsFixed(0),
              maxLines: 1,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 32,
            child: AdaptiveText(
              '×${factor.weight.toStringAsFixed(1)}',
              maxLines: 1,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  IconData _scoreIcon(double score) {
    if (score >= 80) return Icons.emoji_events;
    if (score >= 60) return Icons.trending_up;
    return Icons.trending_down;
  }
}
