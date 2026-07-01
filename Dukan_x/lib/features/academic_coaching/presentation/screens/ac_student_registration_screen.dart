// ============================================================================
// ACADEMIC COACHING — STUDENT REGISTRATION (4-Step Wizard)
// ============================================================================
// Step 1: Personal Details | Step 2: Academic Info | Step 3: Course & Batch |
// Step 4: Fee Structure & Payment

import 'package:flutter/material.dart';
import '../../data/models/ac_models.dart';
import '../../data/repositories/ac_repository.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';

class AcStudentRegistrationScreen extends StatefulWidget {
  const AcStudentRegistrationScreen({super.key});

  @override
  State<AcStudentRegistrationScreen> createState() =>
      _AcStudentRegistrationScreenState();
}

class _AcStudentRegistrationScreenState
    extends State<AcStudentRegistrationScreen> {
  late AcRepository _repository;
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Personal Details
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _parentPhoneCtrl = TextEditingController();
  final _parentNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String? _gender;
  DateTime? _dob;

  // Step 2: Academic Info
  final _schoolNameCtrl = TextEditingController();
  final _currentClassCtrl = TextEditingController();
  String? _board;

  // Step 3: Course & Batch
  List<AcCourse> _courses = [];
  List<AcBatch> _batches = [];
  String? _selectedCourseId;
  List<String> _selectedBatchIds = [];

  // Step 4: Fee & Payment
  final _referralCtrl = TextEditingController();
  List<Map<String, dynamic>> _feeComponents = [];
  double _totalFee = 0;

  @override
  void initState() {
    super.initState();
    _repository = AcRepository(sl<ApiClient>());
    _loadCoursesAndBatches();
  }

  Future<void> _loadCoursesAndBatches() async {
    try {
      final [courses, batches] = await Future.wait([
        _repository.listCourses(),
        _repository.listBatches(status: 'active'),
      ]);
      setState(() {
        _courses = courses as List<AcCourse>;
        _batches = batches as List<AcBatch>;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _parentPhoneCtrl.dispose();
    _parentNameCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _schoolNameCtrl.dispose();
    _currentClassCtrl.dispose();
    _referralCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Student Registration',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF64748B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Step Indicator
            _buildStepIndicator(),
            const Divider(height: 1),
            // Step Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildStepContent(),
              ),
            ),
            // Navigation Buttons
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Personal', 'Academic', 'Course', 'Fee'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF4F46E5)
                              : isCompleted
                              ? const Color(0xFF059669)
                              : const Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        step,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isActive
                              ? const Color(0xFF4F46E5)
                              : isCompleted
                              ? const Color(0xFF059669)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted
                          ? const Color(0xFF059669)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPersonalDetailsStep();
      case 1:
        return _buildAcademicInfoStep();
      case 2:
        return _buildCourseBatchStep();
      case 3:
        return _buildFeeStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildPersonalDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personal Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Enter the student\'s basic information',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _firstNameCtrl,
                label: 'First Name *',
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _lastNameCtrl,
                label: 'Last Name *',
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDropdown<String>(
                label: 'Gender',
                value: _gender,
                items: const ['Male', 'Female', 'Other'],
                onChanged: (v) => setState(() => _gender = v),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDatePicker(
                label: 'Date of Birth',
                value: _dob,
                onChanged: (v) => setState(() => _dob = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _phoneCtrl,
          label: 'Phone Number *',
          keyboardType: TextInputType.phone,
          validator: (v) {
            if (v?.isEmpty ?? true) return 'Required';
            if (v!.length < 10) return 'Invalid phone number';
            return null;
          },
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
        const Text(
          'Parent/Guardian Information',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _parentNameCtrl,
          label: 'Parent/Guardian Name *',
          validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _parentPhoneCtrl,
          label: 'Parent Phone Number *',
          keyboardType: TextInputType.phone,
          validator: (v) {
            if (v?.isEmpty ?? true) return 'Required';
            if (v!.length < 10) return 'Invalid phone number';
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _emailCtrl,
          label: 'Email (Optional)',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _addressCtrl,
          label: 'Address (Optional)',
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildAcademicInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Academic Information',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Enter the student\'s school and class details',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),
        _buildTextField(controller: _schoolNameCtrl, label: 'School Name'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _currentClassCtrl,
                label: 'Current Class/Grade',
                hint: 'e.g., 10th, 12th, B.Com',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDropdown<String>(
                label: 'Board',
                value: _board,
                items: const ['CBSE', 'ICSE', 'State Board', 'IB', 'Other'],
                onChanged: (v) => setState(() => _board = v),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCourseBatchStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Course & Batch Selection',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select the course and batch for enrollment',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),
        const Text(
          'Select Course *',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ..._courses.map((course) => _buildCourseCard(course)),
        const SizedBox(height: 24),
        const Text(
          'Select Batch(es) *',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ..._batches
            .where((b) => b.status == BatchStatus.active)
            .map((batch) => _buildBatchCard(batch)),
      ],
    );
  }

  Widget _buildCourseCard(AcCourse course) {
    final isSelected = _selectedCourseId == course.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCourseId = course.id;
            // Auto-add course subjects as fee components
            _feeComponents = course.subjects
                .map(
                  (s) => {
                    'name': '${s.name} Tuition Fee',
                    'amount': course.totalFee / course.subjects.length,
                    'isOneTime': false,
                  },
                )
                .toList();
            _calculateTotalFee();
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Radio<String>(
                    value: course.id,
                    groupValue: _selectedCourseId,
                    onChanged: (v) {},
                    activeColor: const Color(0xFF4F46E5),
                  ),
                  Expanded(
                    child: Text(
                      course.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (course.targetExam != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        course.targetExam!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4F46E5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (course.description != null)
                Text(
                  course.description!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: course.subjects
                    .map(
                      (s) => Chip(
                        label: Text(s.name),
                        backgroundColor: const Color(0xFFF1F5F9),
                        side: BorderSide.none,
                        padding: EdgeInsets.zero,
                        labelStyle: const TextStyle(fontSize: 12),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.currency_rupee,
                    size: 16,
                    color: Color(0xFF059669),
                  ),
                  Text(
                    course.totalFee.toStringAsFixed(0),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.schedule,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  Text(
                    course.duration?['value'] != null
                        ? '${course.duration!['value']} ${course.duration!['unit']}'
                        : 'N/A',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatchCard(AcBatch batch) {
    final isSelected = _selectedBatchIds.contains(batch.id);
    final isFull = batch.isFull;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFF4F46E5)
              : isFull
              ? Colors.red
              : const Color(0xFFE2E8F0),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isFull
            ? null
            : () {
                setState(() {
                  if (isSelected) {
                    _selectedBatchIds.remove(batch.id);
                  } else {
                    _selectedBatchIds.add(batch.id);
                  }
                });
              },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: isFull
                    ? null
                    : (v) {
                        setState(() {
                          if (v == true) {
                            _selectedBatchIds.add(batch.id);
                          } else {
                            _selectedBatchIds.remove(batch.id);
                          }
                        });
                      },
                activeColor: const Color(0xFF4F46E5),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          batch.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isFull)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'FULL',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${batch.batchType.name} • ${batch.enrolledCount}/${batch.maxCapacity} students',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    if (batch.schedule.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          batch.schedule
                              .map((s) => '${s.dayName} ${s.startTime}')
                              .join(', '),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: batch.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  batch.status.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: batch.statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fee Structure & Confirmation',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Review the fee components and complete registration',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ..._feeComponents.map((fee) => _buildFeeRow(fee)),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Fee',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '₹${_totalFee.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _referralCtrl,
          label: 'How did you hear about us? (Optional)',
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF4F46E5)),
                  SizedBox(width: 8),
                  Text(
                    'Enrollment Summary',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSummaryRow(
                'Name',
                '${_firstNameCtrl.text} ${_lastNameCtrl.text}',
              ),
              _buildSummaryRow('Phone', _phoneCtrl.text),
              _buildSummaryRow(
                'Course',
                _courses
                    .firstWhere(
                      (c) => c.id == _selectedCourseId,
                      orElse: () => AcCourse(
                        id: '',
                        name: '',
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                    )
                    .name,
              ),
              _buildSummaryRow(
                'Batches',
                '${_selectedBatchIds.length} selected',
              ),
              _buildSummaryRow('Total Fee', '₹${_totalFee.toStringAsFixed(2)}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeeRow(Map<String, dynamic> fee) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fee['name']),
                if (!(fee['isOneTime'] ?? true))
                  const Text(
                    'Monthly',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
              ],
            ),
          ),
          Text(
            '₹${(fee['amount'] as double).toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton.icon(
              onPressed: () => setState(() => _currentStep--),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Previous'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            )
          else
            const SizedBox(),
          Row(
            children: [
              if (_currentStep < 3)
                ElevatedButton.icon(
                  onPressed: _validateAndContinue,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Continue'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _isLoading ? 'Processing...' : 'Complete Registration',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4F46E5)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<String> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
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
        fillColor: Colors.white,
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<T>(value: item as T, child: Text(item)),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? value,
    required void Function(DateTime?) onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate:
              value ?? DateTime.now().subtract(const Duration(days: 365 * 10)),
          firstDate: DateTime(1990),
          lastDate: DateTime.now(),
        );
        if (date != null) onChanged(date);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
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
          fillColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value != null
                  ? '${value.day}/${value.month}/${value.year}'
                  : 'Select Date',
              style: TextStyle(
                color: value != null ? Colors.black : const Color(0xFF64748B),
              ),
            ),
            const Icon(
              Icons.calendar_today,
              size: 18,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  void _validateAndContinue() {
    if (_formKey.currentState!.validate()) {
      if (_currentStep == 2 &&
          (_selectedCourseId == null || _selectedBatchIds.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one course and batch'),
          ),
        );
        return;
      }
      setState(() => _currentStep++);
    }
  }

  void _calculateTotalFee() {
    _totalFee = _feeComponents.fold(
      0,
      (sum, f) => sum + (f['amount'] as double),
    );
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    try {
      final studentData = {
        'firstName': _firstNameCtrl.text,
        'lastName': _lastNameCtrl.text,
        'phone': _phoneCtrl.text,
        'parentPhone': _parentPhoneCtrl.text,
        'parentName': _parentNameCtrl.text,
        'email': _emailCtrl.text.isEmpty ? null : _emailCtrl.text,
        'address': _addressCtrl.text.isEmpty ? null : _addressCtrl.text,
        'gender': _gender,
        'dob': _dob?.toIso8601String(),
        'schoolName': _schoolNameCtrl.text.isEmpty
            ? null
            : _schoolNameCtrl.text,
        'currentClass': _currentClassCtrl.text.isEmpty
            ? null
            : _currentClassCtrl.text,
        'board': _board,
        'enrolledCourseIds': [_selectedCourseId!],
        'enrolledBatchIds': _selectedBatchIds,
        'referralSource': _referralCtrl.text.isEmpty
            ? null
            : _referralCtrl.text,
      };

      final student = await _repository.createStudent(studentData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${student.fullName} registered successfully!'),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
