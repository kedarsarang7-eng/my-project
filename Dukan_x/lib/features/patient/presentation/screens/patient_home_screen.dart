import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/visits_repository.dart'; // Fixed import
import '../../../../models/visit.dart'; // Fixed import
import 'medical_records_screen.dart';
import 'patient_appointments_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class PatientHomeScreen extends ConsumerStatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const _PatientHomeTab(),
    const MedicalRecordsScreen(),
    const PatientAppointmentsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FuturisticColors.background,
      body: SafeArea(child: _screens[_currentIndex]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: FuturisticColors.surface,
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          selectedItemColor: FuturisticColors.primary,
          unselectedItemColor: Colors.grey,
          elevation: 0,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_edu_rounded),
              label: 'Records',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_rounded),
              label: 'Appointments',
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientHomeTab extends StatefulWidget {
  const _PatientHomeTab();

  @override
  State<_PatientHomeTab> createState() => _PatientHomeTabState();
}

class _PatientHomeTabState extends State<_PatientHomeTab> {
  Visit? _nextVisit;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNextAppointment();
  }

  Future<void> _loadNextAppointment() async {
    final user = sl<SessionManager>().currentSession;
    if (!user.isAuthenticated) return;

    try {
      final repo = sl<VisitsRepository>();
      final result = await repo.getVisitsForPatient(user.odId);

      if (result.isSuccess && result.data != null) {
        final now = DateTime.now();
        final futureVisits =
            result.data!.where((v) => v.visitDate.isAfter(now)).toList()
              ..sort((a, b) => a.visitDate.compareTo(b.visitDate));

        if (mounted) {
          setState(() {
            _nextVisit = futureVisits.isNotEmpty ? futureVisits.first : null;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = sl<SessionManager>().currentSession;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: FuturisticColors.primary,
                child: Text(
                  user.displayName?.isNotEmpty == true
                      ? user.displayName![0]
                      : 'P',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hello,', style: TextStyle(color: Colors.grey)),
                  Text(
                    user.displayName ?? 'Patient',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No new notifications')),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Next Appointment Card
          const Text(
            'Next Appointment',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildAppointmentCard(),

          const SizedBox(height: 32),

          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildActionCard(Icons.qr_code, 'My QR', () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('My Patient QR'),
                    content: const SizedBox(
                      height: 200,
                      child: Center(child: Icon(Icons.qr_code, size: 100)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }),
              _buildActionCard(Icons.upload_file, 'Upload', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('File uploader opening...')),
                );
              }),
              _buildActionCard(Icons.call, 'Contact', () {
                // In production: launchUrl(Uri.parse('tel:+1234567890'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Calling clinic...')),
                );
              }),
              _buildActionCard(Icons.medication, 'Meds', () {
                // Tab index 1 is Medical Records (simplified routing)
                // In real app, use a named route or tab controller
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening Prescriptions...')),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_nextVisit == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: FuturisticColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: const Center(
          child: Text(
            'No upcoming appointments',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: FuturisticColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: FuturisticColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                // Simple date format
                "${_nextVisit!.visitDate.day}/${_nextVisit!.visitDate.month} at ${_nextVisit!.visitDate.hour}:${_nextVisit!.visitDate.minute.toString().padLeft(2, '0')}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Medical Checkup', // Or fetch type if available
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 4),
          const Text('City Clinic', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildActionCard(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FuturisticColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Icon(icon, color: FuturisticColors.accent1, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
