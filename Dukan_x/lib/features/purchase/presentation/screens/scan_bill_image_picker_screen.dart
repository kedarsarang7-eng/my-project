// ============================================================================
// Scan Bill Image Picker Screen
// ============================================================================
// First screen in the scan bill flow:
// - Option to take photo or choose from gallery
// - Image preview with retake option
// - Crop/rotate functionality
// - Proceed to processing
// ============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/di/service_locator.dart';
import '../../providers/scan_bill_session_provider.dart';
import 'scan_bill_processing_screen.dart';

class ScanBillImagePickerScreen extends ConsumerStatefulWidget {
  final String verticalType;

  const ScanBillImagePickerScreen({super.key, required this.verticalType});

  @override
  ConsumerState<ScanBillImagePickerScreen> createState() =>
      _ScanBillImagePickerScreenState();
}

class _ScanBillImagePickerScreenState
    extends ConsumerState<ScanBillImagePickerScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final LoggerService _logger = sl<LoggerService>();

  bool _isProcessing = false;
  List<File> _previewImages = [];
  int _selectedImageIndex = 0;

  @override
  void initState() {
    super.initState();
    // Check for any existing session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingSession();
    });
  }

  void _checkExistingSession() {
    final sessionState = ref.read(scanBillSessionProvider(widget.verticalType));
    if (sessionState.extractionResult != null) {
      // There's an existing session - ask user
      _showResumeDialog();
    }
  }

  void _showResumeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Resume Previous Session?'),
        content: const Text(
          'You have an incomplete scan bill session. Would you like to resume where you left off?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetSession();
            },
            child: const Text('Start New'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resumeSession();
            },
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetSession() async {
    await ref
        .read(scanBillSessionProvider(widget.verticalType).notifier)
        .reset();
  }

  void _resumeSession() {
    final sessionState = ref.read(scanBillSessionProvider(widget.verticalType));

    if (sessionState.reviewLineItems != null) {
      // Navigate to review screen
      context.push('/purchase/scan-bill/review');
    } else if (sessionState.extractionResult != null) {
      // Navigate to processing/matching screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScanBillProcessingScreen(
            verticalType: widget.verticalType,
            skipToMatching: true,
          ),
        ),
      );
    }
  }

  Future<void> _captureImage(ImageSource source, {bool addPage = false}) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1600,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (pickedFile == null) return;

      _logger.info('Image picked', {
        'path': pickedFile.path,
        'source': source.name,
        'addPage': addPage,
      });

      setState(() {
        if (addPage) {
          _previewImages.add(File(pickedFile.path));
          _selectedImageIndex = _previewImages.length - 1;
        } else {
          _previewImages = [File(pickedFile.path)];
          _selectedImageIndex = 0;
        }
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to capture image', {
        'error': e.toString(),
      }, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to capture image: $e')));
      }
    }
  }

  Future<void> _cropImage() async {
    if (_previewImages.isEmpty ||
        _selectedImageIndex >= _previewImages.length) {
      return;
    }

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: _previewImages[_selectedImageIndex].path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Bill',
            toolbarColor: Theme.of(context).primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio5x4,
            ],
          ),
          IOSUiSettings(title: 'Crop Bill'),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _previewImages[_selectedImageIndex] = File(croppedFile.path);
        });
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to crop image', {
        'error': e.toString(),
      }, stackTrace);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _previewImages.removeAt(index);
      if (_selectedImageIndex >= _previewImages.length) {
        _selectedImageIndex = _previewImages.length - 1;
      }
    });
  }

  void _selectImage(int index) {
    setState(() {
      _selectedImageIndex = index;
    });
  }

  void _retakeImage() {
    if (_previewImages.isEmpty) return;

    setState(() {
      _previewImages.removeAt(_selectedImageIndex);
      if (_previewImages.isEmpty) {
        _selectedImageIndex = 0;
      } else if (_selectedImageIndex >= _previewImages.length) {
        _selectedImageIndex = _previewImages.length - 1;
      }
    });
    _logger.info('Image removed - showing capture options if empty');
  }

  void _clearAllImages() {
    setState(() {
      _previewImages = [];
      _selectedImageIndex = 0;
    });
  }

  Future<void> _proceedToProcessing() async {
    if (_previewImages.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      // Process all images
      final tempDir = await getTemporaryDirectory();
      final compressedFiles = <File>[];

      for (int i = 0; i < _previewImages.length; i++) {
        final fileName =
            'scan_bill_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final compressedPath = path.join(tempDir.path, fileName);

        await _previewImages[i].copy(compressedPath);
        compressedFiles.add(File(compressedPath));
      }

      _logger.info('Images ready for processing', {
        'count': compressedFiles.length,
      });

      // Update session with images
      ref
          .read(scanBillSessionProvider(widget.verticalType).notifier)
          .setImages(compressedFiles);

      // Navigate to processing screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScanBillProcessingScreen(
              verticalType: widget.verticalType,
              isMultiPage: _previewImages.length > 1,
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to prepare images', {
        'error': e.toString(),
      }, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to prepare images: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Purchase Bill'),
        actions: [
          if (_previewImages.isNotEmpty) ...[
            // Add Page button (when in multi-page mode)
            IconButton(
              icon: const Icon(Icons.add_photo_alternate),
              onPressed: () => _captureImage(ImageSource.camera, addPage: true),
              tooltip: 'Add Another Page',
            ),
            // Clear all button
            TextButton(
              onPressed: _clearAllImages,
              child: const Text('Clear All'),
            ),
          ],
        ],
      ),
      body: _previewImages.isNotEmpty
          ? _buildPreviewView()
          : _buildCaptureView(colorScheme),
      bottomNavigationBar: _previewImages.isNotEmpty
          ? _buildProceedButton(colorScheme)
          : null,
    );
  }

  Widget _buildCaptureView(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            'Capture Supplier Bill',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Photograph or upload the supplier\'s purchase bill/invoice for automatic product extraction.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Camera option
          _buildCaptureOption(
            icon: Icons.camera_alt_outlined,
            title: 'Take Photo',
            subtitle: 'Use camera to capture bill',
            color: colorScheme.primary,
            onTap: () => _captureImage(ImageSource.camera),
          ),
          const SizedBox(height: 16),

          // Gallery option
          _buildCaptureOption(
            icon: Icons.photo_library_outlined,
            title: 'Choose from Gallery',
            subtitle: 'Select existing image',
            color: colorScheme.secondary,
            onTap: () => _captureImage(ImageSource.gallery),
          ),
          const SizedBox(height: 32),

          // Tips
          _buildTipsCard(),
        ],
      ),
    );
  }

  Widget _buildCaptureOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.amber[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Tips for best results',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTipItem('Ensure good lighting and avoid shadows'),
          _buildTipItem('Keep the bill flat and in focus'),
          _buildTipItem('Capture all line items and totals'),
          _buildTipItem('Avoid blurry or dark images'),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 4),
      child: Text(
        '• $text',
        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
      ),
    );
  }

  Widget _buildPreviewView() {
    return Column(
      children: [
        // Image preview
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                _previewImages[_selectedImageIndex],
                fit: BoxFit.contain,
              ),
              // Page indicator (top center)
              if (_previewImages.length > 1)
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Page ${_selectedImageIndex + 1} of ${_previewImages.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              // Remove button (top-left)
              Positioned(
                top: 16,
                left: 16,
                child: FloatingActionButton.small(
                  heroTag: 'retake',
                  onPressed: _retakeImage,
                  backgroundColor: Colors.red.withOpacity(0.8),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
              ),
              // Crop button (top-right)
              Positioned(
                top: 16,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'crop',
                  onPressed: _cropImage,
                  backgroundColor: Colors.black54,
                  child: const Icon(Icons.crop, color: Colors.white),
                ),
              ),
            ],
          ),
        ),

        // Thumbnail strip
        if (_previewImages.length > 1)
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _previewImages.length + 1, // +1 for "Add Page"
              itemBuilder: (context, index) {
                if (index == _previewImages.length) {
                  // Add Page button
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: InkWell(
                      onTap: () =>
                          _captureImage(ImageSource.camera, addPage: true),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey[400]!,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              color: Colors.grey[600],
                            ),
                            Text(
                              'Add Page',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Thumbnail
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _selectImage(index),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: index == _selectedImageIndex
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(_previewImages[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: index == _selectedImageIndex
                          ? const Align(
                              alignment: Alignment.topRight,
                              child: Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),

        // Image info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _previewImages.length == 1
                          ? '1 Image Ready'
                          : '${_previewImages.length} Images Ready',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      _previewImages.length == 1
                          ? 'Tap "Process Bill" to extract products'
                          : 'Tap "Process Bill" to extract from all pages',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProceedButton(ColorScheme colorScheme) {
    final buttonText = _isProcessing
        ? 'Preparing ${_previewImages.length} Image${_previewImages.length > 1 ? 's' : ''}...'
        : _previewImages.length > 1
        ? 'Process ${_previewImages.length} Pages'
        : 'Process Bill';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _isProcessing ? null : _proceedToProcessing,
          icon: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  _previewImages.length > 1
                      ? Icons.auto_stories
                      : Icons.document_scanner_outlined,
                ),
          label: Text(buttonText),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
