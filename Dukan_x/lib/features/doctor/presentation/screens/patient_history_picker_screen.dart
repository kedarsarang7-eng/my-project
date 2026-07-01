import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../data/repositories/patient_repository.dart';
import '../../models/patient_model.dart';
import 'patient_history_screen.dart';

/// A picker screen for the `patient_history` sidebar item.
///
/// Shows a searchable patient list. Once a patient is selected the full
/// [PatientHistoryScreen] timeline is rendered inline — no extra navigation.
/// This satisfies Requirement 2.15 (the history/timeline view is reachable)
/// while keeping the sidebar handler synchronous.
class PatientHistoryPickerScreen extends ConsumerStatefulWidget {
  const PatientHistoryPickerScreen({super.key});

  @override
  ConsumerState<PatientHistoryPickerScreen> createState() =>
      _PatientHistoryPickerScreenState();
}

class _PatientHistoryPickerScreenState
    extends ConsumerState<PatientHistoryPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  PatientModel? _selectedPatient;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Once a patient is selected, show the full history screen.
    if (_selectedPatient != null) {
      return Column(
        children: [
          _buildBackBar(),
          Expanded(child: PatientHistoryScreen(patient: _selectedPatient!)),
        ],
      );
    }

    // Otherwise show the patient picker.
    return DesktopContentContainer(
      title: 'Patient History',
      subtitle: 'Select a patient to view their medical history',
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),

          // Patient list
          Expanded(
            child: StreamBuilder<List<PatientModel>>(
              stream: sl<PatientRepository>().watchAllPatients(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading patients: ${snapshot.error}'),
                  );
                }

                final patients = (snapshot.data ?? []).where((p) {
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery.toLowerCase();
                  return p.name.toLowerCase().contains(q) ||
                      (p.phone?.toLowerCase().contains(q) ?? false);
                }).toList();

                if (patients.isEmpty) {
                  return const Center(child: Text('No patients found.'));
                }

                return ListView.builder(
                  itemCount: patients.length,
                  itemBuilder: (context, index) {
                    final patient = patients[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          patient.name.isNotEmpty
                              ? patient.name[0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(patient.name),
                      subtitle: Text(patient.phone ?? ''),
                      trailing: const Icon(Icons.history),
                      onTap: () {
                        setState(() {
                          _selectedPatient = patient;
                        });
                      },
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

  Widget _buildBackBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to patient list',
            onPressed: () {
              setState(() {
                _selectedPatient = null;
              });
            },
          ),
          const SizedBox(width: 8),
          Text(
            'History for ${_selectedPatient?.name ?? ''}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
