import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../core/di/service_locator.dart';
import '../../models/patient_model.dart';
import '../../services/patient_service.dart';
import '../../data/repositories/patient_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class AddPatientScreen extends ConsumerStatefulWidget {
  const AddPatientScreen({super.key});

  @override
  ConsumerState<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends ConsumerState<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();
  final _allergiesController = TextEditingController(); // New

  // Date of Birth (Req 2.30 — derive age from DOB)
  DateTime? _dateOfBirth;
  final _dobController = TextEditingController();

  // Chronic Conditions
  final List<String> _commonConditions = [
    'Diabetes',
    'Hypertension',
    'Asthma',
    'Thyroid',
    'Heart Disease',
    'Arthritis',
    'Kidney Disease',
  ];
  final Set<String> _selectedConditions = {};

  String _selectedGender = 'Male';
  String _selectedBloodGroup = 'Unknown';
  bool _isLoading = false;

  /// Derives age from the selected DOB.
  int? get _derivedAge {
    if (_dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - _dateOfBirth!.year;
    if (now.month < _dateOfBirth!.month ||
        (now.month == _dateOfBirth!.month && now.day < _dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(DateTime.now().year - 25),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select Date of Birth',
    );
    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
        // Auto-fill age from DOB
        _ageController.text = (_derivedAge ?? '').toString();
      });
    }
  }

  /// Basic duplicate detection: check if a patient with the same phone already
  /// exists. Returns the existing patient if found, null otherwise.
  Future<PatientModel?> _checkDuplicateByPhone(String phone) async {
    if (phone.isEmpty) return null;
    final results = await sl<PatientRepository>().searchPatients(phone);
    return results.cast<PatientModel?>().firstWhere(
      (p) => p?.phone == phone,
      orElse: () => null,
    );
  }

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();

    // Duplicate detection (Req 2.29): warn if a patient with same phone exists.
    final duplicate = await _checkDuplicateByPhone(phone);
    if (duplicate != null && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Possible Duplicate'),
          content: Text(
            'A patient named "${duplicate.name}" already exists with phone '
            '$phone. Do you want to register a new patient anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Register Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isLoading = true);

    try {
      final newId = const Uuid().v4();
      final now = DateTime.now();

      // Use derived age from DOB if available, else fallback to manual entry.
      final age = _derivedAge ?? int.tryParse(_ageController.text.trim());

      final patient = PatientModel(
        id: newId,
        name: _nameController.text.trim(),
        phone: phone,
        age: age,
        gender: _selectedGender,
        bloodGroup: _selectedBloodGroup,
        address: _addressController.text.trim(),
        chronicConditions: _selectedConditions.join(','),
        allergies: _allergiesController.text.trim(),
        dateOfBirth: _dateOfBirth,
        createdAt: now,
        updatedAt: now,
      );

      // Save to DB
      await sl<PatientRepository>().createPatient(patient);

      // Auto-generate QR
      await sl<PatientService>().generateQrToken(newId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient registered successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopContentContainer(
      title: 'Register New Patient',
      subtitle: 'Create a new patient record',
      actions: [
        PrimaryButton(
          label: _isLoading ? 'Saving...' : 'Register Patient',
          icon: _isLoading ? null : Icons.save,
          onPressed: _isLoading ? null : _savePatient,
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: FuturisticColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: FuturisticColors.accent1.withOpacity(0.1),
              ),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: responsiveValue<double>(
                        context,
                        mobile: 16,
                        tablet: 18,
                        desktop: 20,
                      ),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      icon: Icon(Icons.person),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      icon: Icon(Icons.phone),
                      hintText: '10-digit mobile number',
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Phone is required';
                      final digits = v.trim().replaceAll(RegExp(r'\D'), '');
                      if (digits.length != 10)
                        return 'Enter a valid 10-digit mobile number';
                      if (!RegExp(r'^[6-9]').hasMatch(digits)) {
                        return 'Indian mobile numbers start with 6–9';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date of Birth (Req 2.30)
                  TextFormField(
                    controller: _dobController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Date of Birth',
                      icon: const Icon(Icons.calendar_today),
                      hintText: 'Tap to select',
                      suffixIcon: _dateOfBirth != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() {
                                _dateOfBirth = null;
                                _dobController.clear();
                              }),
                            )
                          : null,
                    ),
                    onTap: _pickDateOfBirth,
                  ),
                  const SizedBox(height: 16),

                  // Age & Gender Row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ageController,
                          decoration: InputDecoration(
                            labelText: 'Age',
                            icon: const Icon(Icons.cake),
                            hintText: _dateOfBirth != null
                                ? 'Derived from DOB'
                                : 'Enter manually or pick DOB',
                          ),
                          keyboardType: TextInputType.number,
                          readOnly: _dateOfBirth != null,
                          validator: (v) {
                            // If DOB is set, age is auto-derived — no manual validation needed.
                            if (_dateOfBirth != null) return null;
                            if (v == null || v.trim().isEmpty)
                              return 'Age or DOB required';
                            final age = int.tryParse(v.trim());
                            if (age == null || age < 0 || age > 150) {
                              return 'Enter a valid age (0–150)';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedGender,
                          decoration: const InputDecoration(
                            labelText: 'Gender',
                            icon: Icon(Icons.male),
                          ),
                          items: ['Male', 'Female', 'Other']
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedGender = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Blood Group
                  DropdownButtonFormField<String>(
                    value: _selectedBloodGroup,
                    decoration: const InputDecoration(
                      labelText: 'Blood Group',
                      icon: Icon(Icons.bloodtype),
                    ),
                    items:
                        [
                              'Unknown',
                              'A+',
                              'A-',
                              'B+',
                              'B-',
                              'O+',
                              'O-',
                              'AB+',
                              'AB-',
                            ]
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _selectedBloodGroup = v!),
                  ),
                  const SizedBox(height: 16),

                  // Address
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      icon: Icon(Icons.home),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  // Medical History Section
                  const Text(
                    'Medical History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Chronic Conditions Chips
                  const Text(
                    'Chronic Conditions:',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _commonConditions.map((condition) {
                      final isSelected = _selectedConditions.contains(
                        condition,
                      );
                      return FilterChip(
                        label: Text(condition),
                        selected: isSelected,
                        selectedColor: FuturisticColors.primary.withOpacity(
                          0.2,
                        ),
                        checkmarkColor: FuturisticColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? FuturisticColors.primary
                              : Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedConditions.add(condition);
                            } else {
                              _selectedConditions.remove(condition);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Allergies
                  TextFormField(
                    controller: _allergiesController,
                    decoration: const InputDecoration(
                      labelText: 'Allergies (Optional)',
                      icon: Icon(Icons.warning_amber),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 32),

                  // Actions
                  // Removed bottom button as it is in the header actions now
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
