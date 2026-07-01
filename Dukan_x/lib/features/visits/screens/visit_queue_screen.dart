import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../models/visit.dart';
import '../../../../models/patient.dart';
import '../../../../core/di/service_locator.dart';
import 'consultation_screen.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/repository/patients_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class VisitQueueScreen extends ConsumerStatefulWidget {
  const VisitQueueScreen({super.key});

  @override
  ConsumerState<VisitQueueScreen> createState() => _VisitQueueScreenState();
}

class _VisitQueueScreenState extends ConsumerState<VisitQueueScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    // Invalidate provider to trigger refresh
    ref.invalidate(todaysVisitsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(todaysVisitsProvider);

    return Scaffold(
      backgroundColor: FuturisticColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Queue Management',
          style: GoogleFonts.outfit(
            fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: FuturisticColors.neonBlue,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Waiting'),
            Tab(text: 'In Progress'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [FuturisticColors.backgroundDark, const Color(0xFF0F172A)],
          ),
        ),
        child: visitsAsync.when(
          data: (visits) {
            final waiting = visits
                .where((v) => v.status == 'checked_in' || v.status == 'waiting')
                .toList();
            final inProgress = visits
                .where((v) => v.status == 'in_progress')
                .toList();
            final completed = visits
                .where((v) => v.status == 'completed')
                .toList();

            return TabBarView(
              controller: _tabController,
              children: [
                _buildList(waiting, 'No patients waiting', Colors.orange),
                _buildList(inProgress, 'No active consultations', Colors.blue),
                _buildList(
                  completed,
                  'No completed visits today',
                  Colors.green,
                ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: FuturisticColors.neonBlue),
          ),
          error: (err, stack) => Center(
            child: Text(
              'Error: $err',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _refresh,
        backgroundColor: Colors.white.withOpacity(0.1),
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildList(List<Visit> visits, String emptyMsg, Color accentColor) {
    if (visits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_ind_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMsg,
              style: GoogleFonts.outfit(
                color: Colors.white.withOpacity(0.4),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: visits.length,
        itemBuilder: (context, index) {
          final visit = visits[index];
          return _buildVisitCard(visit, accentColor);
        },
      ),
    );
  }

  Widget _buildVisitCard(Visit visit, Color accentColor) {
    // Need to fetch patient name? Ideally Visit model or a joined query provides calling name.
    // My Visit model has patientId but not name.
    // I should create a separate provider or future to fetch Patient details for each card
    // OR create a "VisitWithPatient" DTO in repo.
    // For simplicity now, I'll fetch patient name via FutureBuilder linked to repo OR just show ID/Time.
    // Actually, displaying just ID is bad UX.
    // Better: Helper widget that fetches patient.

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Open Consultation
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ConsultationScreen(visitId: visit.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Time / Token
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${visit.visitDate.hour}:${visit.visitDate.minute.toString().padLeft(2, '0')}',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Time',
                        style: GoogleFonts.outfit(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    // Use FutureBuilder for Patient Name
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PatientNameWidget(patientId: visit.patientId),
                      const SizedBox(height: 4),
                      Text(
                        visit.status.toUpperCase().replaceAll('_', ' '),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.white.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PatientNameWidget extends ConsumerWidget {
  final String patientId;
  const _PatientNameWidget({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We could make a provider for single patient, or just use Future
    // Using a FutureProvider.family for single patient would be cached efficiently

    // For now, quick direct access via repo instance in FutureBuilder is okay for list
    // optimization: create 'patientProvider(id)'

    return FutureBuilder<RepositoryResult<Patient?>>(
      future: sl<PatientsRepository>().getById(patientId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            width: 100,
            height: 16,
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        final patient = snapshot.data?.data;
        return Text(
          patient?.name ?? 'Unknown Patient',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.white,
          ),
        );
      },
    );
  }
}
