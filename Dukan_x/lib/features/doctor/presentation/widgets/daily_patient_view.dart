import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../core/database/app_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class DailyPatientView extends StatelessWidget {
  final List<AppointmentEntity> appointments;
  final Function(String)? onPatientTap;

  const DailyPatientView({
    super.key,
    required this.appointments,
    this.onPatientTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: FuturisticColors.glassShadow,
        border: Border.all(color: FuturisticColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Appointments",
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: FuturisticColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: FuturisticColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${appointments.length} Total',
                  style: GoogleFonts.inter(
                    color: FuturisticColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (appointments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 48,
                      color: FuturisticColors.textDisabled,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No appointments for today',
                      style: GoogleFonts.inter(
                        color: FuturisticColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: appointments.length,
              separatorBuilder: (c, i) =>
                  Divider(color: FuturisticColors.divider),
              itemBuilder: (context, index) {
                final appt = appointments[index];
                return ListTile(
                  onTap: () => onPatientTap?.call(appt.patientId),
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: FuturisticColors.primary.withOpacity(0.1),
                    child: Text(
                      appt.patientId.isNotEmpty
                          ? appt.patientId.substring(0, 1).toUpperCase()
                          : '?',
                      style: TextStyle(color: FuturisticColors.primary),
                    ),
                  ),
                  title: Text(
                    'Patient ID: ${appt.patientId}',
                    style: GoogleFonts.inter(
                      color: FuturisticColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: FuturisticColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('hh:mm a').format(appt.scheduledTime),
                        style: GoogleFonts.inter(
                          color: FuturisticColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: FuturisticColors.textDisabled,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                        appt.purpose ?? "Consultation",
                        style: GoogleFonts.inter(
                          color: FuturisticColors.textSecondary,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      ),
                    ],
                  ),
                  trailing: _buildStatusChip(appt.status),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = FuturisticColors.textDisabled;
    if (status == 'completed') color = FuturisticColors.success;
    if (status == 'scheduled') color = FuturisticColors.info;
    if (status == 'cancelled') color = FuturisticColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
