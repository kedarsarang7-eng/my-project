// ============================================================================
// Computer Shop — Create Job Card Screen
// ============================================================================
// Form to create new service job cards with:
// - Device info (brand, model, serial)
// - Customer info
// - Problem description
// - Photo uploads
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/computer_job_providers.dart';

class CreateJobCardScreen extends ConsumerStatefulWidget {
  final String? serialNumber;

  const CreateJobCardScreen({super.key, this.serialNumber});

  @override
  ConsumerState<CreateJobCardScreen> createState() =>
      _CreateJobCardScreenState();
}

class _CreateJobCardScreenState extends ConsumerState<CreateJobCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  late final TextEditingController _serialController;
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _problemController = TextEditingController();
  final List<String> _photoUrls = [];

  @override
  void initState() {
    super.initState();
    _serialController = TextEditingController(text: widget.serialNumber ?? '');
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _problemController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'deviceBrand': _brandController.text.trim(),
      'deviceModel': _modelController.text.trim(),
      if (_serialController.text.isNotEmpty)
        'serialNumber': _serialController.text.trim(),
      if (_customerNameController.text.isNotEmpty)
        'customerName': _customerNameController.text.trim(),
      if (_customerPhoneController.text.isNotEmpty)
        'customerPhone': _customerPhoneController.text.trim(),
      if (_customerEmailController.text.isNotEmpty)
        'customerEmail': _customerEmailController.text.trim(),
      'reportedIssue': _problemController.text.trim(),
      'photoUrls': _photoUrls,
    };

    try {
      await ref.read(createJobCardFormProvider.notifier).createJobCard(data);

      final state = ref.read(createJobCardFormProvider);
      if (state.isSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Job card created successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, state.createdJobId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(createJobCardFormProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Create Job Card',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section: Device Information
              _SectionHeader(
                icon: Icons.computer,
                title: 'Device Information',
                color: const Color(0xFF3B82F6),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _brandController,
                decoration: InputDecoration(
                  labelText: 'Brand *',
                  hintText: 'e.g., Dell, HP, Apple',
                  prefixIcon: const Icon(Icons.business),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Brand is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                decoration: InputDecoration(
                  labelText: 'Model *',
                  hintText: 'e.g., Latitude 5520, MacBook Pro',
                  prefixIcon: const Icon(Icons.devices),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Model is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _serialController,
                decoration: InputDecoration(
                  labelText: 'Serial Number',
                  hintText: 'Device serial number (optional)',
                  prefixIcon: const Icon(Icons.confirmation_number),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Section: Customer Information
              _SectionHeader(
                icon: Icons.person,
                title: 'Customer Information',
                color: const Color(0xFF10B981),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _customerNameController,
                decoration: InputDecoration(
                  labelText: 'Customer Name',
                  hintText: 'Full name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _customerPhoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '10-digit mobile number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _customerEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'customer@example.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Section: Problem Description
              _SectionHeader(
                icon: Icons.report_problem,
                title: 'Problem Description',
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _problemController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Issue Description *',
                  hintText: 'Describe the problem in detail...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please describe the problem';
                  }
                  if (value.length < 10) {
                    return 'Description is too short (min 10 chars)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Section: Photos
              _SectionHeader(
                icon: Icons.camera_alt,
                title: 'Photos',
                color: const Color(0xFF8B5CF6),
              ),
              const SizedBox(height: 16),
              _PhotoUploadSection(
                photoUrls: _photoUrls,
                onAddPhoto: (url) => setState(() => _photoUrls.add(url)),
                onRemovePhoto: (url) => setState(() => _photoUrls.remove(url)),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: formState.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: formState.isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Creating...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save),
                            SizedBox(width: 8),
                            Text(
                              'Create Job Card',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Section Header Widget
// ============================================================================

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Photo Upload Section
// ============================================================================

class _PhotoUploadSection extends StatelessWidget {
  final List<String> photoUrls;
  final Function(String) onAddPhoto;
  final Function(String) onRemovePhoto;

  const _PhotoUploadSection({
    required this.photoUrls,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photo Grid
        if (photoUrls.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: photoUrls.length,
              itemBuilder: (context, index) {
                final url = photoUrls[index];
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(url),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => onRemovePhoto(url),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        if (photoUrls.isNotEmpty) const SizedBox(height: 12),
        // Add Photo Button
        OutlinedButton.icon(
          onPressed: () {
            // Show dialog to enter photo URL (in production, integrate with camera/gallery)
            _showAddPhotoDialog(context);
          },
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('Add Photo'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddPhotoDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Photo URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://example.com/photo.jpg',
            labelText: 'Photo URL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                onAddPhoto(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
