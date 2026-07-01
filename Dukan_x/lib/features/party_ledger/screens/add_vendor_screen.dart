import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/vendors_repository.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../providers/app_state_providers.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class AddVendorScreen extends ConsumerStatefulWidget {
  const AddVendorScreen({super.key});

  @override
  ConsumerState<AddVendorScreen> createState() => _AddVendorScreenState();
}

class _AddVendorScreenState extends ConsumerState<AddVendorScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController gstinController = TextEditingController();
  bool _isSaving = false;

  Future<void> _addVendor() async {
    if (nameController.text.trim().isEmpty) {
      _showError("Vendor name is required");
      return;
    }

    final email = emailController.text.trim();
    if (email.isNotEmpty && !_isValidEmail(email)) {
      _showError("Please enter a valid email address");
      return;
    }

    final phone = phoneController.text.trim();
    if (phone.isNotEmpty && phone.replaceAll(RegExp(r'\D'), '').length < 10) {
      _showError("Phone number must have at least 10 digits");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = sl<SessionManager>().ownerId;
      if (userId == null) throw Exception("User not logged in");

      final newVendor = Vendor(
        id: const Uuid().v4(),
        userId: userId,
        name: nameController.text.trim(),
        phone: phone.isEmpty ? null : phone,
        email: email.isEmpty ? null : email,
        address: addressController.text.trim().isEmpty
            ? null
            : addressController.text.trim(),
        gstin: gstinController.text.trim().isEmpty
            ? null
            : gstinController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await sl<VendorsRepository>().createVendor(newVendor);

      if (result.isSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vendor added successfully!")),
        );
        Navigator.pop(context, result.data);
      } else if (mounted) {
        _showError(result.errorMessage ?? "Failed to add vendor");
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

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeStateProvider);
    final isDark = themeState.isDark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          "Add Vendor",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        leading: BackButton(color: isDark ? Colors.white : Colors.black),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: SingleChildScrollView(
        padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildField(
              label: "Vendor Name",
              controller: nameController,
              icon: Icons.store,
              isDark: isDark,
              hint: "Enter vendor/supplier name",
            ),
            const SizedBox(height: 20),
            _buildField(
              label: "Phone Number",
              controller: phoneController,
              icon: Icons.phone,
              isDark: isDark,
              hint: "Enter phone number",
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            _buildField(
              label: "Email (Optional)",
              controller: emailController,
              icon: Icons.email,
              isDark: isDark,
              hint: "Enter email address",
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            _buildField(
              label: "Address (Optional)",
              controller: addressController,
              icon: Icons.location_on,
              isDark: isDark,
              hint: "Enter vendor address",
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            _buildField(
              label: "GSTIN (Optional)",
              controller: gstinController,
              icon: Icons.receipt,
              isDark: isDark,
              hint: "Enter GST number",
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _addVendor,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
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
                        "Create Vendor",
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
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isDark,
    required String hint,
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
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
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

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    emailController.dispose();
    gstinController.dispose();
    super.dispose();
  }
}
