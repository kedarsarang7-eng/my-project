import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/clinic_repository.dart';
import 'package:intl/intl.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class PatientHistoryScreen extends ConsumerStatefulWidget {
  final String patientId;

  const PatientHistoryScreen({
    super.key,
    required this.patientId,
  });

  @override
  ConsumerState<PatientHistoryScreen> createState() => _PatientHistoryScreenState();
}

class _PatientHistoryScreenState extends ConsumerState<PatientHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    final result = await ref.read(clinicRepositoryProvider).getPatientHistory(widget.patientId);
    
    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load history: ${failure.message}')),
        );
      },
      (history) {
        setState(() {
          _history = history;
        });
      },
    );
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient History'),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('No previous visits found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final visit = _history[index];
                    final date = DateTime.tryParse(visit['date'] ?? '');
                    final dateStr = date != null ? DateFormat.yMMMd().add_jm().format(date) : 'Unknown Date';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        title: Text('Visit: $dateStr'),
                        subtitle: Text('Diagnosis: ${visit['diagnosis'] ?? 'N/A'}'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow('Subjective', visit['soap']?['subjective']),
                                const SizedBox(height: 8),
                                _buildDetailRow('Objective', visit['soap']?['objective']),
                                const SizedBox(height: 8),
                                _buildDetailRow('Plan', visit['soap']?['plan']),
                                const SizedBox(height: 16),
                                if (visit['prescriptions'] != null)
                                  _buildDetailRow('Prescription', visit['prescriptions'].toString()),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value),
      ],
    );
  }
}
