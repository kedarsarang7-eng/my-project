// ============================================================================
// ACADEMIC COACHING — FACULTY MANAGEMENT SCREEN
// ============================================================================
// Modern grid with faculty cards, payroll summary, and assignment tracking

import 'package:flutter/material.dart';
import '../../data/models/ac_models.dart';
import '../../data/repositories/ac_repository.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';

class AcFacultyScreen extends StatefulWidget {
  const AcFacultyScreen({super.key});

  @override
  State<AcFacultyScreen> createState() => _AcFacultyScreenState();
}

class _AcFacultyScreenState extends State<AcFacultyScreen> {
  late AcRepository _repository;
  List<AcFaculty> _faculty = [];
  List<AcBatch> _batches = [];
  bool _isLoading = true;
  String? _error;

  String _searchQuery = '';
  EmploymentType? _selectedType;
  Map<String, Map<String, dynamic>> _payrollData = {};

  @override
  void initState() {
    super.initState();
    _repository = AcRepository(sl<ApiClient>());
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final [faculty, batches] = await Future.wait([
        _repository.listFaculty(),
        _repository.listBatches(),
      ]);

      setState(() {
        _faculty = faculty as List<AcFaculty>;
        _batches = batches as List<AcBatch>;
        _isLoading = false;
      });

      // Load payroll for each faculty
      for (var f in _faculty) {
        _loadPayroll(f.id);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load faculty: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPayroll(String facultyId) async {
    try {
      final currentMonth = DateTime.now().toIso8601String().substring(0, 7);
      final payroll = await _repository.getFacultyPayroll(
        facultyId,
        month: currentMonth,
      );
      setState(() {
        _payrollData[facultyId] = payroll;
      });
    } catch (e) {
      debugPrint('Failed to load payroll for $facultyId: $e');
    }
  }

  List<AcFaculty> get _filteredFaculty {
    return _faculty.where((f) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!f.name.toLowerCase().contains(query) &&
            !(f.email?.toLowerCase().contains(query) ?? false) &&
            !f.phone.contains(query)) {
          return false;
        }
      }
      if (_selectedType != null && f.employmentType != _selectedType) {
        return false;
      }
      return true;
    }).toList();
  }

  List<AcBatch> _getFacultyBatches(String facultyId) {
    return _batches.where((b) => b.facultyIds.contains(facultyId)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildFilters(),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _buildError()
                  : _buildFacultyGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Faculty Management',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_faculty.where((f) => f.isActive).length} active faculty members',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          ],
        ),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _showAddFacultyDialog(),
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Add Faculty'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search faculty by name, email, or phone...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<EmploymentType?>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: 'Employment Type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Types')),
                ...EmploymentType.values.map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.name.replaceAll('_', ' ').toUpperCase()),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _selectedType = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacultyGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.1,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: _filteredFaculty.length,
      itemBuilder: (context, index) {
        final faculty = _filteredFaculty[index];
        final payroll = _payrollData[faculty.id];
        final batches = _getFacultyBatches(faculty.id);

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1),
                      child: Text(
                        faculty.name[0],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            faculty.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            faculty.email ?? '—',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: faculty.isActive
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        faculty.isActive ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: faculty.isActive
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Employment Type & Specialization
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        faculty.employmentType.name
                            .replaceAll('_', ' ')
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (faculty.specialization.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          faculty.specialization.first.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Stats Row
                Row(
                  children: [
                    _buildStatBox(
                      label: 'Classes',
                      value: '${payroll?['totalClasses'] ?? 0}',
                      icon: Icons.class_,
                      color: const Color(0xFF4F46E5),
                    ),
                    const SizedBox(width: 12),
                    _buildStatBox(
                      label: 'Batches',
                      value: '${batches.length}',
                      icon: Icons.groups,
                      color: const Color(0xFF059669),
                    ),
                    const SizedBox(width: 12),
                    _buildStatBox(
                      label: 'Salary',
                      value:
                          '₹${((payroll?['netSalary'] ?? 0) / 1000).toStringAsFixed(1)}k',
                      icon: Icons.payments,
                      color: const Color(0xFFDC2626),
                    ),
                  ],
                ),
                const Spacer(),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _viewPayroll(faculty),
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text('Payroll'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _editFaculty(faculty),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _markAttendance(faculty),
                      icon: const Icon(Icons.fact_check, size: 18),
                      label: const Text('Attendance'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatBox({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
          const SizedBox(height: 16),
          Text(_error ?? 'An error occurred'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  void _showAddFacultyDialog() {
    // Add faculty dialog — pending feature gate
  }

  void _viewPayroll(AcFaculty faculty) {
    // Show payroll details — pending feature gate
  }

  void _editFaculty(AcFaculty faculty) {
    // Edit faculty dialog — pending feature gate
  }

  void _markAttendance(AcFaculty faculty) {
    // Mark faculty attendance — pending feature gate
  }
}
