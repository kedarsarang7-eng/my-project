import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../staff/providers/staff_provider.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Add Staff Screen for Petrol Pump
/// 
/// Invite new staff members with role selection
class AddStaffScreen extends ConsumerStatefulWidget {
  const AddStaffScreen({super.key});

  @override
  ConsumerState<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends ConsumerState<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedRole = 'staff';
  bool _isLoading = false;
  String? _invitationResult;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _inviteStaff() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await ref.read(staffListProvider.notifier).inviteStaff(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        role: _selectedRole,
      );

      if (result) {
        setState(() => _invitationResult = 'Staff invited successfully');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: BoundedBox(
          maxWidth: 600,
          child: Padding(
            padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
            child: _invitationResult != null
                ? _buildSuccessView()
                : _buildFormView(),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        Expanded(
          child: Card(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Staff Information',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'Enter staff member\'s full name',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Email
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'Enter email address',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Phone
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number (Optional)',
                        hintText: 'Enter phone number',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),
                    
                    // Role Selection
                    Text(
                      'Role',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    context.isMobile
                        ? Column(
                            children: [
                              _buildRoleCard(
                                'staff',
                                'Staff',
                                'Can process payments and view own transactions',
                                Icons.person_outline,
                              ),
                              const SizedBox(height: 12),
                              _buildRoleCard(
                                'manager',
                                'Manager',
                                'Can manage staff and view all reports',
                                Icons.manage_accounts_outlined,
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _buildRoleCard(
                                  'staff',
                                  'Staff',
                                  'Can process payments and view own transactions',
                                  Icons.person_outline,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildRoleCard(
                                  'manager',
                                  'Manager',
                                  'Can manage staff and view all reports',
                                  Icons.manage_accounts_outlined,
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 32),
                    
                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : () => Navigator.maybePop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _inviteStaff,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.person_add),
                            label: Text(_isLoading ? 'Inviting...' : 'Invite Staff'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add New Staff',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Invite a new staff member to your petrol pump',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleCard(String role, String title, String description, IconData icon) {
    final isSelected = _selectedRole == role;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: isSelected ? AppTheme.primaryColor : Colors.grey),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppTheme.primaryColor : null,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Card(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, size: 64, color: AppTheme.successColor),
              ),
              const SizedBox(height: 24),
              Text(
                'Staff Invited Successfully!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Share these credentials with ${_nameController.text}',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
              const SizedBox(height: 32),
              Container(
                padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.email_outlined),
                        const SizedBox(width: 8),
                        Text(_emailController.text),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Temporary Password',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _invitationResult!,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () => _copyToClipboard(_invitationResult!),
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copy password',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.maybePop(context),
                      child: const Text('Back to Staff List'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _invitationResult = null;
                          _nameController.clear();
                          _emailController.clear();
                          _phoneController.clear();
                          _selectedRole = 'staff';
                        });
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text('Invite Another'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
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
}
