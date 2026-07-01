import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/di/service_locator.dart';
import '../core/repository/customers_repository.dart';
import '../core/session/session_manager.dart';
import '../providers/app_state_providers.dart';

class EditCustomerScreen extends ConsumerStatefulWidget {
  final Customer customer;

  const EditCustomerScreen({super.key, required this.customer});

  @override
  ConsumerState<EditCustomerScreen> createState() => _EditCustomerScreenState();
}

class _EditCustomerScreenState extends ConsumerState<EditCustomerScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _gstinCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.customer.name);
    _phoneCtrl = TextEditingController(text: widget.customer.phone);
    _addressCtrl = TextEditingController(text: widget.customer.address);
    _emailCtrl = TextEditingController(text: widget.customer.email);
    _gstinCtrl = TextEditingController(text: widget.customer.gstin);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          'Edit Customer',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        leading: BackButton(color: isDark ? Colors.white : Colors.black),
      ),
      body: ResponsiveContainer(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildField(
              label: 'Customer Name',
              controller: _nameCtrl,
              icon: Icons.person,
              isDark: isDark,
            ),
            const SizedBox(height: 20),
            _buildField(
              label: 'Phone Number',
              controller: _phoneCtrl,
              icon: Icons.phone,
              isDark: isDark,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            _buildField(
              label: 'Email (Optional)',
              controller: _emailCtrl,
              icon: Icons.email,
              isDark: isDark,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            _buildField(
              label: 'Address (Optional)',
              controller: _addressCtrl,
              icon: Icons.location_on,
              isDark: isDark,
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            _buildField(
              label: 'GSTIN (Optional)',
              controller: _gstinCtrl,
              icon: Icons.receipt,
              isDark: isDark,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveCustomer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            prefixIcon: Icon(icon, color: Colors.blueAccent),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.blueAccent),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveCustomer() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showError('Name is required');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = sl<SessionManager>().ownerId;
      if (userId == null) throw Exception('User not logged in');

      final updated = widget.customer.copyWith(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        gstin: _gstinCtrl.text.trim(),
      );

      final result = await sl<CustomersRepository>().updateCustomer(
        updated,
        userId: userId,
      );

      if (result.isSuccess && mounted) {
        Navigator.pop(context, result.data);
      } else if (mounted) {
        _showError(result.errorMessage ?? 'Failed to update customer');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    _gstinCtrl.dispose();
    super.dispose();
  }
}
