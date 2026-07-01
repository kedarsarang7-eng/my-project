import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../core/di/service_locator.dart';
import '../../models/patient_model.dart';
import '../../data/repositories/patient_repository.dart';
// import 'add_patient_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart'; // Will implement next

class PatientListScreen extends ConsumerStatefulWidget {
  const PatientListScreen({super.key});

  @override
  ConsumerState<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends ConsumerState<PatientListScreen> {
  final TextEditingController _searchController = TextEditingController();
  // Using a stream/future provider or just raw stream from repository for now
  // Ideally use a specialized provider

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DesktopContentContainer(
      title: 'Patient Management',
      subtitle: 'Manage patient records',
      actions: [
        DesktopIconButton(
          icon: Icons.qr_code_scanner,
          tooltip: 'Scan QR',
          onPressed: () {},
        ),
        const SizedBox(width: 8),
        PrimaryButton(
          label: 'Add Patient',
          icon: Icons.person_add,
          onPressed: () {},
        ),
      ],
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: FuturisticColors.surface,
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

          // List
          Expanded(
            child: StreamBuilder<List<PatientModel>>(
              stream: sl<PatientRepository>().watchAllPatients(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final patients = snapshot.data ?? [];
                // Client-side filtering if stream returns all
                final filtered = _searchQuery.isEmpty
                    ? patients
                    : patients
                          .where(
                            (p) =>
                                p.name.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                ) ||
                                (p.phone?.contains(_searchQuery) ?? false),
                          )
                          .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.person_off_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No patients found'
                              : 'No matches found',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final patient = filtered[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ModernCard(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: FuturisticColors.accent1
                                .withOpacity(0.2),
                            child: Text(patient.name[0].toUpperCase()),
                          ),
                          title: Text(
                            patient.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            '${patient.phone} • ${patient.age} yrs • ${patient.gender}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.white70,
                          ),
                          onTap: () {
                            // View Details
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
}
