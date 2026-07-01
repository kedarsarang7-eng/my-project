import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../../../core/theme/futuristic_colors.dart';
import '../../models/pharmacy_dashboard_models.dart';
import '../../providers/pharmacy_dashboard_providers.dart';

class PharmacyPatientFeedback extends ConsumerWidget {
  const PharmacyPatientFeedback({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackAsync = ref.watch(pharmacyPatientFeedbackProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          Expanded(
            child: feedbackAsync.when(
              data: (data) => _buildFeedbackContent(context, data),
              loading: () => _buildLoadingContent(),
              error: (_, _) => _buildErrorContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
        padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.star_rounded,
            color: Colors.amber,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Patient Feedback',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: FuturisticColors.textPrimary,
                ),
              ),
              Text(
                'Average rating & trend',
                style: TextStyle(
                  fontSize: 12,
                  color: FuturisticColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackContent(BuildContext context, PatientFeedbackData data) {
    if (data.isEmpty) {
      return _buildEmptyContent();
    }

    return Column(
      children: [
        // Rating Display
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Star Rating
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    data.averageRating.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: FuturisticColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStarRating(data.averageRating),
                      const SizedBox(height: 4),
                      Text(
                        'Average Rating',
                        style: TextStyle(
                          fontSize: 12,
                          color: FuturisticColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Trend Sparkline
              if (data.trend.isNotEmpty) ...[
                Text(
                  '30-Day Trend',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FuturisticColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _buildTrendChart(data.trend),
                ),
              ],
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Rating Distribution
        if (data.trend.isNotEmpty) ...[
          _buildRatingDistribution(data),
        ],
      ],
    );
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final filled = rating >= starValue;
        final halfFilled = rating >= starValue - 0.5 && rating < starValue;
        
        return Icon(
          halfFilled ? Icons.star_half : (filled ? Icons.star : Icons.star_border),
          color: Colors.amber,
          size: 20,
        );
      }),
    );
  }

  Widget _buildTrendChart(List<double> trend) {
    if (trend.length < 2) {
      return Container(
        alignment: Alignment.center,
        child: Text(
          'Insufficient data for trend',
          style: TextStyle(
            fontSize: 12,
            color: FuturisticColors.textSecondary,
          ),
        ),
      );
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              trend.length,
              (index) => FlSpot(index.toDouble(), trend[index]),
            ),
            isCurved: true,
            color: _getTrendColor(trend),
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  _getTrendColor(trend).withValues(alpha: 0.1),
                  _getTrendColor(trend).withValues(alpha: 0.01),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: const LineTouchData(enabled: false),
        minX: 0,
        maxX: (trend.length - 1).toDouble(),
        minY: 0,
        maxY: 5,
      ),
    );
  }

  Widget _buildRatingDistribution(PatientFeedbackData data) {
    // Calculate distribution from trend data (simplified approach)
    final distribution = _calculateDistribution(data.trend);
    
    return Column(
      children: [
        Text(
          'Rating Distribution',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: FuturisticColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(5, (index) {
          final starValue = 5 - index; // 5 to 1
          final percentage = distribution[starValue] ?? 0.0;
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Text(
                  '$starValue',
                  style: TextStyle(
                    fontSize: 12,
                    color: FuturisticColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 12,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: FuturisticColors.textSecondary.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(percentage * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: FuturisticColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLoadingContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
          color: Colors.amber,
        ),
        const SizedBox(height: 16),
        Text(
          'Loading feedback data...',
          style: TextStyle(
            color: FuturisticColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent() {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: FuturisticColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to load feedback data',
            style: TextStyle(
              color: FuturisticColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyContent() {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.star_outline_rounded,
            size: 48,
            color: FuturisticColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No patient feedback available',
            style: TextStyle(
              color: FuturisticColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper Methods ─────────────────────────────────────────────────────

  Color _getTrendColor(List<double> trend) {
    if (trend.length < 2) return FuturisticColors.textSecondary;
    
    final firstValue = trend.first;
    final lastValue = trend.last;
    
    if (lastValue > firstValue) {
      return FuturisticColors.success; // Improving
    } else if (lastValue < firstValue) {
      return FuturisticColors.error; // Declining
    } else {
      return FuturisticColors.info; // Stable
    }
  }

  Map<int, double> _calculateDistribution(List<double> trend) {
    // Simple distribution calculation based on trend data
    final distribution = <int, double>{};
    
    for (int i = 1; i <= 5; i++) {
      distribution[i] = 0.0;
    }
    
    // Count ratings in trend
    for (final rating in trend) {
      final starRating = rating.round().clamp(1, 5);
      distribution[starRating] = (distribution[starRating] ?? 0.0) + 1.0;
    }
    
    // Convert to percentages
    final total = trend.length.toDouble();
    for (int i = 1; i <= 5; i++) {
      distribution[i] = (distribution[i] ?? 0.0) / total;
    }
    
    return distribution;
  }
}
