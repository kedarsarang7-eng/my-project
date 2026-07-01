import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/shop_repository.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstinController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = sessionManager.userId;
    if (userId == null) return;

    final result = await sl<ShopRepository>().getShopProfile(userId);
    final profile = result.data;

    if (profile != null) {
      setState(() {
        _shopNameController.text = profile.shopName ?? '';
        _ownerNameController.text = profile.ownerName ?? '';
        _addressController.text = profile.address ?? '';
        _phoneController.text = profile.phone ?? '';
        _emailController.text = profile.email ?? '';
        _gstinController.text = profile.gstin ?? '';
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = sessionManager.userId;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      await sl<ShopRepository>().updateShopProfile(
        ownerId: userId,
        shopName: _shopNameController.text,
        ownerName: _ownerNameController.text,
        address: _addressController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        gstin: _gstinController.text.toUpperCase(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile Updated Successfully!')),
        );
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
    return Scaffold(
      backgroundColor: FuturisticColors.background,
      appBar: AppBar(
        title: const Text('Business Profile'),
        backgroundColor: FuturisticColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField("Shop Name", _shopNameController, Icons.store),
              _buildTextField("Owner Name", _ownerNameController, Icons.person),
              _buildTextField(
                "Address",
                _addressController,
                Icons.location_on,
                maxLines: 3,
              ),
              _buildTextField(
                "Phone",
                _phoneController,
                Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              _buildTextField(
                "Email",
                _emailController,
                Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              _buildTextField("GSTIN", _gstinController, Icons.receipt_long),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FuturisticColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Save Changes",
                          style: TextStyle(
                            fontSize: 16,
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

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: FuturisticColors.textSecondary),
          border: InputBorder.none,
          icon: Icon(icon, color: FuturisticColors.primary),
        ),
        validator: (value) =>
            value != null && value.isEmpty ? 'Required' : null,
      ),
    );
  }
}
