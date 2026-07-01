import 'package:flutter/material.dart';
import 'add_prescription_screen.dart';
import 'visit_screen.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/modern_ui_components.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../models/appointment_model.dart';
import '../../data/repositories/appointment_repository.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class AppointmentScreen extends ConsumerStatefulWidget {
  const AppointmentScreen({super.key});

  @override
  ConsumerState<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends ConsumerState<AppointmentScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final ownerId = sl<SessionManager>().ownerId ?? '';
    if (ownerId.isEmpty) {
      return const Center(child: Text('Error: No Doctor ID'));
    }

    return DesktopContentContainer(
      title: 'Appointments',
      subtitle: 'Manage schedule and visits',
      actions: [
        DesktopIconButton(
          icon: Icons.today,
          tooltip: 'Today',
          onPressed: () => setState(() => _selectedDate = DateTime.now()),
        ),
        const SizedBox(width: 8),
        PrimaryButton(
          label: 'Schedule',
          icon: Icons.add_task,
          onPressed: () => _showAddDialog(context, ownerId),
        ),
      ],
      child: Column(
        children: [
          // Date Selector
          _buildDateSelector(),

          Expanded(
            child: StreamBuilder<List<AppointmentModel>>(
              stream: sl<AppointmentRepository>().watchAppointmentsForDoctor(
                ownerId,
                _selectedDate,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final appointments = snapshot.data ?? [];

                if (appointments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 64,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No appointments for this day',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    final appt = appointments[index];
                    return ModernCard(
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: FuturisticColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            DateFormat('HH:mm').format(appt.scheduledTime),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: FuturisticColors.primary,
                            ),
                          ),
                        ),
                        title: Text(
                          (appt.purpose?.isNotEmpty == true)
                              ? appt.purpose!
                              : 'General Consultation',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          'Status: ${appt.status.name} \n${appt.notes}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                          ),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'visit',
                              child: Text('Start Visit'),
                            ),
                            const PopupMenuItem(
                              value: 'prescribe',
                              child: Text('Prescribe Medicine'),
                            ),
                            const PopupMenuItem(
                              value: 'complete',
                              child: Text('Mark Complete'),
                            ),
                            const PopupMenuItem(
                              value: 'cancel',
                              child: Text('Cancel'),
                            ),
                          ],
                          onSelected: (val) async {
                            if (val == 'visit') {
                              // Navigate to Visit Screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VisitScreen(
                                    appointmentId: appt.id,
                                    patientId: appt.patientId,
                                    patientName: appt.purpose,
                                  ),
                                ),
                              );
                              return;
                            }
                            if (val == 'prescribe') {
                              // Navigate to Prescription Screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddPrescriptionScreen(
                                    preSelectedPatientId: appt.patientId,
                                  ),
                                ),
                              );
                              return;
                            }
                            final newStatus = val == 'complete'
                                ? AppointmentStatus.completed
                                : AppointmentStatus.cancelled;
                            final updated = appt.copyWith(
                              status: newStatus,
                              updatedAt: DateTime.now(),
                            );
                            await sl<AppointmentRepository>().updateAppointment(
                              updated,
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      height: 80,
      color: FuturisticColors.surface.withOpacity(0.5),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 30, // Next 30 days
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = isSameDay(date, _selectedDate);
          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 60,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? FuturisticColors.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white,
                      fontSize: responsiveValue<double>(
                        context,
                        mobile: 14.0,
                        tablet: 16.0,
                        desktop:
                            18.0, // PRESERVED: Desktop uses exactly 18 as before
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showAddDialog(BuildContext context, String doctorId) {
    final purposeController = TextEditingController();
    final timeController = TextEditingController(
      text: '10:00',
    ); // Simple text for now
    bool sendReminder = false; // Reminder opt-in state (task 6.4 — Req 2.20)

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: FuturisticColors.surface,
          title: const Text(
            'Schedule Appointment',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: purposeController,
                decoration: const InputDecoration(
                  labelText: 'Purpose',
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(
                  labelText: 'Time (HH:MM)',
                  filled: true,
                ),
                keyboardType: TextInputType.datetime,
              ),
              const SizedBox(height: 16),
              // ============================================================
              // Reminder opt-in integration point (clinic task 6.4 — Req 2.20)
              //
              // Captures patient opt-in preference for SMS/WhatsApp appointment
              // reminders. The actual backend dispatch (sending the message) is
              // OUT OF SCOPE this pass — only the app-layer toggle + placeholder
              // hook are implemented here.
              // ============================================================
              CheckboxListTile(
                value: sendReminder,
                onChanged: (value) {
                  setDialogState(() => sendReminder = value ?? false);
                },
                title: const Text(
                  'Send appointment reminder',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: Text(
                  'SMS/WhatsApp reminder to patient',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                secondary: Icon(
                  Icons.notifications_active_outlined,
                  color: sendReminder ? FuturisticColors.primary : Colors.grey,
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: FuturisticColors.primary,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final timeParts = timeController.text.split(':');
                  final hour = int.parse(timeParts[0]);
                  final minute = int.parse(timeParts[1]);

                  final scheduledTime = DateTime(
                    _selectedDate.year,
                    _selectedDate.month,
                    _selectedDate.day,
                    hour,
                    minute,
                  );

                  final appt = AppointmentModel(
                    id: const Uuid().v4(),
                    doctorId: doctorId,
                    patientId: 'GUEST', // Ideally select patient
                    scheduledTime: scheduledTime,
                    status: AppointmentStatus.scheduled,
                    purpose: purposeController.text,
                    notes: '',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );

                  await sl<AppointmentRepository>().createAppointment(appt);

                  // TODO: backend dispatch out of scope this pass — wire SMS/WhatsApp
                  // service here. When `sendReminder` is true, dispatch a reminder
                  // notification to the patient's phone (SMS) or WhatsApp number.
                  // Integration requirements:
                  // - Respect patient opt-in preference (stored per-patient)
                  // - Schedule reminder for configurable offset before appointment
                  // - Support both SMS and WhatsApp channels
                  // - Handle delivery failures gracefully (retry / fallback)
                  if (sendReminder) {
                    debugPrint(
                      'Reminder opt-in: patient reminder requested for '
                      'appointment ${appt.id} at $scheduledTime '
                      '— backend dispatch not yet wired',
                    );
                  }

                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  // Show error
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FuturisticColors.primary,
              ),
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }
}
