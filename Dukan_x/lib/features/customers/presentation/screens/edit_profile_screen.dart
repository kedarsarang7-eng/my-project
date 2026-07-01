// ============================================================================
// EDIT PROFILE SCREEN
// ============================================================================
// Uses Riverpod+Repository pattern to update customer details
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/customers_repository.dart';
import '../../../../core/session/session_manager.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final Customer currentProfile;

  const EditProfileScreen({super.key, required this.currentProfile});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _gstinController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentProfile.name);
    _phoneController = TextEditingController(
      text: widget.currentProfile.phone ?? '',
    );
    _emailController = TextEditingController(
      text: widget.currentProfile.email ?? '',
    );
    _addressController = TextEditingController(
      text: widget.currentProfile.address ?? '',
    );
    _gstinController = TextEditingController(
      text: widget.currentProfile.gstin ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _gstinController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updated = widget.currentProfile.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        gstin: _gstinController.text.trim().isEmpty
            ? null
            : _gstinController.text.trim(),
      );

      final session = sl<SessionManager>();

      // We need to update the customer record associated with the current shop (ownerId)
      // NOTE: This updates the vendor's record of the customer.
      // Ideally, there should also be a central "User Profile" update if we want self-details to sync across all shops.
      // For now, consistent with current architecture, we update the customer record in the current context.

      final result = await sl<CustomersRepository>().updateCustomer(
        updated,
        userId: session.ownerId!, // Update in context of current shop
      );

      if (mounted) {
        if (result.data != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Update failed: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Edit Profile",
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: Text(
                "SAVE",
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Personal Details"),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _nameController,
                label: "Full Name",
                icon: Icons.person_outline,
                validator: (v) =>
                    v?.isEmpty == true ? "Name is required" : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _phoneController,
                label: "Phone Number",
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                // Usually phone is read-only or verified, but letting edit for now as per "Edit Profile" req
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                label: "Email Address",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 32),
              _buildSectionTitle("Address & Business"),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _addressController,
                label: "Address",
                icon: Icons.location_on_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _gstinController,
                label: "GSTIN (Optional)",
                icon: Icons.receipt_long_outlined,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
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
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}
