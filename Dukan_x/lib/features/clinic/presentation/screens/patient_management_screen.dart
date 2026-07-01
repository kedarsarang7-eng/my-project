// Clinic - Patient Management Screen
// Real API integration with action panel for Edit/View/Delete

import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';
import '../../../shared/widgets/entity_action_panel.dart';
import '../../data/models/patient_model.dart';
import '../../data/repositories/clinic_repository.dart';

class PatientManagementScreen extends StatefulWidget {
  const PatientManagementScreen({super.key});

  @override
  State<PatientManagementScreen> createState() =>
      _PatientManagementScreenState();
}

class _PatientManagementScreenState extends State<PatientManagementScreen> {
  final ClinicRepository _repository = ClinicRepository(sl<ApiClient>());

  List<Patient> _patients = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _repository.getPatients(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      setState(() {
        _patients = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load patients: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _onDeletePatient(Patient patient) async {
    final confirmed = await DeleteConfirmationDialog.show(
      context: context,
      entityName: 'Patient',
      entityIdentifier: '${patient.name} (${patient.patientId})',
      isSoftDelete: true,
      warningMessage:
          'This will also archive all medical records for this patient.',
    );

    if (!confirmed) return;

    try {
      await _repository.deletePatient(patient.id);

      setState(() {
        _patients.removeWhere((p) => p.id == patient.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Patient ${patient.name} archived'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () => _restorePatient(patient),
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to delete patient: $e');
    }
  }

  Future<void> _restorePatient(Patient patient) async {
    try {
      await _repository.restorePatient(patient.id);
      _loadPatients();
    } catch (e) {
      _showError('Failed to restore patient: $e');
    }
  }

  void _onViewPatient(Patient patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientDetailScreen(patient: patient),
      ),
    );
  }

  void _onEditPatient(Patient patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientEditScreen(patient: patient),
      ),
    ).then((_) => _loadPatients());
  }

  void _onNewAppointment(Patient patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewAppointmentScreen(patient: patient),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Color _getGenderColor(String gender) {
    switch (gender.toLowerCase()) {
      case 'male':
        return Colors.blue;
      case 'female':
        return Colors.pink;
      default:
        return Colors.purple;
    }
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildAppBar(isDark),
          _buildSearchBar(isDark),
          Expanded(
            child: _error != null
                ? _buildErrorWidget()
                : isDesktop
                ? _buildDesktopView()
                : _buildMobileView(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNewPatient(),
        backgroundColor: const Color(0xFF059669), // Medical green
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('New Patient', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_hospital_outlined,
              color: Color(0xFF059669),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Patients',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_patients.length} registered patients',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
          const Spacer(),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPatients),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search patients by name, ID, or phone...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() => _searchQuery = '');
                    _loadPatients();
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
          // Debounce search
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_searchQuery == value) _loadPatients();
          });
        },
      ),
    );
  }

  Widget _buildDesktopView() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: DataTable2(
        columnSpacing: 16,
        horizontalMargin: 16,
        minWidth: 1000,
        columns: const [
          DataColumn2(label: Text('Patient ID'), size: ColumnSize.S),
          DataColumn2(label: Text('Name'), size: ColumnSize.M),
          DataColumn2(label: Text('Age/Gender'), size: ColumnSize.S),
          DataColumn2(label: Text('Contact'), size: ColumnSize.M),
          DataColumn2(label: Text('Last Visit'), size: ColumnSize.S),
          DataColumn2(
            label: Text('Actions'),
            numeric: true,
            size: ColumnSize.S,
          ),
        ],
        rows: _patients.map((patient) => _buildPatientRow(patient)).toList(),
        empty: _buildEmptyState(),
      ),
    );
  }

  DataRow2 _buildPatientRow(Patient patient) {
    final age = patient.dateOfBirth != null
        ? _calculateAge(
            DateTime.fromMillisecondsSinceEpoch(patient.dateOfBirth!),
          )
        : null;

    return DataRow2(
      cells: [
        DataCell(
          Text(
            patient.patientId,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ),
        DataCell(
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _getGenderColor(
                  patient.gender ?? 'unknown',
                ).withValues(alpha: 0.1),
                child: Icon(
                  patient.gender?.toLowerCase() == 'female'
                      ? Icons.female
                      : Icons.male,
                  color: _getGenderColor(patient.gender ?? 'unknown'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      patient.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (patient.bloodGroup != null)
                      Text(
                        'Blood: ${patient.bloodGroup}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Text(
            age != null
                ? '$age yrs / ${patient.gender}'
                : patient.gender ?? '-',
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(patient.phone ?? '-'),
              if (patient.email != null)
                Text(
                  patient.email!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
        DataCell(
          Text(
            patient.lastVisitDate != null
                ? _formatDate(
                    DateTime.fromMillisecondsSinceEpoch(patient.lastVisitDate!),
                  )
                : 'Never',
          ),
        ),
        DataCell(
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'view':
                  _onViewPatient(patient);
                  break;
                case 'edit':
                  _onEditPatient(patient);
                  break;
                case 'appointment':
                  _onNewAppointment(patient);
                  break;
                case 'delete':
                  _onDeletePatient(patient);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'view', child: Text('View Record')),
              const PopupMenuItem(value: 'edit', child: Text('Edit Patient')),
              const PopupMenuItem(
                value: 'appointment',
                child: Text('New Appointment'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Archive Patient',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
            child: const Icon(Icons.more_vert),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildMobileView() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _patients.length,
      itemBuilder: (context, index) {
        final patient = _patients[index];
        return _buildPatientCard(patient);
      },
    );
  }

  Widget _buildPatientCard(Patient patient) {
    final age = patient.dateOfBirth != null
        ? _calculateAge(
            DateTime.fromMillisecondsSinceEpoch(patient.dateOfBirth!),
          )
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: _getGenderColor(
                    patient.gender ?? 'unknown',
                  ).withValues(alpha: 0.1),
                  child: Icon(
                    patient.gender?.toLowerCase() == 'female'
                        ? Icons.female
                        : Icons.male,
                    color: _getGenderColor(patient.gender ?? 'unknown'),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'ID: ${patient.patientId}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                EntityActionPanel.standard(
                  onView: () => _onViewPatient(patient),
                  onEdit: () => _onEditPatient(patient),
                  onDelete: () => _onDeletePatient(patient),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _buildTag(
                  age != null ? '$age yrs' : 'Age unknown',
                  Icons.cake_outlined,
                ),
                const SizedBox(width: 8),
                if (patient.bloodGroup != null)
                  _buildTag(
                    'Blood: ${patient.bloodGroup}',
                    Icons.water_drop_outlined,
                    color: Colors.red,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Phone', patient.phone ?? 'N/A'),
            if (patient.email != null) _buildInfoRow('Email', patient.email!),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _onNewAppointment(patient),
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: const Text('Appointment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _onViewPatient(patient),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color ?? Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: Colors.red[700])),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadPatients, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No patients found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first patient',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _createNewPatient() {
    // Navigate to create patient
  }
}

// Placeholder screens
class PatientDetailScreen extends StatelessWidget {
  final Patient patient;
  const PatientDetailScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(patient.name),
        actions: [
          EntityActionPanel.standard(
            onView: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ],
      ),
      body: Center(child: Text('Patient Record: ${patient.patientId}')),
    );
  }
}

class PatientEditScreen extends StatelessWidget {
  final Patient patient;
  const PatientEditScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit ${patient.name}')),
      body: Center(child: Text('Editing patient record')),
    );
  }
}

class NewAppointmentScreen extends StatelessWidget {
  final Patient patient;
  const NewAppointmentScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('New Appointment - ${patient.name}')),
      body: Center(child: Text('Schedule appointment')),
    );
  }
}
