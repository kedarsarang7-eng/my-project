import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../doctor/data/repositories/appointment_repository.dart';
import '../../../doctor/models/appointment_model.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class PatientAppointmentsScreen extends ConsumerStatefulWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  ConsumerState<PatientAppointmentsScreen> createState() =>
      _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState
    extends ConsumerState<PatientAppointmentsScreen> {
  @override
  Widget build(BuildContext context) {
    final patientId = sl<SessionManager>().userId;
    if (patientId == null) {
      return const Center(child: Text("Error: Not logged in"));
    }

    return Container(
      color: FuturisticColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Text(
                  'My Appointments',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AppointmentModel>>(
              stream: sl<AppointmentRepository>().watchAppointmentsForPatient(
                patientId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final appointments = snapshot.data ?? [];

                if (appointments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No upcoming appointments',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: appointments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final appt = appointments[index];
                    return _buildAppointmentCard(appt);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(AppointmentModel appt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FuturisticColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('MMM').format(appt.scheduledTime).toUpperCase(),
                  style: TextStyle(
                    color: FuturisticColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('dd').format(appt.scheduledTime),
                  style: TextStyle(
                    color: FuturisticColors.primary,
                    fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appt.purpose?.isNotEmpty == true
                      ? appt.purpose!
                      : 'General Checkup',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dr. ID: ${appt.doctorId.substring(0, 5)}... • ${DateFormat('hh:mm a').format(appt.scheduledTime)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(appt.status).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              appt.status.name,
              style: TextStyle(
                color: _getStatusColor(appt.status),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.scheduled:
        return Colors.orange;
      case AppointmentStatus.completed:
        return Colors.green;
      case AppointmentStatus.cancelled:
        return Colors.red;
    }
  }
}
