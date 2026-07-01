import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../data/clinic_repository.dart';

import '../widgets/clinic_breadcrumbs.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Clinic Appointment Calendar — Day/Week/Month view
class ClinicCalendarScreen extends ConsumerStatefulWidget {
  const ClinicCalendarScreen({super.key});

  @override
  ConsumerState<ClinicCalendarScreen> createState() =>
      _ClinicCalendarScreenState();
}

class _ClinicCalendarScreenState extends ConsumerState<ClinicCalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  List<Map<String, dynamic>> _selectedDayAppointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    final result = await ref.read(clinicRepositoryProvider).listAppointments();
    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load: ${failure.message}')),
          );
        }
      },
      (appointments) {
        final events = <DateTime, List<Map<String, dynamic>>>{};
        for (final appt in appointments) {
          final dateStr =
              appt['scheduledDate'] ?? appt['appointmentDate'] ?? '';
          if (dateStr.toString().isEmpty) continue;
          final date = DateTime.tryParse(dateStr.toString());
          if (date == null) continue;
          final key = DateTime(date.year, date.month, date.day);
          events.putIfAbsent(key, () => []).add(appt);
        }
        if (mounted) {
          setState(() {
            _events = events;
            _selectedDayAppointments = _getEventsForDay(_selectedDay!);
          });
        }
      },
    );
    if (mounted) setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in-consultation':
        return Colors.orange;
      case 'cancelled':
      case 'no-show':
        return Colors.red;
      case 'waiting':
        return Colors.amber;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Appointment Calendar',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAppointments),
          PopupMenuButton<CalendarFormat>(
            icon: const Icon(Icons.view_agenda),
            onSelected: (format) => setState(() => _calendarFormat = format),
            itemBuilder: (_) => [
              const PopupMenuItem(value: CalendarFormat.month, child: Text('Month')),
              const PopupMenuItem(value: CalendarFormat.twoWeeks, child: Text('2 Weeks')),
              const PopupMenuItem(value: CalendarFormat.week, child: Text('Week')),
            ],
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
        children: [
          ClinicBreadcrumbs(items: [
            BreadcrumbItem('Dashboard', onTap: () => Navigator.pop(context)),
            const BreadcrumbItem('Calendar'),
          ]),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                TableCalendar<Map<String, dynamic>>(
                  firstDay: DateTime.utc(2024, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: _getEventsForDay,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  calendarStyle: CalendarStyle(
                    markerDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                      _selectedDayAppointments = _getEventsForDay(selectedDay);
                    });
                  },
                  onFormatChanged: (format) => setState(() => _calendarFormat = format),
                  onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '${_selectedDayAppointments.length} appointment${_selectedDayAppointments.length == 1 ? '' : 's'}',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      if (_selectedDay != null)
                        Text(
                          '${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
                          style: GoogleFonts.outfit(color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: _selectedDayAppointments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_available, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text('No appointments', style: TextStyle(color: Colors.grey.shade500)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _selectedDayAppointments.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemBuilder: (context, index) {
                            final appt = _selectedDayAppointments[index];
                            final status = appt['status']?.toString() ?? 'scheduled';
                            final time = appt['scheduledTime'] ?? appt['appointmentTime'] ?? '--:--';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Container(
                                  width: 4,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _statusColor(status),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                title: Text(appt['patientName']?.toString() ?? 'Patient',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('$time • ${appt['purpose'] ?? status}'),
                                trailing: Chip(
                                  label: Text(status, style: const TextStyle(fontSize: 11)),
                                  backgroundColor: _statusColor(status).withValues(alpha: 0.15),
                                  side: BorderSide.none,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
