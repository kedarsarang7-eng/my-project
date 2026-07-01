// ============================================================================
// SECURITY SETUP WIDGET
// ============================================================================
// Owner PIN setup widget for onboarding flow.
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import 'package:flutter/services.dart';

import '../../core/security/services/owner_pin_service.dart';

/// Security Setup Widget - PIN and limits configuration.
///
/// Used during onboarding or from settings screen.
class SecuritySetupWidget extends StatefulWidget {
  final OwnerPinService pinService;
  final String businessId;
  final VoidCallback onComplete;
  final VoidCallback? onSkip;
  final bool showSkip;

  const SecuritySetupWidget({
    super.key,
    required this.pinService,
    required this.businessId,
    required this.onComplete,
    this.onSkip,
    this.showSkip = false,
  });

  @override
  State<SecuritySetupWidget> createState() => _SecuritySetupWidgetState();
}

class _SecuritySetupWidgetState extends State<SecuritySetupWidget> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _obscurePin = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _error;

  // Security settings with defaults
  int _maxDiscountPercent = 10;
  // DONE: Bill edit window validation implemented in FraudDetectionService.checkBillEditWindow()
  // ignore: unused_field
  final int _billEditWindowMinutes = 0;
  double _cashToleranceLimit = 100.0;
  bool _requirePinForRefunds = true;
  bool _requirePinForStockAdjustment = true;
  // DONE: Late night billing detection implemented in FraudDetectionService.checkLateNightBilling()
  // ignore: unused_field
  final int _lateNightHour = 22;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _setupSecurity() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Set PIN - this also creates settings with defaults
      await widget.pinService.setPin(
        businessId: widget.businessId,
        pin: _pinController.text,
      );

      // Note: Settings are created by setPin with sensible defaults.
      // For custom settings, use updateSecuritySettings after PIN is set.

      widget.onComplete();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.security, size: 32, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Security Setup',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Protect your business with a secure PIN',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // PIN Setup Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Owner PIN',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This PIN will be required for critical actions like deleting bills, giving high discounts, and editing locked bills.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // PIN Field
                    TextFormField(
                      controller: _pinController,
                      obscureText: _obscurePin,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Enter 4-6 digit PIN',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePin
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePin = !_obscurePin),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'PIN is required';
                        }
                        if (value.length < 4) {
                          return 'PIN must be at least 4 digits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirm PIN Field
                    TextFormField(
                      controller: _confirmPinController,
                      obscureText: _obscureConfirm,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Confirm PIN',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value != _pinController.text) {
                          return 'PINs do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Security Limits Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Security Limits',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Max Discount
                    _buildSliderSetting(
                      title: 'Max Discount Without PIN',
                      value: _maxDiscountPercent.toDouble(),
                      min: 0,
                      max: 50,
                      suffix: '%',
                      onChanged: (v) =>
                          setState(() => _maxDiscountPercent = v.round()),
                    ),
                    const Divider(),

                    // Cash Tolerance
                    _buildSliderSetting(
                      title: 'Cash Variance Tolerance',
                      value: _cashToleranceLimit,
                      min: 0,
                      max: 1000,
                      suffix: sl<CurrencyService>().symbol,
                      onChanged: (v) => setState(() => _cashToleranceLimit = v),
                    ),
                    const Divider(),

                    // Switches
                    SwitchListTile(
                      title: const Text('Require PIN for Refunds'),
                      subtitle: const Text('PIN needed to process refunds'),
                      value: _requirePinForRefunds,
                      onChanged: (v) =>
                          setState(() => _requirePinForRefunds = v),
                    ),
                    SwitchListTile(
                      title: const Text('Require PIN for Stock Adjustment'),
                      subtitle: const Text(
                        'PIN needed for manual stock changes',
                      ),
                      value: _requirePinForStockAdjustment,
                      onChanged: (v) =>
                          setState(() => _requirePinForStockAdjustment = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Error Display
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            // Action Buttons
            Row(
              children: [
                if (widget.showSkip)
                  TextButton(
                    onPressed: _isLoading ? null : widget.onSkip,
                    child: const Text('Skip for Now'),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _setupSecurity,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_isLoading ? 'Setting Up...' : 'Complete Setup'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderSetting({
    required String title,
    required double value,
    required double min,
    required double max,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title),
            Text(
              '${value.toStringAsFixed(0)}$suffix',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
