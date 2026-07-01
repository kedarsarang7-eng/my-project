import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/responsive/responsive.dart';
import 'add_prescription_screen.dart';
import '../../data/repositories/doctor_dashboard_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/session/owner_id_resolver.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';

import '../providers/clinic_dashboard_data_provider.dart';
import '../widgets/patient_overview_card.dart';
import '../widgets/daily_patient_view.dart';
import '../widgets/smart_insights_card.dart';
import '../widgets/weekly_analytics_chart.dart';
import '../widgets/monthly_analytics_chart.dart';
import '../widgets/alerts_panel.dart';
import 'package:google_fonts/google_fonts.dart';
import 'visit_screen.dart';
import 'doctor_revenue_screen.dart';
import '../../data/repositories/patient_repository.dart';
import '../../models/patient_model.dart';
import 'package:uuid/uuid.dart';
import '../../../../screens/widgets/sync_status_indicator.dart'; // IMPORT ADDED

class DoctorDashboardScreen extends ConsumerStatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  ConsumerState<DoctorDashboardScreen> createState() =>
      _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends ConsumerState<DoctorDashboardScreen> {
  final DoctorDashboardRepository _repository = sl<DoctorDashboardRepository>();

  /// Tenant-scoped owner/clinic id for this dashboard's READ queries.
  ///
  /// Resolved via the shared fail-safe [resolveOwnerId]. Returns `null` (never
  /// the literal `'SYSTEM'`) when no authenticated owner is available, so the
  /// UI renders an error/empty state instead of issuing a cross-tenant query.
  String? get _doctorId {
    try {
      return resolveOwnerId(operation: 'doctor dashboard');
    } on OwnerIdMissingException {
      return null;
    }
  }

  String? _doctorName;

  @override
  void initState() {
    super.initState();
    _loadDoctorName();
  }

  Future<void> _loadDoctorName() async {
    final session = sl<SessionManager>();
    final name = session.currentSession.displayName;
    if (name != null && mounted) {
      setState(() => _doctorName = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorId = _doctorId;
    if (doctorId == null) {
      // Fail safe: no authenticated owner — show an error/empty state instead
      // of bucketing the dashboard's reads under a 'SYSTEM' tenant.
      return DesktopContentContainer(
        title: 'Doctor Dashboard',
        subtitle:
            'Welcome back${_doctorName != null ? ', Dr. $_doctorName' : ''}',
        child: _buildNoOwnerState(),
      );
    }

    // Consume the consolidated provider — fetches all dashboard data once and
    // caches it. A rebuild no longer re-runs 5 independent DB queries.
    final asyncDashboard = ref.watch(clinicDashboardDataProvider(doctorId));

    return DesktopContentContainer(
      title: 'Doctor Dashboard',
      subtitle:
          'Welcome back${_doctorName != null ? ', Dr. $_doctorName' : ''}',
      actions: [
        DesktopIconButton(
          icon: Icons.flash_on,
          tooltip: 'Emergency Visit',
          onPressed: _startEmergencyVisit,
        ),
        const SizedBox(width: 8),
        const SyncStatusIndicator(),
      ],
      child: asyncDashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              Text(
                'Failed to load dashboard data',
                style: GoogleFonts.inter(color: FuturisticColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.invalidate(clinicDashboardDataProvider(doctorId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) => _buildDashboardContent(doctorId, data),
      ),
    );
  }

  /// Builds the full dashboard content from the consolidated [data] snapshot.
  Widget _buildDashboardContent(String doctorId, ClinicDashboardData data) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AlertsPanel(alerts: data.alerts),
          const SizedBox(height: 24),
          PatientOverviewCard(data: data.patientStats),
          const SizedBox(height: 32),
          if (context.isMobile) ...[
            _buildDailyPatientView(doctorId),
            const SizedBox(height: 24),
            SmartInsightsCard(insights: data.smartInsights),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildDailyPatientView(doctorId)),
                const SizedBox(width: 24),
                Expanded(
                  flex: 1,
                  child: SmartInsightsCard(insights: data.smartInsights),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),
          if (context.isMobile) ...[
            WeeklyAnalyticsChart(weeklyData: data.weeklyAnalytics),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DoctorRevenueScreen()),
              ),
              child: MonthlyAnalyticsChart(monthlyData: data.monthlyAnalytics),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: WeeklyAnalyticsChart(weeklyData: data.weeklyAnalytics),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DoctorRevenueScreen(),
                      ),
                    ),
                    child: MonthlyAnalyticsChart(
                      monthlyData: data.monthlyAnalytics,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoOwnerState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 56,
              color: FuturisticColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No active clinic session',
              style: GoogleFonts.inter(
                color: FuturisticColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in with a clinic owner account to view patient data. '
              'Dashboard data is never shown without an authenticated owner.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: FuturisticColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startEmergencyVisit() async {
    final nameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text(
                'Emergency / Walk-in',
                style: GoogleFonts.inter(color: colorScheme.onSurface),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quickly create a visit. Enter name or leave blank for "Walk-In".',
                style: GoogleFonts.inter(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Patient Name (Optional)',
                  labelStyle: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: colorScheme.onSurface.withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.redAccent),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
              ),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, nameController.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: Text(
                'Start Visit',
                style: TextStyle(color: colorScheme.onPrimary),
              ),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    if (!mounted) return;

    // Create Patient
    final patientName = result.isEmpty
        ? 'Walk-In ${DateTime.now().hour}:${DateTime.now().minute}'
        : result;
    final newId = const Uuid().v4();
    final now = DateTime.now();

    final patient = PatientModel(
      id: newId,
      name: patientName,
      phone: null, // Skip phone for emergency
      age: null,
      gender: 'Unknown',
      bloodGroup: null,
      address: 'Emergency Walk-in',
      chronicConditions: null,
      allergies: null,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await sl<PatientRepository>().createPatient(patient);

      if (!mounted) return;

      // Navigate to Visit Screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => VisitScreen(patientId: newId)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start emergency visit: $e')),
        );
      }
    }
  }

  Widget _buildDailyPatientView(String doctorId) {
    return StreamBuilder(
      stream: _repository.watchDailyAppointments(doctorId, DateTime.now()),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text('Error: ${snapshot.error}');
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return DailyPatientView(
          appointments: snapshot.data!,
          onPatientTap: _showPatientDetails,
        );
      },
    );
  }

  void _showPatientDetails(String patientId) async {
    final patient = await _repository.getPatientDetails(patientId);
    if (!mounted) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FuturisticColors.surface,
        title: Text(
          'Patient Details',
          style: GoogleFonts.inter(color: FuturisticColors.textPrimary),
        ),
        content: patient == null
            ? Text(
                'Patient not found',
                style: GoogleFonts.inter(color: FuturisticColors.textSecondary),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Name: ${patient.name}',
                    style: GoogleFonts.inter(
                      color: FuturisticColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Phone: ${patient.phone ?? "--"}',
                    style: GoogleFonts.inter(
                      color: FuturisticColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Age: ${patient.age ?? "--"}',
                    style: GoogleFonts.inter(
                      color: FuturisticColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Gender: ${patient.gender ?? "--"}',
                    style: GoogleFonts.inter(
                      color: FuturisticColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Allergies: ${patient.allergies ?? "None"}',
                    style: GoogleFonts.inter(color: FuturisticColors.error),
                  ),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to Prescription
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AddPrescriptionScreen(preSelectedPatientId: patient?.id),
                ),
              );
            },
            child: Text(
              'Prescribe',
              style: GoogleFonts.inter(color: FuturisticColors.primary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.inter(color: FuturisticColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
