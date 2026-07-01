import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/di/service_locator.dart';

/// Dialog shown when cashier wants to override FEFO auto-selected batch.
/// Requires supervisor PIN to proceed — prevents selling newer stock first.
///
/// SECURITY (P0 risk-fix): the supervisor PIN is verified against the backend
/// `POST /pharmacy/fefo-override/authorize` endpoint, which:
///   * looks up the calling user's stored PIN (managerPin/overridePin/pin)
///   * optionally falls back to a server-side master PIN (env-only)
///   * writes a tamper-evident audit row for Drug Inspector trail
/// The previous hardcoded `'1234'` PIN is removed entirely.
class FefoOverrideDialog extends StatefulWidget {
  final String productName;
  final String? productId;
  final String autoSelectedBatch;
  final String? autoSelectedBatchId;
  final DateTime? autoSelectedExpiry;
  final List<OverrideBatchOption> availableBatches;

  const FefoOverrideDialog({
    super.key,
    required this.productName,
    this.productId,
    required this.autoSelectedBatch,
    this.autoSelectedBatchId,
    this.autoSelectedExpiry,
    required this.availableBatches,
  });

  static Future<OverrideBatchResult?> show(
    BuildContext context, {
    required String productName,
    String? productId,
    required String autoSelectedBatch,
    String? autoSelectedBatchId,
    DateTime? autoSelectedExpiry,
    required List<OverrideBatchOption> availableBatches,
  }) {
    return showDialog<OverrideBatchResult?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FefoOverrideDialog(
        productName: productName,
        productId: productId,
        autoSelectedBatch: autoSelectedBatch,
        autoSelectedBatchId: autoSelectedBatchId,
        autoSelectedExpiry: autoSelectedExpiry,
        availableBatches: availableBatches,
      ),
    );
  }

  @override
  State<FefoOverrideDialog> createState() => _FefoOverrideDialogState();
}

class _FefoOverrideDialogState extends State<FefoOverrideDialog> {
  final _pinController = TextEditingController();
  final _reasonController = TextEditingController();
  String? _selectedBatchId;
  String? _error;
  bool _pinVerified = false;
  bool _verifying = false;

  /// Audit id returned from the backend after a successful PIN verification.
  /// Echoed back via [OverrideBatchResult] so downstream operations (e.g.
  /// invoice creation) can attach it for compliance traceability.
  String? _overrideAuditId;

  @override
  void dispose() {
    _pinController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _error = 'Enter supervisor PIN');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final api = sl<ApiClient>();
      final response = await api.post(
        '/pharmacy/fefo-override/authorize',
        body: <String, dynamic>{
          'supervisorPin': pin,
          if (widget.productId != null) 'productId': widget.productId,
          if (widget.autoSelectedBatchId != null)
            'autoSelectedBatchId': widget.autoSelectedBatchId,
          if (_reasonController.text.trim().isNotEmpty)
            'reason': _reasonController.text.trim(),
        },
      );

      if (!mounted) return;
      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        final payload =
            (data['data'] as Map<String, dynamic>?) ?? data;
        setState(() {
          _pinVerified = true;
          _overrideAuditId =
              payload['overrideId']?.toString();
          _error = null;
          _verifying = false;
        });
      } else {
        setState(() {
          _error = response.error ?? 'Invalid supervisor PIN';
          _verifying = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Verification failed: $e';
        _verifying = false;
      });
    }
  }

  void _confirm() {
    if (_selectedBatchId == null) {
      setState(() => _error = 'Select a batch');
      return;
    }
    final selectedBatch = widget.availableBatches
        .firstWhere((b) => b.batchId == _selectedBatchId);
    Navigator.of(context).pop(OverrideBatchResult(
      batchId: selectedBatch.batchId,
      batchNumber: selectedBatch.batchNumber,
      expiryDate: selectedBatch.expiryDate,
      overrideAuditId: _overrideAuditId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 768;

    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isTablet ? 500 : double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.swap_horiz,
                      color: Colors.orange, size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Override FEFO Selection',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Product
            Text(
              widget.productName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),

            const SizedBox(height: 12),

            // Current auto-selected batch
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'FEFO Selected: ${widget.autoSelectedBatch} '
                      '(Exp: ${_formatDate(widget.autoSelectedExpiry)})',
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Step 1: Supervisor PIN
            if (!_pinVerified) ...[
              const Text(
                'Supervisor PIN required to override:',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pinController,
                obscureText: true,
                maxLength: 20,
                enabled: !_verifying,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Supervisor PIN',
                  labelStyle: TextStyle(color: Colors.grey.shade400),
                  errorText: _error,
                  prefixIcon:
                      Icon(Icons.lock, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: const Color(0xFF2A2A3E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade700),
                  ),
                ),
                onSubmitted: (_) => _verifyPin(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                enabled: !_verifying,
                style: const TextStyle(color: Colors.white),
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: 'Reason (optional, audited)',
                  labelStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon:
                      Icon(Icons.notes, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: const Color(0xFF2A2A3E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _verifying
                          ? null
                          : () => Navigator.of(context).pop(null),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade400,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade700),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _verifying ? null : _verifyPin,
                      icon: _verifying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.vpn_key),
                      label:
                          Text(_verifying ? 'Verifying…' : 'Verify PIN'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Step 2: Batch selection (after PIN verified)
            if (_pinVerified) ...[
              const Text(
                'Select batch:',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: SingleChildScrollView(
                  child: Column(
                    children: widget.availableBatches
                        .map((batch) => RadioListTile<String>(
                              value: batch.batchId,
                              groupValue: _selectedBatchId,
                              onChanged: (v) =>
                                  setState(() => _selectedBatchId = v),
                              title: Text(
                                '${batch.batchNumber} — Stock: ${batch.stockQty}',
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.white),
                              ),
                              subtitle: Text(
                                'Exp: ${_formatDate(batch.expiryDate)}'
                                '${batch.rackLocation != null ? " | Rack: ${batch.rackLocation}" : ""}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        _expiryColor(batch.expiryDate)),
                              ),
                              dense: true,
                              activeColor: Colors.orange,
                            ))
                        .toList(),
                  ),
                ),
              ),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: Colors.red, fontSize: 13)),
                ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade400,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade700),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _confirm,
                      icon: const Icon(Icons.check),
                      label: const Text('Use Selected Batch'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? d) =>
      d != null ? d.toIso8601String().substring(0, 10) : 'N/A';

  Color _expiryColor(DateTime? d) {
    if (d == null) return Colors.grey;
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0) return Colors.red;
    if (days <= 90) return Colors.amber.shade700;
    return Colors.green;
  }
}

class OverrideBatchOption {
  final String batchId;
  final String batchNumber;
  final DateTime? expiryDate;
  final double stockQty;
  final String? rackLocation;

  OverrideBatchOption({
    required this.batchId,
    required this.batchNumber,
    this.expiryDate,
    required this.stockQty,
    this.rackLocation,
  });
}

class OverrideBatchResult {
  final String batchId;
  final String batchNumber;
  final DateTime? expiryDate;
  /// Server-side audit row id returned from
  /// `POST /pharmacy/fefo-override/authorize`. Echoed downstream so that the
  /// originating invoice can be cross-referenced for Drug Inspector audits.
  final String? overrideAuditId;

  OverrideBatchResult({
    required this.batchId,
    required this.batchNumber,
    this.expiryDate,
    this.overrideAuditId,
  });
}
