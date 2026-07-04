// ============================================================================
// Computer Shop — Create Job Card Screen
// ============================================================================
// Form to create new service job cards with:
// - Device info (brand, model, serial)
// - Customer info
// - Problem description
// - Photo uploads
// ============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import '../../providers/computer_job_providers.dart';
import '../../utils/computer_shop_validators.dart';

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

  /// Maximum allowed photo file size: 10 MB.
  static const int _maxPhotoSizeBytes = 10 * 1024 * 1024;

  final ImagePicker _imagePicker = ImagePicker();

  /// Shows a bottom sheet with Camera and Gallery options then processes the
  /// picked image (validates size ≤ 10MB, handles errors).
  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Add Photo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF3B82F6)),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Color(0xFF8B5CF6),
                ),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile == null || !mounted) return;

      // Validate file size ≤ 10 MB.
      final int fileSize = await File(pickedFile.path).length();
      if (fileSize > _maxPhotoSizeBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'File size exceeds 10 MB limit. Please select a smaller image.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Attach the file using a file:// URI.
      final String fileUri = 'file://${pickedFile.path}';
      setState(() => _photoUrls.add(fileUri));
    } catch (e) {
      if (!mounted) return;
      // Distinguish camera permission denied from general failures.
      final String message =
          e.toString().toLowerCase().contains('permission') ||
              e.toString().toLowerCase().contains('denied') ||
              e.toString().toLowerCase().contains('camera_access_denied')
          ? 'Camera permission denied'
          : 'Failed to attach photo';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        title: Text(
          'Create Job Card',
          style: TextStyle(
            fontSize: responsiveValue<double>(
              context,
              mobile: 16,
              tablet: 18,
              desktop: 20,
            ),
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: BoundedBox(
          maxWidth: 800,
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
                  validator: (value) {
                    // Serial is optional; validate format only when provided.
                    if (value == null || value.trim().isEmpty) return null;
                    return ComputerShopValidators.validateSerial(value);
                  },
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
                  validator: (value) {
                    // Phone is optional; validate format only when provided.
                    if (value == null || value.isEmpty) return null;
                    return ComputerShopValidators.validatePhone(value);
                  },
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
                  validator: (value) {
                    // Email is optional; validate format only when provided.
                    if (value == null || value.isEmpty) return null;
                    return ComputerShopValidators.validateEmail(value);
                  },
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
                  onAddPhoto: () => _pickPhoto(),
                  onRemovePhoto: (url) =>
                      setState(() => _photoUrls.remove(url)),
                ),
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: formState.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
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

/// Validates whether [source] is a supported image URL.
///
/// Returns `true` if, after trimming, the string is non-empty and begins with
/// one of the supported schemes (`http://`, `https://`, or `file://`).
bool _isValidImageSource(String? source) {
  if (source == null) return false;
  final trimmed = source.trim();
  if (trimmed.isEmpty) return false;
  final lower = trimmed.toLowerCase();
  return lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('file://');
}

class _PhotoUploadSection extends StatelessWidget {
  final List<String> photoUrls;
  final VoidCallback onAddPhoto;
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
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _buildImageWidget(url),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: Semantics(
                        label: 'Remove photo',
                        button: true,
                        child: Tooltip(
                          message: 'Remove photo',
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
          onPressed: onAddPhoto,
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

  /// Builds the image widget for a given [url].
  ///
  /// - If the URL is invalid (empty, whitespace-only, or unsupported scheme),
  ///   renders a placeholder icon — no `NetworkImage` is constructed.
  /// - For file:// URIs, uses `Image.file` to display the local image.
  /// - For http/https, uses `Image.network` with `loadingBuilder` and `errorBuilder`
  ///   to gracefully handle loading states and runtime failures.
  Widget _buildImageWidget(String url) {
    if (!_isValidImageSource(url)) {
      return _buildInvalidPlaceholder();
    }

    final trimmed = url.trim();

    // Handle local file:// URIs
    if (trimmed.toLowerCase().startsWith('file://')) {
      final filePath = trimmed.substring(7); // Remove 'file://' prefix
      return Image.file(
        File(filePath),
        fit: BoxFit.cover,
        width: 100,
        height: 100,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorPlaceholder();
        },
      );
    }

    return Image.network(
      trimmed,
      fit: BoxFit.cover,
      width: 100,
      height: 100,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildErrorPlaceholder();
      },
    );
  }

  /// Placeholder shown when the image source string is invalid.
  Widget _buildInvalidPlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, color: Colors.grey, size: 28),
          SizedBox(height: 4),
          Text('Invalid', style: TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  /// Placeholder shown when a valid image source fails to load at runtime.
  Widget _buildErrorPlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, color: Colors.grey, size: 28),
          SizedBox(height: 4),
          Text('Error', style: TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}
