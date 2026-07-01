// ============================================================================
// HEALTH SCORE DETAIL SCREEN
// ============================================================================
// Detailed breakdown of business health factors
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/business_health_engine.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class HealthScoreDetailScreen extends StatelessWidget {
  final HealthScoreResult health;

  const HealthScoreDetailScreen({super.key, required this.health});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Color(health.grade.colorValue);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D1B2A)
          : const Color(0xFFF3F4F6),
      body: BoundedBox(
        maxWidth: 800,
        child: CustomScrollView(
        slivers: [
          _buildAppBar(context, isDark, color),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRecommendations(context, isDark),
                  const SizedBox(height: 24),
                  Text(
                    'Score Breakdown',
                    style: TextStyle(
                      fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRadarChart(isDark, color),
                  const SizedBox(height: 24),
                  _buildFactorList(isDark),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark, Color color) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: color,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, color.withOpacity(0.8)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${health.score}',
                  style: TextStyle(
                    fontSize: responsiveValue<double>(context,
                    mobile: 32.0,
                    tablet: 32.0,
                    desktop: 48.0,  // PRESERVED: Desktop uses exactly 48 as before
                  ),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  health.grade.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendations(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E3A5F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                'Recommendations',
                style: TextStyle(
                  fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...health.recommendations.map(
            (rec) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      rec,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarChart(bool isDark, Color color) {
    if (health.factors.isEmpty) return const SizedBox.shrink();

    // Map factors to radar entries
    // Order: Sales, Pending, Stock, Cash Flow, Sync
    final data = health.factors.map((f) => f.score.toDouble()).toList();

    return AspectRatio(
      aspectRatio: 1.5,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E3A5F) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: RadarChart(
          RadarChartData(
            dataSets: [
              RadarDataSet(
                fillColor: color.withOpacity(0.2),
                borderColor: color,
                entryRadius: 3,
                dataEntries: data.map((v) => RadarEntry(value: v)).toList(),
                borderWidth: 2,
              ),
            ],
            radarBackgroundColor: Colors.transparent,
            borderData: FlBorderData(show: false),
            radarBorderData: const BorderSide(color: Colors.transparent),
            titlePositionPercentageOffset: 0.2,
            titleTextStyle: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 10,
            ),
            getTitle: (index, angle) {
              if (index >= health.factors.length) {
                return const RadarChartTitle(text: '');
              }
              return RadarChartTitle(text: health.factors[index].type.label);
            },
            tickCount: 1,
            ticksTextStyle: const TextStyle(color: Colors.transparent),
            gridBorderData: BorderSide(
              color: isDark ? Colors.white12 : Colors.black12,
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFactorList(bool isDark) {
    return Column(
      children: health.factors.map((factor) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E3A5F) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Score Circle
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _getScoreColor(factor.score).withOpacity(0.3),
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${factor.score}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(factor.score),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      factor.type.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      factor.detail,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getScoreColor(factor.score).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  factor.status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(factor.score),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return const Color(0xFF10B981); // Green
    if (score >= 50) return const Color(0xFFF59E0B); // Yellow
    return const Color(0xFFEF4444); // Red
  }
}
