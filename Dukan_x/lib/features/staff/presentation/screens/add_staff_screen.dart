import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import 'package:drift/drift.dart' show Value;
import '../../../../core/database/app_database.dart';
import '../../../../widgets/ui/futuristic_button.dart';
import '../../services/staff_service.dart';
import '../../data/models/staff_model.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Add/Edit Staff Screen
class AddStaffScreen extends StatefulWidget {
  final StaffModel? staff;

  const AddStaffScreen({super.key, this.staff});

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = sl<StaffService>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _salaryController;

  StaffRole _selectedRole = StaffRole.salesperson;
  SalaryType _selectedSalaryType = SalaryType.monthly;
  DateTime _joinedDate = DateTime.now();
  bool _isLoading = false;

  bool get _isEditing => widget.staff != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.staff?.name ?? '');
    _phoneController = TextEditingController(text: widget.staff?.phone ?? '');
    _emailController = TextEditingController(text: widget.staff?.email ?? '');
    _addressController = TextEditingController(
      text: widget.staff?.address ?? '',
    );
    _salaryController = TextEditingController(
      text: widget.staff?.baseSalary.toStringAsFixed(0) ?? '',
    );

    if (widget.staff != null) {
      _selectedRole = widget.staff!.role;
      _selectedSalaryType = widget.staff!.salaryType;
      _joinedDate = widget.staff!.joinedAt;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Staff' : 'Add Staff'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Basic Info Section
            _buildSectionHeader('Basic Information', Icons.person),
            const SizedBox(height: 12),
            _buildCard(
              isDark,
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person_outline,
                  isDark: isDark,
                  validator: (v) =>
                      v?.isEmpty == true ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone_outlined,
                  isDark: isDark,
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      v?.isEmpty == true ? 'Phone is required' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email (Optional)',
                  icon: Icons.email_outlined,
                  isDark: isDark,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _addressController,
                  label: 'Address (Optional)',
                  icon: Icons.location_on_outlined,
                  isDark: isDark,
                  maxLines: 2,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Role & Salary Section
            _buildSectionHeader('Role & Salary', Icons.work),
            const SizedBox(height: 12),
            _buildCard(
              isDark,
              children: [
                // Role Dropdown
                DropdownButtonFormField<StaffRole>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: StaffRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(_formatRole(role)),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedRole = v!),
                ),
                const SizedBox(height: 16),

                // Salary Type
                DropdownButtonFormField<SalaryType>(
                  value: _selectedSalaryType,
                  decoration: InputDecoration(
                    labelText: 'Salary Type',
                    prefixIcon: const Icon(Icons.schedule),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: SalaryType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_formatSalaryType(type)),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedSalaryType = v!),
                ),
                const SizedBox(height: 16),

                // Salary Amount
                _buildTextField(
                  controller: _salaryController,
                  label: _getSalaryLabel(),
                  icon: Icons.currency_rupee,
                  isDark: isDark,
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      v?.isEmpty == true ? 'Salary is required' : null,
                ),
                const SizedBox(height: 16),

                // Joined Date
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Joined Date',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '${_joinedDate.day}/${_joinedDate.month}/${_joinedDate.year}',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              height: 54,
              child: FuturisticButton.success(
                label: _isLoading
                    ? 'Saving...'
                    : (_isEditing ? 'Update Staff' : 'Add Staff'),
                icon: Icons.save,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _saveStaff,
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildCard(bool isDark, {required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatRole(StaffRole role) {
    switch (role) {
      case StaffRole.admin:
        return 'Admin';
      case StaffRole.manager:
        return 'Manager';
      case StaffRole.cashier:
        return 'Cashier';
      case StaffRole.salesperson:
        return 'Salesperson';
      case StaffRole.stockKeeper:
        return 'Stock Keeper';
      case StaffRole.accountant:
        return 'Accountant';
      case StaffRole.delivery:
        return 'Delivery';
      case StaffRole.caterer:
        return 'Caterer';
    }
  }

  String _formatSalaryType(SalaryType type) {
    switch (type) {
      case SalaryType.monthly:
        return 'Monthly';
      case SalaryType.daily:
        return 'Daily';
      case SalaryType.hourly:
        return 'Hourly';
    }
  }

  String _getSalaryLabel() {
    switch (_selectedSalaryType) {
      case SalaryType.monthly:
        return 'Monthly Salary (₹)';
      case SalaryType.daily:
        return 'Daily Rate (₹)';
      case SalaryType.hourly:
        return 'Hourly Rate (₹)';
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _joinedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _joinedDate = date);
    }
  }

  Future<void> _saveStaff() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final userId = sl<SessionManager>().ownerId;
    if (userId == null) {
      _showError('Not logged in');
      return;
    }

    try {
      final companion = StaffMembersCompanion(
        name: Value(_nameController.text.trim()),
        phone: Value(_phoneController.text.trim()),
        email: Value(
          _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
        ),
        address: Value(
          _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
        ),
        role: Value(_selectedRole.name.toUpperCase()),
        baseSalary: Value(double.parse(_salaryController.text)),
        salaryType: Value(_selectedSalaryType.name.toUpperCase()),
        joinedAt: Value(_joinedDate),
      );

      if (_isEditing) {
        await _service.updateStaff(widget.staff!.id, companion);
      } else {
        await _service.createStaff(companion);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Failed to save: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
