import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/staff_profile_model.dart';
import '../providers/staff_management_provider.dart';

/// Create Staff Dialog
/// Full-screen dialog for creating new staff members
class CreateStaffDialog extends ConsumerStatefulWidget {
  const CreateStaffDialog({super.key});

  @override
  ConsumerState<CreateStaffDialog> createState() => _CreateStaffDialogState();
}

class _CreateStaffDialogState extends ConsumerState<CreateStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyRelationController = TextEditingController();
  
  StaffRole _selectedRole = StaffRole.pumpOperator;
  TimeOfDay _shiftStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _shiftEnd = const TimeOfDay(hour: 17, minute: 0);
  final Set<String> _workingDays = {'MON', 'TUE', 'WED', 'THU', 'FRI'};
  
  CreateStaffResponse? _createdStaff;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(staffManagementProvider);

    if (_createdStaff != null) {
      return _buildSuccessView();
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 800,
        height: 700,
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Text(
                    'Create New Staff Account',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 24),
              
              // Form content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Personal Information
                      _buildSectionTitle('Personal Information'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _nameController,
                              label: 'Full Name *',
                              hint: 'Enter staff full name',
                              validator: (v) => v?.isEmpty == true ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _phoneController,
                              label: 'Phone Number *',
                              hint: 'Enter phone number',
                              keyboardType: TextInputType.phone,
                              validator: (v) => (v?.length ?? 0) < 10 ? 'Invalid phone' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email (Optional)',
                        hint: 'Enter email address',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Role Selection
                      _buildSectionTitle('Role & Permissions'),
                      const SizedBox(height: 16),
                      _buildRoleSelector(),
                      
                      const SizedBox(height: 32),
                      
                      // Shift Timing
                      _buildSectionTitle('Shift Timing'),
                      const SizedBox(height: 16),
                      _buildShiftTiming(),
                      
                      const SizedBox(height: 32),
                      
                      // Working Days
                      _buildSectionTitle('Working Days'),
                      const SizedBox(height: 12),
                      _buildWorkingDaysSelector(),
                      
                      const SizedBox(height: 32),
                      
                      // Emergency Contact
                      _buildSectionTitle('Emergency Contact (Optional)'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _emergencyNameController,
                              label: 'Name',
                              hint: 'Contact name',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _emergencyPhoneController,
                              label: 'Phone',
                              hint: 'Contact phone',
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _emergencyRelationController,
                              label: 'Relation',
                              hint: 'e.g., Spouse, Parent',
                            ),
                          ),
                        ],
                      ),
                      
                      if (state.updateError != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade600),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  state.updateError!,
                                  style: TextStyle(color: Colors.red.shade600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: state.isCreating ? null : _createStaff,
                    icon: state.isCreating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add),
                    label: Text(state.isCreating ? 'Creating...' : 'Create Staff'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF374151),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: StaffRole.values.map((role) {
        final isSelected = _selectedRole == role;
        final color = _getRoleColor(role);
        
        return InkWell(
          onTap: () => setState(() => _selectedRole = role),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
              border: Border.all(
                color: isSelected ? color : const Color(0xFFD1D5DB),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Icon(Icons.check_circle, color: color, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  role.displayName,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? color : const Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getRoleColor(StaffRole role) {
    switch (role) {
      case StaffRole.cashier:
        return const Color(0xFF10B981);
      case StaffRole.pumpOperator:
        return const Color(0xFFF59E0B);
      case StaffRole.supervisor:
        return const Color(0xFF8B5CF6);
      case StaffRole.manager:
        return const Color(0xFF3B82F6);
      case StaffRole.admin:
        return const Color(0xFFEF4444);
    }
  }

  Widget _buildShiftTiming() {
    return Row(
      children: [
        Expanded(
          child: _buildTimePicker(
            label: 'Start Time',
            time: _shiftStart,
            onTap: () => _selectTime(true),
          ),
        ),
        const SizedBox(width: 16),
        const Icon(Icons.arrow_forward, color: Color(0xFF9CA3AF)),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTimePicker(
            label: 'End Time',
            time: _shiftEnd,
            onTap: () => _selectTime(false),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 20, color: Color(0xFF6B7280)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                Text(
                  time.format(context),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStart ? _shiftStart : _shiftEnd,
    );
    if (time != null) {
      setState(() {
        if (isStart) {
          _shiftStart = time;
        } else {
          _shiftEnd = time;
        }
      });
    }
  }

  Widget _buildWorkingDaysSelector() {
    final days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    
    return Wrap(
      spacing: 8,
      children: days.map((day) {
        final isSelected = _workingDays.contains(day);
        
        return FilterChip(
          label: Text(day),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _workingDays.add(day);
              } else {
                _workingDays.remove(day);
              }
            });
          },
          selectedColor: const Color(0xFFDBEAFE),
          checkmarkColor: const Color(0xFF2563EB),
          labelStyle: TextStyle(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF374151),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        );
      }).toList(),
    );
  }

  Future<void> _createStaff() async {
    if (!_formKey.currentState!.validate()) return;
    if (_workingDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one working day')),
      );
      return;
    }

    final request = CreateStaffRequest(
      fullName: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      role: _selectedRole,
      shiftTiming: ShiftTiming(
        start: '${_shiftStart.hour.toString().padLeft(2, '0')}:${_shiftStart.minute.toString().padLeft(2, '0')}',
        end: '${_shiftEnd.hour.toString().padLeft(2, '0')}:${_shiftEnd.minute.toString().padLeft(2, '0')}',
        days: _workingDays.toList(),
      ),
      emergencyContact: _emergencyNameController.text.isEmpty
          ? null
          : EmergencyContact(
              name: _emergencyNameController.text.trim(),
              phone: _emergencyPhoneController.text.trim(),
              relation: _emergencyRelationController.text.trim(),
            ),
    );

    final response = await ref.read(staffManagementProvider.notifier).createStaff(request);
    
    if (response != null) {
      setState(() => _createdStaff = response);
    }
  }

  Widget _buildSuccessView() {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Color(0xFF059669),
                size: 32,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Staff Created Successfully!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_nameController.text} has been added to your team',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildCredentialRow('Staff ID', _createdStaff!.staffId),
                  const Divider(),
                  _buildCredentialRow('Temporary Password', _createdStaff!.temporaryPassword, isPassword: true),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Share these credentials securely with the staff member. They will be required to change their password on first login.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: 'Staff ID: ${_createdStaff!.staffId}\nPassword: ${_createdStaff!.temporaryPassword}',
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Credentials'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value, {bool isPassword = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
        Row(
          children: [
            Text(
              isPassword ? '••••••••••••' : value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
            if (isPassword) ...[
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
