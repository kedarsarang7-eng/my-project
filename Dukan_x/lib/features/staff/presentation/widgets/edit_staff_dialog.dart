import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/staff_profile_model.dart';
import '../providers/staff_management_provider.dart' hide selectedStaffProvider;
import '../providers/selected_staff_provider.dart';

/// Edit Staff Dialog
class EditStaffDialog extends ConsumerStatefulWidget {
  final String staffId;

  const EditStaffDialog({
    super.key,
    required this.staffId,
  });

  @override
  ConsumerState<EditStaffDialog> createState() => _EditStaffDialogState();
}

class _EditStaffDialogState extends ConsumerState<EditStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  
  StaffRole? _selectedRole;
  bool _isActive = true;
  bool _isLoading = true;
  // ignore: unused_field
  StaffProfileModel? _staff;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _loadStaff();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    final staff = await ref.read(selectedStaffProvider.notifier).loadStaff(widget.staffId);
    if (staff != null) {
      setState(() {
        _staff = staff;
        _nameController.text = staff.fullName;
        _phoneController.text = staff.phoneNumber;
        _emailController.text = staff.email ?? '';
        _selectedRole = staff.role;
        _isActive = staff.isActive;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(staffManagementProvider);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(32),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Text(
                          'Edit Staff Account',
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
                            _buildTextField(
                              controller: _nameController,
                              label: 'Full Name *',
                              validator: (v) => v?.isEmpty == true ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _phoneController,
                              label: 'Phone Number *',
                              keyboardType: TextInputType.phone,
                              validator: (v) => (v?.length ?? 0) < 10 ? 'Invalid phone' : null,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _emailController,
                              label: 'Email (Optional)',
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 24),
                            
                            // Role selector
                            const Text(
                              'Role',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildRoleSelector(),
                            
                            const SizedBox(height: 24),
                            
                            // Status toggle
                            Row(
                              children: [
                                const Text(
                                  'Account Status:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Switch(
                                  value: _isActive,
                                  onChanged: (value) => setState(() => _isActive = value),
                                  activeColor: const Color(0xFF10B981),
                                ),
                                Text(
                                  _isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _isActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                    fontWeight: FontWeight.w500,
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
                        ElevatedButton(
                          onPressed: state.isUpdating ? null : _updateStaff,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: state.isUpdating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save Changes'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
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
            child: Text(
              role.displayName,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? color : const Color(0xFF374151),
              ),
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

  Future<void> _updateStaff() async {
    if (!_formKey.currentState!.validate()) return;

    final request = UpdateStaffRequest(
      fullName: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      role: _selectedRole,
      isActive: _isActive,
    );

    final success = await ref.read(staffManagementProvider.notifier).updateStaff(
      widget.staffId,
      request,
    );
    
    if (success && mounted) {
      Navigator.pop(context);
    }
  }
}
