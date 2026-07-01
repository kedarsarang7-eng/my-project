import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../models/patient.dart';
import '../../../../core/repository/patients_repository.dart';
import '../../../../core/repository/customers_repository.dart';
import '../../../../core/di/service_locator.dart';
import 'package:uuid/uuid.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class PatientRegistrationScreen extends ConsumerStatefulWidget {
  const PatientRegistrationScreen({super.key});

  @override
  ConsumerState<PatientRegistrationScreen> createState() =>
      _PatientRegistrationScreenState();
}

class _PatientRegistrationScreenState
    extends ConsumerState<PatientRegistrationScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSaving = false;

  // Form Data
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  String _gender = 'Male';
  String _bloodGroup = 'O+';
  final _allergiesController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];
  final List<String> _genders = ['Male', 'Female', 'Other'];

  void _nextStep() {
    if (_currentStep < 2) {
      if (_currentStep == 0) {
        if (_nameController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter patient name')),
          );
          return;
        }
      } else if (_currentStep == 1) {
        if (_ageController.text.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Please enter age')));
          return;
        }
      }

      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _savePatient();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _savePatient() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final userId = ref.read(authStateProvider).userId;

      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Logic to Link or Create Customer
      String linkedCustomerId = '';
      if (_phoneController.text.isNotEmpty) {
        final custRepo = sl<CustomersRepository>();
        // Check existing
        final existing = await custRepo.getByPhone(
          _phoneController.text.trim(),
        );
        if (existing.isSuccess && existing.data != null) {
          linkedCustomerId = existing.data!.id;
        } else {
          // Create new customer
          final newCust = await custRepo.createCustomer(
            userId: userId,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            // Optional: Add more fields if available
          );
          if (newCust.isSuccess && newCust.data != null) {
            linkedCustomerId = newCust.data!.id;
          }
        }
      }

      final patient = Patient(
        id: const Uuid().v4(),
        userId: userId,
        customerId: linkedCustomerId, // Linked Customer ID
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        age: int.tryParse(_ageController.text) ?? 0,
        gender: _gender,
        bloodGroup: _bloodGroup,
        allergies: _allergiesController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        chronicConditions: _conditionsController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        emergencyContactName: _emergencyNameController.text.trim(),
        emergencyContactPhone: _emergencyPhoneController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save using repository
      // Already handled customer linking above

      await sl<PatientsRepository>().createPatient(patient);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient registered successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving patient: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FuturisticColors.backgroundDark,
      body: BoundedBox(
        maxWidth: 800,
        child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [FuturisticColors.backgroundDark, Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _prevStep,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'New Patient Registration',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Progress Indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _buildProgressDot(0),
                    _buildProgressLine(0),
                    _buildProgressDot(1),
                    _buildProgressLine(1),
                    _buildProgressDot(2),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Wizard Pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [_buildStep1(), _buildStep2(), _buildStep3()],
                ),
              ),

              // Bottom Navigation
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0)
                      TextButton(
                        onPressed: _prevStep,
                        child: Text(
                          'Back',
                          style: GoogleFonts.outfit(color: Colors.white70),
                        ),
                      )
                    else
                      const SizedBox(),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FuturisticColors.neonBlue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _currentStep == 2
                                  ? 'Complete Registration'
                                  : 'Next Step',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildProgressDot(int step) {
    bool isActive = _currentStep >= step;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive
            ? FuturisticColors.neonBlue
            : Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
        border: isActive
            ? null
            : Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: FuturisticColors.neonBlue.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Center(
        child: Text(
          '${step + 1}',
          style: GoogleFonts.outfit(
            color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressLine(int step) {
    bool isActive = _currentStep > step;
    return Expanded(
      child: Container(
        height: 2,
        color: isActive
            ? FuturisticColors.neonBlue
            : Colors.white.withOpacity(0.1),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Basic Information', style: _headerStyle),
          const SizedBox(height: 8),
          Text(
            'Enter patient\'s primary contact details.',
            style: _subHeaderStyle,
          ),
          const SizedBox(height: 32),
          _buildTextField(
            controller: _nameController,
            label: 'Full Name',
            icon: Icons.person_rounded,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _phoneController,
            label: 'Phone Number',
            icon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Demographics', style: _headerStyle),
          const SizedBox(height: 8),
          Text('Physical attributes and vital stats.', style: _subHeaderStyle),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _ageController,
                  label: 'Age',
                  icon: Icons.cake_rounded,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdown(
                  value: _gender,
                  items: _genders,
                  label: 'Gender',
                  onChanged: (v) => setState(() => _gender = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDropdown(
            value: _bloodGroup,
            items: _bloodGroups,
            label: 'Blood Group',
            onChanged: (v) => setState(() => _bloodGroup = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Medical Profile', style: _headerStyle),
          const SizedBox(height: 8),
          Text(
            'Known allergies and chronic conditions.',
            style: _subHeaderStyle,
          ),
          const SizedBox(height: 32),
          _buildTextField(
            controller: _allergiesController,
            label: 'Allergies (comma separated)',
            icon: Icons.warning_amber_rounded,
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _conditionsController,
            label: 'Chronic Conditions',
            icon: Icons.favorite_border_rounded,
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24),
          const SizedBox(height: 20),
          Text(
            'Emergency Contact',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emergencyNameController,
            label: 'Contact Name',
            icon: Icons.contact_phone_rounded,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _emergencyPhoneController,
            label: 'Contact Phone',
            icon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: controller,
        style: GoogleFonts.outfit(color: Colors.white),
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: GoogleFonts.outfit(color: Colors.white.withOpacity(0.5)),
          icon: Icon(icon, color: FuturisticColors.neonBlue),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required String label,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(e, style: GoogleFonts.outfit(color: Colors.white)),
              ),
            )
            .toList(),
        onChanged: onChanged,
        dropdownColor: const Color(0xFF1E293B),
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: GoogleFonts.outfit(color: Colors.white.withOpacity(0.5)),
        ),
      ),
    );
  }

  TextStyle get _headerStyle => GoogleFonts.outfit(
    fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  TextStyle get _subHeaderStyle => GoogleFonts.outfit(
    fontSize: 16,
    color: Colors.white70,
  );
}
