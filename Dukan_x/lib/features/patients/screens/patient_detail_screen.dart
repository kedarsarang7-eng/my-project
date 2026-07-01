import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../models/patient.dart';
import '../../../../models/visit.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/visits_repository.dart';
import '../../visits/screens/consultation_screen.dart';
import 'package:uuid/uuid.dart';
import '../../../core/session/session_manager.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class PatientDetailScreen extends ConsumerStatefulWidget {
  final Patient patient;

  const PatientDetailScreen({super.key, required this.patient});

  @override
  ConsumerState<PatientDetailScreen> createState() =>
      _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen> {
  late Future<List<Visit>> _visitsFuture;

  @override
  void initState() {
    super.initState();
    _refreshVisits();
  }

  void _refreshVisits() {
    _visitsFuture = sl<VisitsRepository>()
        .getVisitsForPatient(widget.patient.id)
        .then((result) {
          if (result.isSuccess) {
            return result.data ?? [];
          }
          return [];
        });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Visit>>(
      future: _visitsFuture,
      builder: (context, snapshot) {
        final visits = snapshot.data ?? [];
        final lastVisit = visits.isNotEmpty ? visits.first : null;
        final totalVisits = visits.length;

        // Calculate stats
        String lastVisitText = 'Never';
        if (lastVisit != null) {
          final diff = DateTime.now().difference(lastVisit.visitDate).inDays;
          if (diff == 0) {
            lastVisitText = 'Today';
          } else if (diff == 1) {
            lastVisitText = 'Yesterday';
          } else {
            lastVisitText = '$diff days ago';
          }
        }

        return Scaffold(
          backgroundColor: FuturisticColors.backgroundDark,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.edit_rounded,
                  color: Colors.white.withOpacity(0.8),
                ),
                onPressed: () {
                  // Edit Patient
                },
              ),
            ],
          ),
          body: BoundedBox(
            maxWidth: 800,
            child: SingleChildScrollView(
            child: Column(
              children: [
                _buildProfileHeader(widget.patient),
                const SizedBox(height: 24),
                _buildQuickStats(lastVisitText, totalVisits.toString()),
                const SizedBox(height: 24),
                _buildMedicalProfile(widget.patient),
                const SizedBox(height: 24),
                _buildVisitHistory(visits),
                const SizedBox(height: 100), // Bottom padding for FAB
              ],
            ),
          ),
          ),

          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              // 1. Get Doctor ID from Session
              final session = sl<SessionManager>();
              final doctorId = session.userId ?? 'UNKNOWN';

              final visitRepo = sl<VisitsRepository>();
              final visitId = const Uuid().v4();
              final now = DateTime.now();

              final newVisit = Visit(
                id: visitId,
                patientId: widget.patient.id,
                doctorId: doctorId,
                visitDate: now,
                status: 'WAITING',
                symptoms: [],
                diagnosis: '',
                notes: '', // Private notes
                createdAt: now,
                updatedAt: now,
              );

              await visitRepo.createVisit(newVisit);

              if (context.mounted) {
                // Navigate to Consultation
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConsultationScreen(visitId: visitId),
                  ),
                );

                // Refresh list on return
                if (mounted) {
                  setState(() {
                    _refreshVisits();
                  });
                }
              }
            },
            backgroundColor: FuturisticColors.neonBlue,
            icon: const Icon(
              Icons.medical_services_outlined,
              color: Colors.white,
            ),
            label: Text(
              'Start Visit',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(Patient patient) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 100, bottom: 32, left: 24, right: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Slate 800
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [FuturisticColors.neonBlue, Colors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Center(
              child: Text(
                patient.name.isNotEmpty ? patient.name[0].toUpperCase() : '?',
                style: GoogleFonts.outfit(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            patient.name,
            style: GoogleFonts.outfit(
              fontSize: responsiveValue<double>(context, mobile: 22, tablet: 24, desktop: 28),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${patient.gender} • ${patient.age} years',
            style: GoogleFonts.outfit(fontSize: 16, color: Colors.white70),
          ),
          if (patient.phone != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone, size: 16, color: FuturisticColors.neonBlue),
                const SizedBox(width: 6),
                Text(
                  patient.phone!,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: FuturisticColors.neonBlue,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStats(String lastVisit, String totalVisits) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Last Visit',
              lastVisit,
              Icons.calendar_today_rounded,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'Total Visits',
              totalVisits,
              Icons.history_rounded,
              Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalProfile(Patient patient) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Medical Profile',
            style: GoogleFonts.outfit(
              fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          // Blood Group
          _buildInfoRow(
            'Blood Group',
            patient.bloodGroup.isNotEmpty ? patient.bloodGroup : 'Unknown',
          ),
          _buildInfoRow(
            'Allergies',
            patient.allergies.isNotEmpty
                ? patient.allergies.join(', ')
                : 'None',
          ),
          _buildInfoRow(
            'Chronic Conditions',
            patient.chronicConditions.isNotEmpty
                ? patient.chronicConditions.join(', ')
                : 'None',
          ),
          _buildInfoRow(
            'Emergency Contact',
            patient.emergencyContactName.isNotEmpty
                ? patient.emergencyContactName
                : 'None',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.outfit(color: Colors.white60, fontSize: 16),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitHistory(List<Visit> visits) {
    return Container(
      padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Visits',
                style: GoogleFonts.outfit(
                  fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (visits.isNotEmpty)
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'View All',
                    style: GoogleFonts.outfit(color: FuturisticColors.neonBlue),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (visits.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'No visits recorded yet',
                  style: GoogleFonts.outfit(color: Colors.white38),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visits.take(5).length,
              separatorBuilder: (c, i) => const Divider(color: Colors.white10),
              itemBuilder: (context, index) {
                final visit = visits[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FuturisticColors.neonBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.assignment_ind_rounded,
                      color: FuturisticColors.neonBlue,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    DateFormat('MMM d, yyyy • h:mm a').format(visit.visitDate),
                    style: GoogleFonts.outfit(color: Colors.white),
                  ),
                  subtitle: Text(
                    visit.diagnosis.isNotEmpty
                        ? visit.diagnosis
                        : 'No diagnosis',
                    style: GoogleFonts.outfit(color: Colors.white38),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: visit.status == 'completed'
                          ? Colors.green.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      visit.status.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: visit.status == 'completed'
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ),
                  onTap: () {
                    // Navigate to Consultation View (Read Only) or Edit
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ConsultationScreen(visitId: visit.id),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
