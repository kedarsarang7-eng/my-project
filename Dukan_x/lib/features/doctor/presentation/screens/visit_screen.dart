import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/session/owner_id_resolver.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../core/repository/bills_repository.dart';
import '../../../../core/repository/visits_repository.dart';
import '../../../../models/visit.dart';
import '../../../../screens/bill_detail.dart';
import '../../data/repositories/lab_report_repository.dart';
import '../../data/repositories/medical_template_repository.dart';
import '../../data/repositories/patient_repository.dart';
import '../../data/repositories/prescription_repository.dart';
import '../../models/lab_report_model.dart';
import '../../models/medical_template_model.dart';
import '../../models/patient_model.dart';
import '../../services/clinic_billing_service.dart';
import '../../services/patient_access_logger.dart';
import '../widgets/lab_test_selector.dart';
import 'add_prescription_screen.dart';

import '../../../../features/billing/services/barcode_scanner_service.dart';
import '../../../../features/clinic/providers/clinic_dashboard_providers.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/modern_ui_components.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Visit Screen - Core OPD Workflow
///
/// Data Flow: Patient → Vitals → Symptoms → Diagnosis → Prescription → Bill
///
/// This screen handles a complete doctor-patient encounter:
/// 1. Patient selection (from appointment or search)
/// 2. Vitals recording (BP, Temp, Pulse, Weight, SpO2)
/// 3. Symptoms input (multi-select chips)
/// 4. Diagnosis with template support
/// 5. Prescription creation (navigates to AddPrescriptionScreen)
/// 6. Lab test ordering
/// 7. Bill generation (auto-includes consultation fee)
class VisitScreen extends ConsumerStatefulWidget {
  final String? appointmentId;
  final String? patientId;
  final String? patientName;

  const VisitScreen({
    super.key,
    this.appointmentId,
    this.patientId,
    this.patientName,
  });

  @override
  ConsumerState<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends ConsumerState<VisitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = sl<AppDatabase>();
  final _visitsRepo = sl<VisitsRepository>();
  final _billingService = sl<ClinicBillingService>();
  final _prescriptionRepo = sl<PrescriptionRepository>();
  final _labReportRepo = sl<LabReportRepository>();
  final _templateRepo = sl<MedicalTemplateRepository>();

  // Patient selection
  PatientModel? _selectedPatient;
  List<PatientModel> _patientSearchResults = [];
  final _patientSearchController = TextEditingController();

  // Vitals
  final _bpController = TextEditingController();
  final _pulseController = TextEditingController();
  final _tempController = TextEditingController();
  final _weightController = TextEditingController();
  final _spO2Controller = TextEditingController();

  // Clinical data
  final _chiefComplaintController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();

  // Selected symptoms
  final Set<String> _selectedSymptoms = {};

  // Selected Lab Tests
  final List<Map<String, dynamic>> _selectedLabTests = [];

  // Templates
  List<MedicalTemplateModel> _diagnosisTemplates = [];

  // Visit state
  String _visitId = '';
  String _visitStatus = 'WAITING';
  String? _prescriptionId;
  String? _billId;
  bool _isSubmitting = false;

  // Common symptoms for quick selection
  static const List<String> _commonSymptoms = [
    'Fever',
    'Headache',
    'Cough',
    'Cold',
    'Body Pain',
    'Fatigue',
    'Nausea',
    'Vomiting',
    'Diarrhea',
    'Dizziness',
    'Chest Pain',
    'Breathlessness',
    'Skin Rash',
    'Joint Pain',
    'Abdominal Pain',
    'Loss of Appetite',
    'Weight Loss',
    'Insomnia',
  ];

  @override
  void initState() {
    super.initState();
    _visitId = const Uuid().v4();
    _loadInitialPatient();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    // Read path: fail safe — skip the (cross-tenant) template load when no
    // authenticated owner is available instead of bucketing under 'SYSTEM'.
    final String docId;
    try {
      docId = resolveOwnerId(operation: 'load diagnosis templates');
    } on OwnerIdMissingException {
      return;
    }
    final templates = await _templateRepo.getTemplatesByType(
      docId,
      'DIAGNOSIS',
    );
    if (mounted) setState(() => _diagnosisTemplates = templates);
  }

  Future<void> _saveAsTemplate(String text, String type) async {
    if (text.isEmpty) return;

    // Write path: block the template write when no owner id is available and
    // surface an error — never attribute to 'SYSTEM'.
    final String docId;
    try {
      docId = resolveOwnerId(operation: 'save diagnosis template');
    } on OwnerIdMissingException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot save template — no active clinic session.'),
          ),
        );
      }
      return;
    }
    final template = MedicalTemplateModel(
      id: const Uuid().v4(),
      userId: docId,
      type: type,
      title: text,
      content: text,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _templateRepo.createTemplate(template);
    _loadTemplates();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved as template')));
    }
  }

  Future<void> _loadInitialPatient() async {
    if (widget.patientId != null) {
      final patient = await sl<PatientRepository>().getPatientById(
        widget.patientId!,
      );
      if (patient != null && mounted) {
        setState(() => _selectedPatient = patient);
      } else if (mounted) {
        // Fallback if patient not found
        setState(
          () => _selectedPatient = PatientModel(
            id: widget.patientId!,
            name: widget.patientName ?? 'Patient',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }
    }
  }

  Future<void> _searchPatients(String query) async {
    if (query.isEmpty) {
      setState(() => _patientSearchResults = []);
      return;
    }

    final filtered = await sl<PatientRepository>().searchPatients(query);

    if (mounted) {
      setState(() => _patientSearchResults = filtered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorId = sl<SessionManager>().ownerId ?? '';
    // RBAC: Only doctor/admin (clinical roles) can view diagnosis & private notes.
    final canAccessClinicalContent = ref.watch(
      canAccessClinicalContentProvider,
    );

    return DesktopContentContainer(
      title: 'Visit',
      subtitle: 'Doctor Consultation',
      actions: [
        if (_visitStatus == 'IN_PROGRESS')
          PrimaryButton(label: 'Save', icon: Icons.save, onPressed: _saveVisit),
      ],
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Banner
              _buildStatusBanner(),
              const SizedBox(height: 24),

              // Patient Selection
              _buildPatientSection(),
              const SizedBox(height: 24),

              // Vitals Section
              _buildVitalsSection(),
              const SizedBox(height: 24),

              // Symptoms Section
              _buildSymptomsSection(),
              const SizedBox(height: 24),

              // Diagnosis Section — gated by clinical role (ClinicRole check)
              if (canAccessClinicalContent)
                _buildDiagnosisSection()
              else
                _buildRestrictedClinicalContentPlaceholder('Diagnosis'),
              const SizedBox(height: 24),

              // Notes Section — gated by clinical role (ClinicRole check)
              if (canAccessClinicalContent)
                _buildNotesSection()
              else
                _buildRestrictedClinicalContentPlaceholder('Private Notes'),
              const SizedBox(height: 32),
              // Action Buttons
              _buildActionButtons(doctorId),
            ],
          ),
        ),
      ),
    );
  }

  /// Placeholder shown to non-clinical roles (receptionist, nurse) for gated
  /// sections. Keeps the layout consistent while clearly communicating access
  /// restrictions per ClinicRole permissions.
  Widget _buildRestrictedClinicalContentPlaceholder(String sectionName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: Colors.grey.shade500, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$sectionName — clinical notes restricted (doctor access only)',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (_visitStatus) {
      case 'WAITING':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_top;
        statusText = 'Waiting - Select patient to start';
        break;
      case 'IN_PROGRESS':
        statusColor = FuturisticColors.primary;
        statusIcon = Icons.medical_services;
        statusText = 'Consultation in progress';
        break;
      case 'COMPLETED':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Visit completed';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
        statusText = 'Unknown status';
    }

    return Semantics(
      label: 'Visit status: $statusText',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                statusText,
                style: GoogleFonts.inter(
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (_selectedPatient != null &&
                _selectedPatient!.bloodGroup?.isNotEmpty == true)
              Semantics(
                label: 'Blood group: ${_selectedPatient!.bloodGroup}',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bloodtype, color: Colors.red, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _selectedPatient!.bloodGroup!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientSection() {
    return _buildSection(
      title: 'Patient',
      icon: Icons.person,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedPatient != null) ...[
            // Chronic Condition & Allergy Alert
            if ((_selectedPatient!.chronicConditions != null &&
                    _selectedPatient!.chronicConditions!.isNotEmpty) ||
                (_selectedPatient!.allergies != null &&
                    _selectedPatient!.allergies!.isNotEmpty))
              Semantics(
                label:
                    'Medical alert: '
                    '${_selectedPatient!.chronicConditions?.isNotEmpty == true ? "Chronic conditions: ${_selectedPatient!.chronicConditions}. " : ""}'
                    '${_selectedPatient!.allergies?.isNotEmpty == true ? "Allergies: ${_selectedPatient!.allergies}" : ""}',
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.warning_amber_rounded, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            '⚠ Medical Alert',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      if (_selectedPatient!.chronicConditions?.isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Chronic: ${_selectedPatient!.chronicConditions}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (_selectedPatient!.allergies?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: const [
                            Icon(Icons.dangerous, color: Colors.red, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'ALLERGIES:',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_selectedPatient!.allergies}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // Selected patient card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FuturisticColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: FuturisticColors.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: FuturisticColors.primary,
                    child: Text(
                      _selectedPatient!.name.isNotEmpty
                          ? _selectedPatient!.name[0].toUpperCase()
                          : 'P',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedPatient!.name,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${_selectedPatient!.age ?? '--'} yrs • ${_selectedPatient!.gender ?? '--'} • ${_selectedPatient!.phone ?? '--'}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
                    ),
                    onPressed: () => setState(() {
                      _selectedPatient = null;
                      _visitStatus = 'WAITING';
                    }),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Patient search
            TextField(
              controller: _patientSearchController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search patient by name or phone...',
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.5),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.5),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    Icons.qr_code_scanner,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  onPressed: _scanPatientQR,
                  tooltip: 'Scan Patient QR',
                ),
                filled: true,
                fillColor: FuturisticColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _searchPatients,
            ),

            // Search results
            if (_patientSearchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: FuturisticColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _patientSearchResults.length,
                  itemBuilder: (context, index) {
                    final patient = _patientSearchResults[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          patient.name.isNotEmpty ? patient.name[0] : 'P',
                        ),
                      ),
                      title: Text(
                        patient.name,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        patient.phone ?? '',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedPatient = patient;
                          _patientSearchResults = [];
                          _patientSearchController.clear();
                          _visitStatus = 'IN_PROGRESS';
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildVitalsSection() {
    return _buildSection(
      title: 'Vitals',
      icon: Icons.favorite,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildVitalInput(
                  _bpController,
                  'BP',
                  'mmHg',
                  Icons.favorite,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVitalInput(
                  _pulseController,
                  'Pulse',
                  'bpm',
                  Icons.timeline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildVitalInput(
                  _tempController,
                  'Temp',
                  '°F',
                  Icons.thermostat,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVitalInput(
                  _weightController,
                  'Weight',
                  'kg',
                  Icons.monitor_weight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildVitalInput(_spO2Controller, 'SpO2', '%', Icons.air),
        ],
      ),
    );
  }

  Widget _buildVitalInput(
    TextEditingController controller,
    String label,
    String suffix,
    IconData icon,
  ) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return TextFormField(
      controller: controller,
      style: TextStyle(color: onSurface),
      keyboardType: TextInputType.number,
      validator: _getVitalValidator(label),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: onSurface.withOpacity(0.7)),
        suffixText: suffix,
        suffixStyle: TextStyle(color: onSurface.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: FuturisticColors.primary, size: 20),
        filled: true,
        fillColor: FuturisticColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  /// Returns a validator callback for clinical vital signs.
  /// Enforces plausible ranges (Req 2.28):
  ///   SpO2: 0–100 %
  ///   Pulse: 20–300 bpm
  ///   Temp: 90–110 °F (or 32–43 °C — using °F per UI suffix)
  ///   Weight: 0.5–500 kg
  ///   BP: format "systolic/diastolic" with systolic 40–300, diastolic 20–200
  String? Function(String?)? _getVitalValidator(String label) {
    switch (label) {
      case 'SpO2':
        return (value) {
          if (value == null || value.trim().isEmpty) return null; // optional
          final v = double.tryParse(value.trim());
          if (v == null) return 'Enter a valid number';
          if (v < 0 || v > 100) return 'SpO2 must be 0–100';
          return null;
        };
      case 'Pulse':
        return (value) {
          if (value == null || value.trim().isEmpty) return null;
          final v = int.tryParse(value.trim());
          if (v == null) return 'Enter a valid number';
          if (v < 20 || v > 300) return 'Pulse must be 20–300 bpm';
          return null;
        };
      case 'Temp':
        return (value) {
          if (value == null || value.trim().isEmpty) return null;
          final v = double.tryParse(value.trim());
          if (v == null) return 'Enter a valid number';
          if (v < 90 || v > 110) return 'Temperature must be 90–110 °F';
          return null;
        };
      case 'Weight':
        return (value) {
          if (value == null || value.trim().isEmpty) return null;
          final v = double.tryParse(value.trim());
          if (v == null) return 'Enter a valid number';
          if (v < 0.5 || v > 500) return 'Weight must be 0.5–500 kg';
          return null;
        };
      case 'BP':
        return (value) {
          if (value == null || value.trim().isEmpty) return null;
          // Accept format: "120/80" or just a systolic number
          final parts = value.trim().split('/');
          if (parts.length == 2) {
            final sys = int.tryParse(parts[0].trim());
            final dia = int.tryParse(parts[1].trim());
            if (sys == null || dia == null) {
              return 'Use format: systolic/diastolic (e.g. 120/80)';
            }
            if (sys < 40 || sys > 300) return 'Systolic must be 40–300 mmHg';
            if (dia < 20 || dia > 200) return 'Diastolic must be 20–200 mmHg';
          } else if (parts.length == 1) {
            final sys = int.tryParse(parts[0].trim());
            if (sys == null) return 'Enter a valid BP (e.g. 120/80)';
            if (sys < 40 || sys > 300) return 'Systolic must be 40–300 mmHg';
          } else {
            return 'Use format: systolic/diastolic (e.g. 120/80)';
          }
          return null;
        };
      default:
        return null;
    }
  }

  Widget _buildSymptomsSection() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return _buildSection(
      title: 'Symptoms',
      icon: Icons.sick,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chief complaint
          TextFormField(
            controller: _chiefComplaintController,
            style: TextStyle(color: onSurface),
            decoration: InputDecoration(
              hintText: 'Chief complaint (e.g., Fever for 3 days)',
              hintStyle: TextStyle(color: onSurface.withOpacity(0.5)),
              filled: true,
              fillColor: FuturisticColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Quick symptom chips
          Text(
            'Quick Select:',
            style: TextStyle(color: onSurface.withOpacity(0.7), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonSymptoms.map((symptom) {
              final isSelected = _selectedSymptoms.contains(symptom);
              return Semantics(
                label: isSelected
                    ? 'Symptom $symptom, selected'
                    : 'Symptom $symptom, not selected',
                child: FilterChip(
                  label: Text(symptom),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSymptoms.add(symptom);
                      } else {
                        _selectedSymptoms.remove(symptom);
                      }
                    });
                  },
                  backgroundColor: FuturisticColors.surface,
                  selectedColor: FuturisticColors.primary.withOpacity(0.3),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? FuturisticColors.primary
                        : onSurface.withOpacity(0.7),
                  ),
                  checkmarkColor: FuturisticColors.primary,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosisSection() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return _buildSection(
      title: 'Diagnosis',
      icon: Icons.medical_information,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _diagnosisController,
            style: TextStyle(color: onSurface),
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Diagnosis',
              labelStyle: TextStyle(color: onSurface.withOpacity(0.7)),
              hintText: 'Enter diagnosis...',
              hintStyle: TextStyle(color: onSurface.withOpacity(0.5)),
              filled: true,
              fillColor: FuturisticColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: onSurface.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: onSurface.withOpacity(0.3)),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  Icons.bookmark_add_outlined,
                  color: onSurface.withOpacity(0.7),
                ),
                tooltip: 'Save as Template',
                onPressed: () =>
                    _saveAsTemplate(_diagnosisController.text, 'DIAGNOSIS'),
              ),
            ),
          ),
          if (_diagnosisTemplates.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Templates:',
              style: TextStyle(color: onSurface.withOpacity(0.7), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _diagnosisTemplates
                  .map(
                    (t) => Semantics(
                      label: 'Apply diagnosis template: ${t.title}',
                      child: ActionChip(
                        label: Text(t.title),
                        backgroundColor: FuturisticColors.primary.withOpacity(
                          0.2,
                        ),
                        labelStyle: TextStyle(color: onSurface),
                        onPressed: () {
                          _diagnosisController.text = t.content;
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return _buildSection(
      title: 'Private Notes',
      icon: Icons.note,
      child: TextFormField(
        controller: _notesController,
        style: TextStyle(color: onSurface),
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Additional notes (only visible to doctor)...',
          hintStyle: TextStyle(color: onSurface.withOpacity(0.5)),
          filled: true,
          fillColor: FuturisticColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(String doctorId) {
    return Column(
      children: [
        // Primary actions row
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.medication,
                label: 'Add Prescription',
                color: FuturisticColors.primary,
                onPressed: _selectedPatient == null
                    ? null
                    : () => _addPrescription(doctorId),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.science,
                label: 'Order Lab Tests',
                color: Colors.orange,
                onPressed: _selectedPatient == null ? null : _orderLabTests,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Generate Bill & Complete
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.receipt_long,
                label: 'Generate Bill',
                color: Colors.green,
                onPressed: _selectedPatient == null
                    ? null
                    : () => _generateBill(doctorId),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.check_circle,
                label: 'Complete Visit',
                color: Colors.teal,
                onPressed: (_selectedPatient == null || _isSubmitting)
                    ? null
                    : () => _completeVisit(doctorId),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed == null ? Colors.grey.shade800 : color,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  // ============================================
  // ACTION HANDLERS
  // ============================================

  Future<void> _scanPatientQR() async {
    final barcode = await sl<BarcodeScannerService>().scanBarcode(context);
    if (barcode != null) {
      if (mounted) {
        // Search for patient by this barcode/QR token
        // Assuming QR contains patient ID or special token
        // For now, assume it's patient ID or search query
        _patientSearchController.text = barcode;
        // Trigger search logic?
        // Or if it is exact ID, fetch directly.
        // Let's settle for setting text and maybe triggering search if needed.
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scanned: $barcode')));
      }
    }
  }

  Future<void> _addPrescription(String doctorId) async {
    if (_selectedPatient == null) return;

    // Save visit first to get visitId
    await _saveVisit();

    // Navigate to prescription screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPrescriptionScreen(
          preSelectedPatientId: _selectedPatient!.id,
          visitId: _visitId,
        ),
      ),
    );

    if (result is String) {
      setState(() => _prescriptionId = result);
    }
  }

  void _orderLabTests() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LabTestSelector(
        onSelected: (tests) async {
          if (tests.isEmpty) return;

          setState(() {
            _selectedLabTests.addAll(tests);
          });

          final doctorId = sl<SessionManager>().ownerId ?? '';

          // Order tests in repository
          for (final test in tests) {
            final reportId = const Uuid().v4();
            test['id'] = reportId; // Store ID for billing linking

            final report = LabReportModel(
              id: reportId,
              patientId: _selectedPatient!.id,
              doctorId: doctorId,
              visitId: _visitId,
              testName: test['name'],
              orderedAt: DateTime.now(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              status: LabReportStatus.pending,
            );

            await _labReportRepo.orderLabTest(report);
          }

          // If bill exists, add immediately
          if (_billId != null) {
            await _billingService.addLabTestsToBill(
              billId: _billId!,
              labTests: tests,
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lab Tests added to Bill')),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lab Tests Ordered')),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _generateBill(String doctorId) async {
    if (_selectedPatient == null) return;

    // Save visit first
    await _saveVisit();

    // Navigate to clinic billing screen (or use existing billing)
    // For now, show confirmation and navigate to general billing with prefilled data

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Bill generated with consultation fee'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'View Bill',
          textColor: Colors.white,
          onPressed: () async {
            if (_billId != null) {
              final billRes = await sl<BillsRepository>().getById(_billId!);
              if (billRes.data != null && mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BillDetailScreen(bill: billRes.data!),
                  ),
                );
              }
            }
          },
        ),
      ),
    );

    // Create bill using service
    try {
      final billId = await _billingService.createBillFromVisit(
        visitId: _visitId,
        doctorId: doctorId,
        patientId: _selectedPatient!.id,
        patientName: _selectedPatient!.name,
      );

      // If prescription exists, add medicines to bill
      if (_prescriptionId != null) {
        final prescription = await _prescriptionRepo.getPrescriptionById(
          _prescriptionId!,
        );
        if (prescription != null) {
          await _billingService.addPrescriptionToBill(
            billId: billId,
            prescription: prescription,
          );
        }
      }

      // If lab tests selected, add to bill
      if (_selectedLabTests.isNotEmpty) {
        await _billingService.addLabTestsToBill(
          billId: billId,
          labTests: _selectedLabTests,
        );
      }

      setState(() => _billId = billId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bill generated with consultation & medicines'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View Bill',
              textColor: Colors.white,
              onPressed: () async {
                final billsRepo = sl<BillsRepository>();
                final result = await billsRepo.getById(billId);

                if (result.data != null && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          BillDetailScreen(bill: result.data!),
                    ),
                  );
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating bill: $e')));
      }
    }
  }

  Future<void> _saveVisit() async {
    if (_selectedPatient == null) return;

    final doctorId = sl<SessionManager>().ownerId ?? '';
    final now = DateTime.now();

    // Build Visit model
    final visit = Visit(
      id: _visitId,
      patientId: _selectedPatient!.id,
      doctorId: doctorId,
      visitDate: now,
      chiefComplaint: _chiefComplaintController.text,
      symptoms: _selectedSymptoms.toList(),
      diagnosis: _diagnosisController.text,
      notes: _notesController.text,
      bp: _bpController.text.isNotEmpty ? _bpController.text : null,
      temperature: double.tryParse(_tempController.text),
      weight: double.tryParse(_weightController.text),
      pulse: int.tryParse(_pulseController.text),
      spO2: int.tryParse(_spO2Controller.text),
      prescriptionId: _prescriptionId,
      billId: _billId,
      status: 'in_progress',
      createdAt: now,
      updatedAt: now,
    );

    // Check if visit exists
    final existingResult = await _visitsRepo.getVisitById(_visitId);

    if (existingResult.data == null) {
      // Create new visit
      await _visitsRepo.createVisit(visit);

      // Log PHI write access (Req 2.11)
      await logPatientAccess(
        db: sl<AppDatabase>(),
        patientId: _selectedPatient!.id,
        userId: doctorId,
        type: PatientAccessType.write,
        description: 'created visit',
      );
    } else {
      // Update existing visit
      await _visitsRepo.updateVisit(visit);

      // Log PHI update access (Req 2.11)
      await logPatientAccess(
        db: sl<AppDatabase>(),
        patientId: _selectedPatient!.id,
        userId: doctorId,
        type: PatientAccessType.update,
        description: 'updated visit',
      );
    }
  }

  Future<void> _completeVisit(String doctorId) async {
    if (_selectedPatient == null) return;

    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now();

      // Build Visit model with completed status
      final visit = Visit(
        id: _visitId,
        patientId: _selectedPatient!.id,
        doctorId: doctorId,
        visitDate: now,
        chiefComplaint: _chiefComplaintController.text,
        symptoms: _selectedSymptoms.toList(),
        diagnosis: _diagnosisController.text,
        notes: _notesController.text,
        bp: _bpController.text.isNotEmpty ? _bpController.text : null,
        temperature: double.tryParse(_tempController.text),
        weight: double.tryParse(_weightController.text),
        pulse: int.tryParse(_pulseController.text),
        spO2: int.tryParse(_spO2Controller.text),
        prescriptionId: _prescriptionId,
        billId: _billId,
        status: 'completed',
        createdAt: now,
        updatedAt: now,
      );

      // Update visit using repository
      await _visitsRepo.updateVisit(visit);

      // Update patient's lastVisitId (keeping direct DB for this patient update)
      await (_db.update(
        _db.patients,
      )..where((t) => t.id.equals(_selectedPatient!.id))).write(
        PatientsCompanion(
          lastVisitId: Value(_visitId),
          lastVisitDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      setState(() => _visitStatus = 'COMPLETED');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visit completed successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Return to previous screen
        Navigator.pop(context, _visitId);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing visit: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _patientSearchController.dispose();
    _bpController.dispose();
    _pulseController.dispose();
    _tempController.dispose();
    _weightController.dispose();
    _spO2Controller.dispose();
    _chiefComplaintController.dispose();
    _diagnosisController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
