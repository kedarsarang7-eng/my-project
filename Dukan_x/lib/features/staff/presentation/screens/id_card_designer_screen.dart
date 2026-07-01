// ============================================================================
// ID CARD DESIGNER SCREEN - Staff ID Card Creator
// ============================================================================
// Purpose: Owner designs and prints ID cards for staff members
// Features:
//   - Live preview of ID card with staff photo and details
//   - Multiple ID card templates (Standard, Premium, Compact)
//   - QR code generation for staff ID
//   - Barcode (Code128) option
//   - Photo upload/capture
//   - Print to PDF or direct printer
//   - Batch print for multiple staff
// ============================================================================

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/staff_profile_model.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/logger_service.dart';
import '../bloc/id_card_designer_bloc.dart';
import '../bloc/id_card_designer_event.dart';
import '../bloc/id_card_designer_state.dart';
import '../bloc/id_card_models.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// ID Card Designer Screen
/// 
/// Allows petrol pump owners to design, preview, and print
/// professional ID cards for their staff members.
class IDCardDesignerScreen extends StatelessWidget {
  final String staffId;

  const IDCardDesignerScreen({super.key, required this.staffId});

  @override
  Widget build(BuildContext context) {
    // Defensive check: Validate service locator has required dependencies
    if (!sl.isRegistered<IDCardDesignerBloc>()) {
      return _buildErrorScreen(
        context,
        'IDCardDesignerBloc not registered',
        'Please ensure the app is properly initialized.',
      );
    }

    try {
      return BlocProvider(
        create: (context) => sl<IDCardDesignerBloc>()
          ..add(LoadStaffForIDCard(staffId: staffId)),
        child: const _IDCardDesignerView(),
      );
    } catch (e, stackTrace) {
      // Log error for debugging
      LoggerService.d('IDCard', 'ERROR: Failed to create IDCardDesignerBloc: $e');
      LoggerService.d('IDCard', 'Stack trace: $stackTrace');

      return _buildErrorScreen(
        context,
        'Failed to initialize ID card designer',
        'Error: $e',
      );
    }
  }

  /// Builds an error screen when BLoC creation fails
  Widget _buildErrorScreen(BuildContext context, String title, String message) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
        backgroundColor: Colors.red,
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // Retry navigation - this will rebuild the widget
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _IDCardDesignerView extends StatelessWidget {
  const _IDCardDesignerView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('ID Card Designer'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Template selector
          _TemplateSelector(),
          const SizedBox(width: 16),
          // Print button
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print ID Card',
            onPressed: () => _showPrintOptions(context),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: BlocConsumer<IDCardDesignerBloc, IDCardDesignerState>(
        listener: (context, state) {
          if (state is IDCardExported) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('ID Card saved: ${state.filePath}'),
                backgroundColor: Colors.green,
              ),
            );
          }
          if (state is IDCardError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is IDCardDesignerLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is IDCardDesignerLoaded) {
            return Row(
              children: [
                // Left panel - Settings
                Expanded(
                  flex: 2,
                  child: _SettingsPanel(
                    staff: state.staff,
                    settings: state.settings,
                  ),
                ),
                
                // Center - Preview
                Expanded(
                  flex: 3,
                  child: _IDCardPreview(
                    staff: state.staff,
                    settings: state.settings,
                  ),
                ),
                
                // Right panel - Actions
                Expanded(
                  flex: 2,
                  child: _ActionsPanel(
                    staff: state.staff,
                    settings: state.settings,
                  ),
                ),
              ],
            );
          }

          return const Center(child: Text('Failed to load staff data'));
        },
      ),
    );
  }

  void _showPrintOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Print Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.print, color: Colors.blue),
              title: const Text('Print to Printer'),
              subtitle: const Text('Direct print to connected printer'),
              onTap: () {
                Navigator.pop(context);
                context.read<IDCardDesignerBloc>().add(
                  const PrintIDCard(),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Export as PDF'),
              subtitle: const Text('Save as PDF file for later printing'),
              onTap: () {
                Navigator.pop(context);
                _exportAsPDF(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.green),
              title: const Text('Export as Image'),
              subtitle: const Text('Save as PNG image'),
              onTap: () {
                Navigator.pop(context);
                context.read<IDCardDesignerBloc>().add(
                  const ExportIDCard(format: 'PNG'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAsPDF(BuildContext context) async {
    final result = await FilePicker.saveFile(
      dialogTitle: 'Save ID Card as PDF',
      fileName: 'staff_id_card.pdf',
      allowedExtensions: ['pdf'],
      bytes: Uint8List(0),
    );

    if (result != null) {
      context.read<IDCardDesignerBloc>().add(
        ExportIDCard(format: 'PDF', filePath: result),
      );
    }
  }
}

// ============================================================================
// SETTINGS PANEL
// ============================================================================

class _SettingsPanel extends StatelessWidget {
  final StaffProfileModel staff;
  final IDCardSettings settings;

  const _SettingsPanel({required this.staff, required this.settings});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Card Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Template Selection
            _buildSectionTitle('Template'),
            const SizedBox(height: 12),
            _TemplateSelectorDropdown(
              selectedTemplate: settings.template,
              onChanged: (template) {
                context.read<IDCardDesignerBloc>().add(
                  UpdateSettings(settings.copyWith(template: template)),
                );
              },
            ),
            const SizedBox(height: 24),
            
            // Photo Settings
            _buildSectionTitle('Photo'),
            const SizedBox(height: 12),
            _PhotoSettings(
              staff: staff,
              photoMode: settings.photoMode,
              onPhotoModeChanged: (mode) {
                context.read<IDCardDesignerBloc>().add(
                  UpdateSettings(settings.copyWith(photoMode: mode)),
                );
              },
              onPhotoUploaded: (path) {
                context.read<IDCardDesignerBloc>().add(
                  UpdatePhoto(photoPath: path),
                );
              },
            ),
            const SizedBox(height: 24),
            
            // ID Code Settings
            _buildSectionTitle('ID Code'),
            const SizedBox(height: 12),
            _IDCodeSettings(
              codeType: settings.codeType,
              onCodeTypeChanged: (type) {
                context.read<IDCardDesignerBloc>().add(
                  UpdateSettings(settings.copyWith(codeType: type)),
                );
              },
            ),
            const SizedBox(height: 24),
            
            // Color Theme
            _buildSectionTitle('Theme Color'),
            const SizedBox(height: 12),
            _ColorPicker(
              selectedColor: settings.primaryColor,
              onColorSelected: (color) {
                context.read<IDCardDesignerBloc>().add(
                  UpdateSettings(settings.copyWith(primaryColor: color)),
                );
              },
            ),
            const SizedBox(height: 24),
            
            // Card Size
            _buildSectionTitle('Card Size'),
            const SizedBox(height: 12),
            _CardSizeSelector(
              selectedSize: settings.cardSize,
              onSizeChanged: (size) {
                context.read<IDCardDesignerBloc>().add(
                  UpdateSettings(settings.copyWith(cardSize: size)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _TemplateSelectorDropdown extends StatelessWidget {
  final IDCardTemplate selectedTemplate;
  final ValueChanged<IDCardTemplate> onChanged;

  const _TemplateSelectorDropdown({
    required this.selectedTemplate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<IDCardTemplate>(
      value: selectedTemplate,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: IDCardTemplate.values.map((template) {
        return DropdownMenuItem(
          value: template,
          child: Row(
            children: [
              Icon(_getTemplateIcon(template), size: 20),
              const SizedBox(width: 8),
              Text(_getTemplateName(template)),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  IconData _getTemplateIcon(IDCardTemplate template) {
    switch (template) {
      case IDCardTemplate.standard:
        return Icons.badge;
      case IDCardTemplate.modern:
        return Icons.style;
      case IDCardTemplate.compact:
        return Icons.credit_card;
      case IDCardTemplate.premium:
        return Icons.stars;
    }
  }

  String _getTemplateName(IDCardTemplate template) {
    switch (template) {
      case IDCardTemplate.standard:
        return 'Standard';
      case IDCardTemplate.modern:
        return 'Modern';
      case IDCardTemplate.compact:
        return 'Compact';
      case IDCardTemplate.premium:
        return 'Premium';
    }
  }
}

class _PhotoSettings extends StatelessWidget {
  final StaffProfileModel staff;
  final PhotoMode photoMode;
  final ValueChanged<PhotoMode> onPhotoModeChanged;
  final ValueChanged<String> onPhotoUploaded;

  const _PhotoSettings({
    required this.staff,
    required this.photoMode,
    required this.onPhotoModeChanged,
    required this.onPhotoUploaded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SegmentedButton<PhotoMode>(
          segments: const [
            ButtonSegment(
              value: PhotoMode.existing,
              label: Text('Existing'),
              icon: Icon(Icons.person),
            ),
            ButtonSegment(
              value: PhotoMode.upload,
              label: Text('Upload'),
              icon: Icon(Icons.upload),
            ),
            ButtonSegment(
              value: PhotoMode.camera,
              label: Text('Camera'),
              icon: Icon(Icons.camera_alt),
            ),
          ],
          selected: {photoMode},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) {
              onPhotoModeChanged(selection.first);
            }
          },
        ),
        const SizedBox(height: 12),
        if (photoMode == PhotoMode.upload)
          ElevatedButton.icon(
            onPressed: () => _pickImage(context),
            icon: const Icon(Icons.upload_file),
            label: const Text('Select Photo'),
          ),
        if (photoMode == PhotoMode.camera)
          ElevatedButton.icon(
            onPressed: () => _captureImage(context),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Capture Photo'),
          ),
      ],
    );
  }

  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 90,
    );
    if (image != null) {
      onPhotoUploaded(image.path);
    }
  }

  Future<void> _captureImage(BuildContext context) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 90,
    );
    if (image != null) {
      onPhotoUploaded(image.path);
    }
  }
}

class _IDCodeSettings extends StatelessWidget {
  final IDCodeType codeType;
  final ValueChanged<IDCodeType> onCodeTypeChanged;

  const _IDCodeSettings({
    required this.codeType,
    required this.onCodeTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text('Show QR Code'),
          subtitle: const Text('Scannable QR with Staff ID'),
          value: codeType == IDCodeType.qr || codeType == IDCodeType.both,
          onChanged: (value) {
            if (value == true) {
              onCodeTypeChanged(
                codeType == IDCodeType.barcode ? IDCodeType.both : IDCodeType.qr,
              );
            } else {
              onCodeTypeChanged(
                codeType == IDCodeType.both ? IDCodeType.barcode : IDCodeType.none,
              );
            }
          },
        ),
        CheckboxListTile(
          title: const Text('Show Barcode'),
          subtitle: const Text('Code128 barcode'),
          value: codeType == IDCodeType.barcode || codeType == IDCodeType.both,
          onChanged: (value) {
            if (value == true) {
              onCodeTypeChanged(
                codeType == IDCodeType.qr ? IDCodeType.both : IDCodeType.barcode,
              );
            } else {
              onCodeTypeChanged(
                codeType == IDCodeType.both ? IDCodeType.qr : IDCodeType.none,
              );
            }
          },
        ),
      ],
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  const _ColorPicker({
    required this.selectedColor,
    required this.onColorSelected,
  });

  final List<Color> _colors = const [
    Color(0xFF1E3A5F), // Navy Blue
    Color(0xFF2E7D32), // Green
    Color(0xFFC62828), // Red
    Color(0xFF1565C0), // Blue
    Color(0xFF6A1B9A), // Purple
    Color(0xFF00695C), // Teal
    Color(0xFFEF6C00), // Orange
    Color(0xFF37474F), // Dark Grey
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _colors.map((color) {
        final isSelected = color.value == selectedColor.value;
        return InkWell(
          onTap: () => onColorSelected(color),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: isSelected
                  ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _CardSizeSelector extends StatelessWidget {
  final CardSize selectedSize;
  final ValueChanged<CardSize> onSizeChanged;

  const _CardSizeSelector({
    required this.selectedSize,
    required this.onSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<CardSize>(
      segments: const [
        ButtonSegment(
          value: CardSize.standard,
          label: Text('Standard'),
        ),
        ButtonSegment(
          value: CardSize.compact,
          label: Text('Compact'),
        ),
        ButtonSegment(
          value: CardSize.lanyard,
          label: Text('Lanyard'),
        ),
      ],
      selected: {selectedSize},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) {
          onSizeChanged(selection.first);
        }
      },
    );
  }
}

// ============================================================================
// ID CARD PREVIEW
// ============================================================================

class _IDCardPreview extends StatelessWidget {
  final StaffProfileModel staff;
  final IDCardSettings settings;

  const _IDCardPreview({required this.staff, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        child: _buildCardPreview(),
      ),
    );
  }

  Widget _buildCardPreview() {
    switch (settings.template) {
      case IDCardTemplate.standard:
        return _StandardIDCard(staff: staff, settings: settings);
      case IDCardTemplate.modern:
        return _ModernIDCard(staff: staff, settings: settings);
      case IDCardTemplate.compact:
        return _CompactIDCard(staff: staff, settings: settings);
      case IDCardTemplate.premium:
        return _PremiumIDCard(staff: staff, settings: settings);
    }
  }
}

// ============================================================================
// ID CARD TEMPLATES
// ============================================================================

class _StandardIDCard extends StatelessWidget {
  final StaffProfileModel staff;
  final IDCardSettings settings;

  const _StandardIDCard({required this.staff, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 540,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: settings.primaryColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'PETROL PUMP STAFF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Authorized Personnel',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Photo
          Container(
            margin: const EdgeInsets.only(top: 20),
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: settings.primaryColor, width: 4),
              image: _getPhotoDecoration(),
            ),
            child: staff.profilePhotoUrl == null && settings.photoPath == null
                ? Center(
                    child: Text(
                      staff.fullName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                        color: settings.primaryColor,
                      ),
                    ),
                  )
                : null,
          ),
          
          const SizedBox(height: 20),
          
          // Name
          Text(
            staff.fullName,
            style: TextStyle(
              fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Role
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: settings.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              staff.role.jsonValue.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: settings.primaryColor,
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Staff ID
          Text(
            'ID: ${staff.staffId}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontFamily: 'monospace',
            ),
          ),
          
          const Spacer(),
          
          // QR Code or Barcode
          if (settings.codeType != IDCodeType.none)
            _buildCode(),
          
          const SizedBox(height: 20),
          
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Center(
              child: Text(
                'If found, please return to nearest station',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DecorationImage? _getPhotoDecoration() {
    final photoUrl = settings.photoPath ?? staff.profilePhotoUrl;
    if (photoUrl == null) return null;
    
    if (photoUrl.startsWith('http')) {
      return DecorationImage(
        image: NetworkImage(photoUrl),
        fit: BoxFit.cover,
      );
    } else {
      return DecorationImage(
        image: FileImage(File(photoUrl)),
        fit: BoxFit.cover,
      );
    }
  }

  Widget _buildCode() {
    if (settings.codeType == IDCodeType.qr || settings.codeType == IDCodeType.both) {
      return QrImageView(
        data: staff.staffId,
        version: QrVersions.auto,
        size: 100,
        backgroundColor: Colors.white,
      );
    }
    
    if (settings.codeType == IDCodeType.barcode || settings.codeType == IDCodeType.both) {
      return BarcodeWidget(
        barcode: Barcode.code128(),
        data: staff.staffId,
        width: 200,
        height: 60,
        drawText: true,
      );
    }
    
    return const SizedBox.shrink();
  }
}

// Other templates would be similar with different layouts
class _ModernIDCard extends StatelessWidget {
  final StaffProfileModel staff;
  final IDCardSettings settings;

  const _ModernIDCard({required this.staff, required this.settings});

  @override
  Widget build(BuildContext context) {
    return _StandardIDCard(staff: staff, settings: settings);
  }
}

class _CompactIDCard extends StatelessWidget {
  final StaffProfileModel staff;
  final IDCardSettings settings;

  const _CompactIDCard({required this.staff, required this.settings});

  @override
  Widget build(BuildContext context) {
    return _StandardIDCard(staff: staff, settings: settings);
  }
}

class _PremiumIDCard extends StatelessWidget {
  final StaffProfileModel staff;
  final IDCardSettings settings;

  const _PremiumIDCard({required this.staff, required this.settings});

  @override
  Widget build(BuildContext context) {
    return _StandardIDCard(staff: staff, settings: settings);
  }
}

// ============================================================================
// ACTIONS PANEL
// ============================================================================

class _ActionsPanel extends StatelessWidget {
  final StaffProfileModel staff;
  final IDCardSettings settings;

  const _ActionsPanel({required this.staff, required this.settings});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          _ActionButton(
            icon: Icons.print,
            label: 'Print ID Card',
            color: Colors.blue,
            onTap: () => context.read<IDCardDesignerBloc>().add(
              const PrintIDCard(),
            ),
          ),
          const SizedBox(height: 12),
          
          _ActionButton(
            icon: Icons.picture_as_pdf,
            label: 'Export as PDF',
            color: Colors.red,
            onTap: () => context.read<IDCardDesignerBloc>().add(
              const ExportIDCard(format: 'PDF'),
            ),
          ),
          const SizedBox(height: 12),
          
          _ActionButton(
            icon: Icons.image,
            label: 'Export as Image',
            color: Colors.green,
            onTap: () => context.read<IDCardDesignerBloc>().add(
              const ExportIDCard(format: 'PNG'),
            ),
          ),
          const SizedBox(height: 12),
          
          _ActionButton(
            icon: Icons.email,
            label: 'Email to Staff',
            color: Colors.orange,
            onTap: () => context.read<IDCardDesignerBloc>().add(
              const EmailIDCard(),
            ),
          ),
          const SizedBox(height: 24),
          
          const Divider(),
          const SizedBox(height: 24),
          
          Text(
            'Batch Actions',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          
          _ActionButton(
            icon: Icons.people,
            label: 'Print All Staff Cards',
            color: Colors.purple,
            onTap: () => context.read<IDCardDesignerBloc>().add(
              const PrintAllCards(),
            ),
          ),
          const SizedBox(height: 12),
          
          _ActionButton(
            icon: Icons.download,
            label: 'Download Template',
            color: Colors.teal,
            onTap: () => context.read<IDCardDesignerBloc>().add(
              const DownloadTemplate(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // Implemented in _SettingsPanel
  }
}

// IDCardSettings, PhotoMode, IDCardTemplate, IDCodeType, CardSize
// are defined in ../bloc/id_card_models.dart
