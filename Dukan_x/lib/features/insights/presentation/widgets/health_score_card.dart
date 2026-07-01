// ============================================================================
// HEALTH SCORE CARD
// ============================================================================
// Dashboard widget showing business health score
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/business_health_engine.dart';
import '../screens/health_score_detail_screen.dart';

import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/glass_container.dart';

class HealthScoreCard extends ConsumerWidget {
  final String userId;
  final bool isDark;

  const HealthScoreCard({
    super.key,
    required this.userId,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(healthScoreStreamProvider(userId));

    return healthAsync.when(
      data: (health) => _buildCard(context, health),
      loading: () => _buildLoading(),
      error: (err, stack) => _buildError(err.toString()),
    );
  }

  Widget _buildCard(BuildContext context, HealthScoreResult health) {
    final color = Color(health.grade.colorValue);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HealthScoreDetailScreen(health: health),
          ),
        );
      },
      child: GlassContainer(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Circular Score Indicator
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                children: [
                  Center(
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: health.score / 100,
                        backgroundColor: color.withOpacity(0.1),
                        color: color,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${health.score}',
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: FuturisticColors.textPrimary,
                          ),
                        ),
                        Text(
                          '/100',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: FuturisticColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Business Health: ',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: FuturisticColors.textPrimary,
                        ),
                      ),
                      Text(
                        health.grade.label,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    health.summary,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.4,
                      color: FuturisticColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Tap for full breakdown',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 10, color: color),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return GlassContainer(
      margin: const EdgeInsets.all(16),
      height: 120,
      child: const Center(
        child: CircularProgressIndicator(color: FuturisticColors.primary),
      ),
    );
  }

  Widget _buildError(String error) {
    return GlassContainer(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      color: FuturisticColors.error,
      opacity: 0.1,
      border: Border.all(color: FuturisticColors.error.withOpacity(0.3)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: FuturisticColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Could not calculate health score: $error',
              style: GoogleFonts.inter(color: FuturisticColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
