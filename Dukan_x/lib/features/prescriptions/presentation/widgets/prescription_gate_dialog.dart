import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../inventory/services/drug_schedule_service.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';

/// Result returned by [PrescriptionGateDialog].
///
/// Carries the schedule-aware contract that downstream invoice metadata
/// MUST honour. The fields populated depend on [schedule]:
///
/// - Schedule H : `prescriptionId` (rx text or image hash) only.
/// - Schedule H1: `prescriptionId` + `doctorName` + `doctorRegNo`
///                + `patientName` (CDSCO H1 Register).
/// - Schedule X : H1 fields + `patientAddress` (NDPS Act).
class PrescriptionGateResult {
  final String prescriptionId;
  final DrugSchedule schedule;
  final String? doctorName;
  final String? doctorRegNo;
  final String? patientName;
  final String? patientAddress;

  const PrescriptionGateResult({
    required this.prescriptionId,
    required this.schedule,
    this.doctorName,
    this.doctorRegNo,
    this.patientName,
    this.patientAddress,
  });

  Map<String, dynamic> toMetadata() => {
        'prescriptionId': prescriptionId,
        'drugSchedule': schedule.label,
        if (doctorName != null && doctorName!.trim().isNotEmpty)
          'doctorName': doctorName!.trim(),
        if (doctorRegNo != null && doctorRegNo!.trim().isNotEmpty)
          'doctorRegNo': doctorRegNo!.trim(),
        if (patientName != null && patientName!.trim().isNotEmpty)
          'patientName': patientName!.trim(),
        if (patientAddress != null && patientAddress!.trim().isNotEmpty)
          'patientAddress': patientAddress!.trim(),
      };
}

/// Modal dialog that blocks billing of Schedule H/H1/X drugs until a
/// prescription is scanned/uploaded or Rx ID entered, plus any extra
/// statutory fields required by the drug's schedule class.
class PrescriptionGateDialog extends StatefulWidget {
  final String productName;
  final DrugSchedule schedule;

  const PrescriptionGateDialog({
    super.key,
    required this.productName,
    required this.schedule,
  });

  /// Show dialog and return the rich [PrescriptionGateResult] (or null on
  /// cancel). Use this for invoice metadata wiring.
  static Future<PrescriptionGateResult?> showRich(
    BuildContext context, {
    required String productName,
    required DrugSchedule schedule,
  }) {
    return showDialog<PrescriptionGateResult?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PrescriptionGateDialog(
        productName: productName,
        schedule: schedule,
      ),
    );
  }

  /// Backwards-compatible wrapper that returns just the prescription ID.
  /// Prefer [showRich] for new code.
  static Future<String?> show(
    BuildContext context, {
    required String productName,
    required DrugSchedule schedule,
  }) async {
    final res = await showRich(
      context,
      productName: productName,
      schedule: schedule,
    );
    return res?.prescriptionId;
  }

  @override
  State<PrescriptionGateDialog> createState() =>
      _PrescriptionGateDialogState();
}

class _PrescriptionGateDialogState extends State<PrescriptionGateDialog> {
  final _rxIdController = TextEditingController();
  final _doctorNameController = TextEditingController();
  final _doctorRegController = TextEditingController();
  final _patientNameController = TextEditingController();
  final _patientAddressController = TextEditingController();

  File? _prescriptionImage;
  bool _isUploading = false;
  String? _errorMessage;

  /// Indian MCI/DMC doctor reg pattern matching backend (DOCTOR_REG_PATTERN).
  static final RegExp _doctorRegPattern =
      RegExp(r'^[A-Z]{2,5}-\d{4,8}$', caseSensitive: false);

  bool get _requiresH1Fields =>
      widget.schedule == DrugSchedule.scheduleH1 ||
      widget.schedule == DrugSchedule.scheduleX;

  bool get _requiresPatientAddress =>
      widget.schedule == DrugSchedule.scheduleX;

  @override
  void dispose() {
    _rxIdController.dispose();
    _doctorNameController.dispose();
    _doctorRegController.dispose();
    _patientNameController.dispose();
    _patientAddressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _prescriptionImage = File(picked.path);
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Camera error: $e');
    }
  }

  String _inferMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  String? _validateContract({required String resolvedRxId}) {
    if (resolvedRxId.isEmpty) {
      return 'Enter Rx ID or scan/upload prescription image';
    }

    if (_requiresH1Fields) {
      final docName = _doctorNameController.text.trim();
      final docReg = _doctorRegController.text.trim();
      final patientName = _patientNameController.text.trim();

      if (docName.isEmpty) {
        return 'Prescribing doctor name is required for ${widget.schedule.label} drugs';
      }
      if (docReg.isEmpty) {
        return 'Doctor registration number is required for ${widget.schedule.label} drugs';
      }
      if (!_doctorRegPattern.hasMatch(docReg)) {
        return 'Doctor reg no must match XX-NNNNN format (e.g., MCI-12345)';
      }
      if (patientName.isEmpty) {
        return 'Patient name is required for ${widget.schedule.label} drugs';
      }
    }

    if (_requiresPatientAddress) {
      final addr = _patientAddressController.text.trim();
      if (addr.isEmpty) {
        return 'Patient address is required for Schedule X drugs (NDPS Act)';
      }
    }

    return null;
  }

  Future<void> _submit() async {
    final rxIdInput = _rxIdController.text.trim();

    final resolvedId = rxIdInput.isNotEmpty
        ? rxIdInput
        : (_prescriptionImage != null
            ? 'RX_${DateTime.now().millisecondsSinceEpoch}'
            : '');

    final contractError = _validateContract(resolvedRxId: resolvedId);
    if (contractError != null) {
      setState(() => _errorMessage = contractError);
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final api = sl<ApiClient>();
      String storagePath;
      String fileHash;
      String? mimeType;

      if (_prescriptionImage != null) {
        final bytes = await _prescriptionImage!.readAsBytes();
        fileHash = sha256.convert(bytes).toString();
        mimeType = _inferMimeType(_prescriptionImage!.path);
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}-${_prescriptionImage!.path.split(Platform.pathSeparator).last}';
        final signedUrlRes = await api.get(
          '/storage/signed-url?action=upload&path=prescriptions/$fileName&contentType=${Uri.encodeComponent(mimeType)}&maxSizeMB=10',
        );
        if (!signedUrlRes.isSuccess || signedUrlRes.data == null) {
          throw Exception(
              signedUrlRes.error ?? 'Failed to generate upload URL');
        }
        final payload =
            Map<String, dynamic>.from(signedUrlRes.data!['data'] ?? {});
        final uploadUrl = payload['url']?.toString();
        storagePath = payload['path']?.toString() ?? '';
        if (uploadUrl == null || uploadUrl.isEmpty || storagePath.isEmpty) {
          throw Exception('Invalid signed URL response');
        }

        final uploadRes = await http.put(
          Uri.parse(uploadUrl),
          headers: {
            'Content-Type': mimeType,
          },
          body: bytes,
        );
        if (uploadRes.statusCode < 200 || uploadRes.statusCode >= 300) {
          throw Exception(
              'S3 upload failed with status ${uploadRes.statusCode}');
        }
      } else {
        fileHash = sha256.convert(utf8.encode(resolvedId)).toString();
        storagePath = 'manual://prescriptions/$resolvedId';
      }

      final response = await api.post(
        '/pharmacy/prescriptions/evidence',
        body: {
          'prescriptionId': resolvedId,
          'storagePath': storagePath,
          'fileHashSha256': fileHash,
          ...{'mimeType': mimeType},
          'notes': _prescriptionImage != null
              ? 'Uploaded from POS prescription gate'
              : 'Manual prescription ID entry from POS',
        },
      );

      if (!response.isSuccess) {
        setState(() {
          _errorMessage = response.error ?? 'Failed to save evidence';
          _isUploading = false;
        });
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pop(PrescriptionGateResult(
        prescriptionId: resolvedId,
        schedule: widget.schedule,
        doctorName: _doctorNameController.text.trim().isEmpty
            ? null
            : _doctorNameController.text.trim(),
        doctorRegNo: _doctorRegController.text.trim().isEmpty
            ? null
            : _doctorRegController.text.trim(),
        patientName: _patientNameController.text.trim().isEmpty
            ? null
            : _patientNameController.text.trim(),
        patientAddress: _patientAddressController.text.trim().isEmpty
            ? null
            : _patientAddressController.text.trim(),
      ));
    } catch (e) {
      setState(() {
        _errorMessage = 'Evidence save failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 768;
    final dialogWidth =
        isWide ? 560.0 : MediaQuery.of(context).size.width * 0.92;

    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: dialogWidth,
        ),
        child: Container(
          width: dialogWidth,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildProductPanel(),
                const SizedBox(height: 16),
                _buildRxField(),
                const SizedBox(height: 12),
                _buildOrDivider(),
                const SizedBox(height: 12),
                _buildScanRow(),
                if (_prescriptionImage != null) ...[
                  const SizedBox(height: 12),
                  _buildPreview(),
                ],
                if (_requiresH1Fields) ...[
                  const SizedBox(height: 16),
                  _buildSectionTitle(
                    widget.schedule == DrugSchedule.scheduleX
                        ? 'Schedule X — Statutory Fields'
                        : 'Schedule H1 — Statutory Fields',
                  ),
                  const SizedBox(height: 8),
                  _buildLabeledField(
                    controller: _doctorNameController,
                    label: 'Prescribing Doctor Name',
                    icon: Icons.medical_information,
                  ),
                  const SizedBox(height: 8),
                  _buildLabeledField(
                    controller: _doctorRegController,
                    label: 'Doctor Reg No (e.g. MCI-12345)',
                    icon: Icons.verified,
                  ),
                  const SizedBox(height: 8),
                  _buildLabeledField(
                    controller: _patientNameController,
                    label: 'Patient Name',
                    icon: Icons.person,
                  ),
                  if (_requiresPatientAddress) ...[
                    const SizedBox(height: 8),
                    _buildLabeledField(
                      controller: _patientAddressController,
                      label: 'Patient Address (NDPS Act)',
                      icon: Icons.home,
                      maxLines: 2,
                    ),
                  ],
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ],
                if (widget.schedule == DrugSchedule.scheduleX) ...[
                  const SizedBox(height: 12),
                  _buildScheduleXNotice(),
                ],
                const SizedBox(height: 20),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _scheduleColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.medical_services,
                color: _scheduleColor, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prescription Required',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${widget.schedule.label} Drug',
                  style: TextStyle(
                    fontSize: 13,
                    color: _scheduleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _buildProductPanel() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _scheduleColor.withValues(alpha: 0.3)),
        ),
        child: Text(
          widget.productName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      );

  Widget _buildRxField() => TextField(
        controller: _rxIdController,
        style: const TextStyle(color: Colors.white),
        decoration: _decoration(
          'Prescription ID / Rx Number',
          icon: Icons.qr_code,
          hint: 'Enter Rx ID from prescription',
        ),
        onSubmitted: (_) => _submit(),
      );

  Widget _buildOrDivider() => Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade700)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('OR', style: TextStyle(color: Colors.grey.shade500)),
          ),
          Expanded(child: Divider(color: Colors.grey.shade700)),
        ],
      );

  Widget _buildScanRow() => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan Rx'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _scheduleColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: _scheduleColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _scheduleColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: _scheduleColor),
              ),
            ),
          ),
        ],
      );

  Widget _buildPreview() => Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _prescriptionImage!,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _prescriptionImage = null),
            icon: const Icon(Icons.close, size: 16, color: Colors.red),
            label: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      );

  Widget _buildSectionTitle(String text) => Text(
        text,
        style: TextStyle(
          color: _scheduleColor,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      );

  Widget _buildLabeledField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: _decoration(label, icon: icon),
      );

  InputDecoration _decoration(
    String label, {
    required IconData icon,
    String? hint,
  }) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade400),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: Colors.grey.shade400),
        filled: true,
        fillColor: const Color(0xFF2A2A3E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _scheduleColor),
        ),
      );

  Widget _buildScheduleXNotice() => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Schedule X: Patient ID proof & narcotic register entry mandatory.',
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
          ],
        ),
      );

  Widget _buildActions() => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(null),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey.shade700),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isUploading ? null : _submit,
              icon: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle),
              label:
                  Text(_isUploading ? 'Verifying...' : 'Confirm & Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _scheduleColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      );

  Color get _scheduleColor => switch (widget.schedule) {
        DrugSchedule.scheduleH => Colors.orange,
        DrugSchedule.scheduleH1 => Colors.deepOrange,
        DrugSchedule.scheduleX => Colors.red,
        _ => Colors.blue,
      };
}
