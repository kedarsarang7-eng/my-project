import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
// Assuming this package exists or used elsewhere, if not I'll stick to manual glassmorphism
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../models/patient.dart';
// Assuming this exists from previous info
import 'patient_registration_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class PatientListScreen extends ConsumerStatefulWidget {
  const PatientListScreen({super.key});

  @override
  ConsumerState<PatientListScreen> createState() => _PatientListScreenState();
}

enum SortOption { nameAsc, nameDesc, ageAsc, ageDesc }

class _PatientListScreenState extends ConsumerState<PatientListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SortOption _currentSort = SortOption.nameAsc;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get current user ID (Clinic Owner)
    final userId = ref.watch(authStateProvider).userId;

    if (userId == null) {
      return const Scaffold(
        body: BoundedBox(
          maxWidth: 800,
          child: Center(child: Text('Please log in to view patients')),
        ),
      );
    }

    final patientsAsync = ref.watch(patientsStreamProvider(userId));

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: FuturisticColors.backgroundDark, // or use palette
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'My Patients',
          style: GoogleFonts.outfit(
            fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort, color: Colors.white),
            onSelected: (SortOption result) {
              setState(() {
                _currentSort = result;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
              const PopupMenuItem<SortOption>(
                value: SortOption.nameAsc,
                child: Text('Name (A-Z)'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.nameDesc,
                child: Text('Name (Z-A)'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.ageAsc,
                child: Text('Age (Youngest First)'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.ageDesc,
                child: Text('Age (Oldest First)'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PatientRegistrationScreen(),
            ),
          );
        },
        backgroundColor: FuturisticColors.neonBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'New Patient',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              FuturisticColors.backgroundDark,
              Color(0xFF0F172A), // Slate 900
            ],
          ),
        ),
        child: Stack(
          children: [
            // Ambient Gradients
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FuturisticColors.neonBlue.withOpacity(0.1),
                  // Basic blur handled by BackdropFilter if needed
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.outfit(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search by name or phone...',
                          hintStyle: GoogleFonts.outfit(
                            color: Colors.white.withOpacity(0.5),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                  ),

                  // Patient List
                  Expanded(
                    child: patientsAsync.when(
                      data: (patients) {
                        // Filter
                        var filtered = patients.where((p) {
                          final q = _searchQuery.toLowerCase();
                          return p.name.toLowerCase().contains(q) ||
                              (p.phone?.contains(q) ?? false);
                        }).toList();

                        // Sort
                        filtered.sort((a, b) {
                          switch (_currentSort) {
                            case SortOption.nameAsc:
                              return a.name.compareTo(b.name);
                            case SortOption.nameDesc:
                              return b.name.compareTo(a.name);
                            case SortOption.ageAsc:
                              return a.age.compareTo(b.age);
                            case SortOption.ageDesc:
                              return b.age.compareTo(a.age);
                          }
                        });

                        if (filtered.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_search_rounded,
                                  size: 64,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No patients found'
                                      : 'No match for "$_searchQuery"',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final patient = filtered[index];
                            return _buildPatientCard(patient);
                          },
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: FuturisticColors.neonBlue,
                        ),
                      ),
                      error: (err, stack) => Center(
                        child: Text(
                          'Error: $err',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
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

  Widget _buildPatientCard(Patient patient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Navigate to Patient Detail
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Avatar / Initials
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        FuturisticColors.neonBlue.withOpacity(0.8),
                        Colors.purpleAccent.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      patient.name.isNotEmpty
                          ? patient.name[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.outfit(
                        fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        style: GoogleFonts.outfit(
                          fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 14,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${patient.gender} • ${patient.age} yrs',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          if (patient.phone != null &&
                              patient.phone!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.phone_rounded,
                              size: 14,
                              color: Colors.white.withOpacity(0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              patient.phone!,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow
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
