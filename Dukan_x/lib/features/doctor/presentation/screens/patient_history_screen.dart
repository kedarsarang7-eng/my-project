import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/visits_repository.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../models/visit.dart';
import '../../data/repositories/prescription_repository.dart';
import '../../models/patient_model.dart';
import '../../models/prescription_model.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Patient History Screen - Timeline of all visits and prescriptions
///
/// Features:
/// - Complete timeline of patient's visits
/// - Expandable cards with diagnosis, prescriptions, bills
/// - Quick access to past prescription details
class PatientHistoryScreen extends ConsumerStatefulWidget {
  final PatientModel patient;

  const PatientHistoryScreen({super.key, required this.patient});

  @override
  ConsumerState<PatientHistoryScreen> createState() =>
      _PatientHistoryScreenState();
}

class _PatientHistoryScreenState extends ConsumerState<PatientHistoryScreen> {
  final _visitsRepo = sl<VisitsRepository>();
  final _prescriptionRepo = sl<PrescriptionRepository>();

  List<Visit> _visits = [];
  final Map<String, PrescriptionModel?> _prescriptions = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    try {
      final result = await _visitsRepo.getVisitsForPatient(widget.patient.id);

      if (result.data != null) {
        _visits = result.data!;

        // Load prescriptions for each visit
        for (final visit in _visits) {
          if (visit.prescriptionId != null) {
            final prescription = await _prescriptionRepo.getPrescriptionById(
              visit.prescriptionId!,
            );
            _prescriptions[visit.id] = prescription;
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopContentContainer(
      title: 'Medical History',
      subtitle: widget.patient.name,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _visits.isEmpty
          ? _buildEmptyState()
          : _buildTimeline(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No visit history found',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This patient has no recorded visits yet',
            style: TextStyle(color: Colors.white.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _visits.length,
      itemBuilder: (context, index) {
        final visit = _visits[index];
        final isFirst = index == 0;
        final isLast = index == _visits.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline line and dot
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  if (!isFirst)
                    Container(
                      width: 2,
                      height: 20,
                      color: FuturisticColors.primary.withOpacity(0.3),
                    ),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: visit.status == 'completed'
                          ? Colors.green
                          : FuturisticColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: FuturisticColors.background,
                        width: 2,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 100,
                      color: FuturisticColors.primary.withOpacity(0.3),
                    ),
                ],
              ),
            ),

            // Visit card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 16),
                child: _buildVisitCard(visit),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVisitCard(Visit visit) {
    final prescription = _prescriptions[visit.id];
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Card(
      color: FuturisticColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(
          visit.status == 'completed' ? Icons.check_circle : Icons.pending,
          color: visit.status == 'completed' ? Colors.green : Colors.orange,
        ),
        title: Text(
          dateFormat.format(visit.visitDate),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          visit.diagnosis.isNotEmpty
              ? visit.diagnosis
              : 'No diagnosis recorded',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          // Chief Complaint
          if (visit.chiefComplaint.isNotEmpty)
            _buildDetailRow('Chief Complaint', visit.chiefComplaint),

          // Symptoms
          if (visit.symptoms.isNotEmpty)
            _buildDetailRow('Symptoms', visit.symptoms.join(', ')),

          // Diagnosis
          if (visit.diagnosis.isNotEmpty)
            _buildDetailRow('Diagnosis', visit.diagnosis),

          // Vitals
          _buildVitalsSection(visit),

          // Prescription
          if (prescription != null) ...[
            const Divider(color: Colors.white24),
            _buildPrescriptionSection(prescription),
          ],

          // Bill info
          if (visit.billId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.receipt, size: 16, color: Colors.green.shade300),
                  const SizedBox(width: 8),
                  Text(
                    'Bill Generated',
                    style: TextStyle(color: Colors.green.shade300),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsSection(Visit visit) {
    final vitals = <String>[];

    if (visit.bp != null && visit.bp!.isNotEmpty) {
      vitals.add('BP: ${visit.bp}');
    }
    if (visit.pulse != null) {
      vitals.add('Pulse: ${visit.pulse} bpm');
    }
    if (visit.temperature != null) {
      vitals.add('Temp: ${visit.temperature}°F');
    }
    if (visit.weight != null) {
      vitals.add('Weight: ${visit.weight} kg');
    }
    if (visit.spO2 != null) {
      vitals.add('SpO2: ${visit.spO2}%');
    }

    if (vitals.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: vitals
            .map(
              (v) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: FuturisticColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  v,
                  style: TextStyle(
                    color: FuturisticColors.primary,
                    fontSize: 12,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildPrescriptionSection(PrescriptionModel prescription) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.medication, size: 16, color: Colors.cyan),
            const SizedBox(width: 8),
            Text(
              'Prescription',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...prescription.items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 6, color: Colors.white54),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${item.medicineName} ${item.dosage ?? ''} - ${item.frequency ?? ''} (${item.duration ?? ''})',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (prescription.advice?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Advice: ${prescription.advice}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}
