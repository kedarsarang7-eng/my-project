import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class AlertsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> alerts;

  const AlertsPanel({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label:
          '${alerts.length} action required alert${alerts.length > 1 ? 's' : ''}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FuturisticColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FuturisticColors.error.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: FuturisticColors.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'Action Required',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: FuturisticColors.error,
                  ),
                ),
                const SizedBox(width: 8),
                // Badge count paired with text (not color-only)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: FuturisticColors.error.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${alerts.length}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: FuturisticColors.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: FuturisticColors.error,
                        size: 16,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          alert['message'] ?? '',
                          style: GoogleFonts.inter(
                            color: FuturisticColors.textPrimary,
                          ),
                        ),
                      ),
                      if (alert['action'] != null)
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            alert['action'],
                            style: GoogleFonts.inter(
                              color: FuturisticColors.accent1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
