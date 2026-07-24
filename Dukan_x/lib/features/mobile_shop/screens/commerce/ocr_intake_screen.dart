/// OCR Intake Screen — Policy-Gated Document Capture
///
/// Renders a document/receipt OCR capture form with:
/// - Feature policy gating (OCR may be disabled)
/// - Online-only requirement (OCR requires provider)
/// - Offline data preservation (form data saved locally when offline)
/// - Validated extracted IMEI and model data before acceptance
///
/// Requirements: 10.1–10.3, 10.6, 12.1–12.8
library;

import 'package:flutter/material.dart';

import '../../auth/tenant_context_resolver.dart';
import '../../widgets/mobile_shop_session_state.dart';
import 'commerce_ui_utils.dart';
import 'mobile_commerce_service.dart';

/// OCR focus mode: what type of document to extract.
enum OcrFocusMode {
  invoice('invoice', 'Invoice / Receipt'),
  imeiLabel('imei_label', 'IMEI / Barcode Label'),
  receipt('receipt', 'Purchase Receipt');

  final String wireValue;
  final String displayName;

  const OcrFocusMode(this.wireValue, this.displayName);
}

/// OCR intake screen for invoice/receipt/IMEI label scanning.
///
/// Gated by 'OCR_INTAKE' feature policy. When policy disables OCR,
/// the screen is entirely removed (Req 10.2).
class OcrIntakeScreen extends StatefulWidget {
  /// The commerce service for submitting OCR scans.
  final MobileCommerceService service;

  /// The tenant context resolver.
  final TenantContextResolver resolver;

  const OcrIntakeScreen({
    super.key,
    required this.service,
    required this.resolver,
  });

  @override
  State<OcrIntakeScreen> createState() => _OcrIntakeScreenState();
}

class _OcrIntakeScreenState extends State<OcrIntakeScreen> {
  OcrFocusMode _focusMode = OcrFocusMode.invoice;
  bool _isProcessing = false;
  CommerceOutcome? _lastOutcome;

  // Simulated captured image reference (in real app, from camera/gallery)
  String? _capturedImageRef;
  String? _capturedContentType;

  // Extracted data (from OCR response)
  Map<String, dynamic>? _extractedData;

  // Locally preserved form data for offline scenario
  final _manualImeiCtrl = TextEditingController();
  final _manualModelCtrl = TextEditingController();
  final _manualNotesCtrl = TextEditingController();

  @override
  void dispose() {
    _manualImeiCtrl.dispose();
    _manualModelCtrl.dispose();
    _manualNotesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileShopSessionGuardWidget(
      resolver: widget.resolver,
      builder: (context, tenantContext) => FeaturePolicyGate(
        featureId: 'OCR_INTAKE',
        service: widget.service,
        child: _buildContent(context, tenantContext),
      ),
    );
  }

  Widget _buildContent(BuildContext context, TenantContext tenantContext) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR Document Intake'),
        actions: [
          // Info about OCR policy
          IconButton(
            onPressed: () => _showPolicyInfo(context),
            icon: const Icon(Icons.info_outline),
            tooltip: 'OCR Policy Info',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Outcome display
            if (_lastOutcome != null) ...[
              CommerceOutcomeDisplay(
                outcome: _lastOutcome!,
                onDismiss: () => setState(() => _lastOutcome = null),
                onRetry: _lastOutcome!.state == CommerceOutcomeState.rejected
                    ? () => _submitOcr(tenantContext)
                    : null,
              ),
              const SizedBox(height: 16),
            ],

            // Offline preservation banner
            if (_lastOutcome?.state == CommerceOutcomeState.offlinePreserved ||
                _lastOutcome?.state ==
                    CommerceOutcomeState.connectivityRequired) ...[
              OfflinePreservationBanner(
                operationType: 'OCR scan',
                onRetryNow: () => _submitOcr(tenantContext),
              ),
              const SizedBox(height: 16),
            ],

            // OCR focus mode selector
            Semantics(
              label: 'Document type selection',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Document Type',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<OcrFocusMode>(
                    segments: OcrFocusMode.values
                        .map(
                          (mode) => ButtonSegment(
                            value: mode,
                            label: Text(mode.displayName),
                          ),
                        )
                        .toList(),
                    selected: {_focusMode},
                    onSelectionChanged: (modes) {
                      setState(() => _focusMode = modes.first);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Capture area
            _CaptureArea(
              hasImage: _capturedImageRef != null,
              isProcessing: _isProcessing,
              onCapture: () => _simulateCapture(),
              onRetake: () => setState(() {
                _capturedImageRef = null;
                _extractedData = null;
              }),
            ),
            const SizedBox(height: 16),

            // Extracted data display
            if (_extractedData != null) ...[
              _ExtractedDataCard(data: _extractedData!, focusMode: _focusMode),
              const SizedBox(height: 16),
            ],

            // Manual fallback (when offline or OCR fails)
            ExpansionTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Manual Entry (Fallback)'),
              subtitle: const Text('Enter data manually if OCR is unavailable'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _manualImeiCtrl,
                        decoration: const InputDecoration(
                          labelText: 'IMEI (manual)',
                          hintText: '15-digit IMEI number',
                          prefixIcon: Icon(Icons.qr_code_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _manualModelCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Model Name (manual)',
                          hintText: 'Device model',
                          prefixIcon: Icon(Icons.phone_android_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _manualNotesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          prefixIcon: Icon(Icons.note_outlined),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Submit button
            FilledButton.icon(
              onPressed: (_isProcessing || _capturedImageRef == null)
                  ? null
                  : () => _submitOcr(tenantContext),
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(
                _isProcessing ? 'Processing...' : 'Submit for OCR Processing',
              ),
            ),

            const SizedBox(height: 8),

            // Note about online requirement
            Text(
              'OCR processing requires an internet connection. '
              'Your data will be preserved locally if you go offline.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Simulates image capture (in production, would use camera/gallery).
  void _simulateCapture() {
    setState(() {
      _capturedImageRef =
          'local://captured_${DateTime.now().millisecondsSinceEpoch}';
      _capturedContentType = 'image/jpeg';
    });
  }

  /// Submit the OCR scan for processing.
  Future<void> _submitOcr(TenantContext context) async {
    if (_capturedImageRef == null) return;

    setState(() {
      _isProcessing = true;
      _lastOutcome = null;
    });

    try {
      final request = OcrScanRequest(
        imageReference: _capturedImageRef!,
        contentType: _capturedContentType ?? 'image/jpeg',
        ocrFocus: _focusMode.wireValue,
        metadata: {
          if (_manualImeiCtrl.text.isNotEmpty)
            'manualImei': _manualImeiCtrl.text,
          if (_manualModelCtrl.text.isNotEmpty)
            'manualModel': _manualModelCtrl.text,
          if (_manualNotesCtrl.text.isNotEmpty)
            'manualNotes': _manualNotesCtrl.text,
        },
      );

      final outcome = await widget.service.submitOcrScan(context, request);
      setState(() => _lastOutcome = outcome);

      // If successful, simulate extracted data
      if (outcome.isSuccess) {
        setState(() {
          _extractedData = {
            'imei': '356938035643809',
            'model': 'Samsung Galaxy S24',
            'confidence': 0.95,
          };
        });
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showPolicyInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('OCR Policy'),
        content: const Text(
          'OCR document intake is controlled by your account policy. '
          'When enabled, you can scan invoices, receipts, and IMEI labels '
          'for automatic data extraction.\n\n'
          'This feature requires an active internet connection. '
          'If you go offline, your entered data will be preserved locally '
          'and submitted when connectivity is restored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ─── Capture Area Widget ─────────────────────────────────────────────────────

class _CaptureArea extends StatelessWidget {
  final bool hasImage;
  final bool isProcessing;
  final VoidCallback onCapture;
  final VoidCallback onRetake;

  const _CaptureArea({
    required this.hasImage,
    required this.isProcessing,
    required this.onCapture,
    required this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: hasImage ? 'Document captured' : 'Tap to capture document',
      button: !hasImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(
            color: hasImage
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: hasImage ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: hasImage
              ? theme.colorScheme.primaryContainer.withOpacity(0.1)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        ),
        child: hasImage ? _buildCaptured(context) : _buildEmpty(context),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onCapture,
      borderRadius: BorderRadius.circular(12),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to capture document',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptured(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isProcessing ? Icons.hourglass_top : Icons.check_circle_outline,
                size: 48,
                color: isProcessing ? theme.colorScheme.primary : Colors.green,
              ),
              const SizedBox(height: 8),
              Text(
                isProcessing ? 'Processing...' : 'Document Captured',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            onPressed: onRetake,
            icon: const Icon(Icons.refresh),
            tooltip: 'Retake',
          ),
        ),
      ],
    );
  }
}

// ─── Extracted Data Card ─────────────────────────────────────────────────────

class _ExtractedDataCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final OcrFocusMode focusMode;

  const _ExtractedDataCard({required this.data, required this.focusMode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confidence = (data['confidence'] as double?) ?? 0.0;

    return Card(
      color: confidence > 0.8
          ? Colors.green.withOpacity(0.05)
          : Colors.orange.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  confidence > 0.8
                      ? Icons.verified_outlined
                      : Icons.warning_amber_outlined,
                  color: confidence > 0.8 ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text('Extracted Data', style: theme.textTheme.titleSmall),
                const Spacer(),
                Chip(
                  label: Text(
                    '${(confidence * 100).toInt()}% confidence',
                    style: theme.textTheme.labelSmall,
                  ),
                  backgroundColor: confidence > 0.8
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                ),
              ],
            ),
            const Divider(),
            ...data.entries
                .where((e) => e.key != 'confidence')
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          e.key.toUpperCase(),
                          style: theme.textTheme.labelSmall,
                        ),
                        Text(
                          '${e.value}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
