import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../doctor/data/repositories/prescription_repository.dart';
import '../../../doctor/models/prescription_model.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class MedicalRecordsScreen extends ConsumerStatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  ConsumerState<MedicalRecordsScreen> createState() =>
      _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends ConsumerState<MedicalRecordsScreen> {
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
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.history_edu, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Medical History',
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
            child: StreamBuilder<List<PrescriptionModel>>(
              stream: sl<PrescriptionRepository>().watchPrescriptionsForPatient(
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

                final records = snapshot.data ?? [];

                if (records.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_off,
                          size: 64,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No medical records found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return _buildRecordCard(record);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(PrescriptionModel record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),
        collapsedIconColor: Colors.grey,
        iconColor: FuturisticColors.primary,
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FuturisticColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.description, color: FuturisticColors.primary),
        ),
        title: Text(
          DateFormat('dd MMM yyyy').format(record.date),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Dr. ID: ${record.doctorId.substring(0, 6)}...',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (record.advice != null && record.advice!.isNotEmpty)
              Text(
                'Advice: ${record.advice}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black12,
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MEDICINES',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                ...record.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.medication_liquid,
                          size: 16,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.medicineName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${item.dosage ?? ''} • ${item.frequency ?? ''} • ${item.duration ?? ''}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              if (item.instructions != null)
                                Text(
                                  '${item.instructions}',
                                  style: TextStyle(
                                    color: FuturisticColors.accent2,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (record.advice != null) ...[
                  const Text(
                    'ADVICE',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    record.advice!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
