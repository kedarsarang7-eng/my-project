import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/customers_repository.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../providers/app_state_providers.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController gstinController = TextEditingController();
  bool _isSaving = false;

  Future<void> _addCustomer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = sl<SessionManager>().ownerId;
      if (userId == null) throw Exception("User not logged in");

      final result = await sl<CustomersRepository>().createCustomer(
        userId: userId,
        name: nameController.text.trim(),
        phone: phoneController.text.trim().isEmpty
            ? null
            : phoneController.text.trim(),
        email: emailController.text.trim().isEmpty
            ? null
            : emailController.text.trim(),
        address: addressController.text.trim().isEmpty
            ? null
            : addressController.text.trim(),
        gstin: gstinController.text.trim().isEmpty
            ? null
            : gstinController.text.trim(),
      );

      if (result.isSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Customer added successfully!")),
        );
        Navigator.pop(context, result.data);
      } else if (mounted) {
        _showError(result.errorMessage ?? "Failed to add customer");
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

  /// Validates email format using regex
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
          "Add Customer",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        leading: BackButton(color: isDark ? Colors.white : Colors.black),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: SmartForm(
        formKey: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SmartTextFormField(
              label: "Customer Name",
              controller: nameController,
              hintText: "Enter full name",
              prefixIcon: const Icon(Icons.person),
              validator: (v) => v?.trim().isEmpty == true ? "Required" : null,
            ),
            const SizedBox(height: 20),
            SmartTextFormField(
              label: "Phone Number",
              controller: phoneController,
              hintText: "Enter phone number",
              prefixIcon: const Icon(Icons.phone),
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v != null && v.isNotEmpty && v.length < 10) {
                  return 'Phone number must be at least 10 digits';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            SmartTextFormField(
              label: "Email (Optional)",
              controller: emailController,
              hintText: "Enter email address",
              prefixIcon: const Icon(Icons.email),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v != null && v.isNotEmpty && !_isValidEmail(v)) {
                  return 'Invalid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            SmartTextFormField(
              label: "Address (Optional)",
              controller: addressController,
              hintText: "Enter customer address",
              prefixIcon: const Icon(Icons.location_on),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            SmartTextFormField(
              label: "GSTIN (Optional)",
              controller: gstinController,
              hintText: "Enter GST number",
              prefixIcon: const Icon(Icons.receipt),
            ),
            const SizedBox(height: 40),
            EnterpriseButton(
              onPressed: _addCustomer,
              label: "Create Customer",
              isLoading: _isSaving,
              width: double.infinity,
            ),
          ],
        ),
      ),
      ),
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
