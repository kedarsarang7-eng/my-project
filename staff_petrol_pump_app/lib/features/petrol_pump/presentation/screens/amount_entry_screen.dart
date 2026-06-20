import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/license_provider.dart';
import '../../providers/qr_payment_provider.dart';
import '../../theme/fuelpos_theme.dart';
import '../../widgets/sidebar_nav_widget.dart';

/// Amount Entry Screen
///
/// Staff enters the payment amount here before generating QR code.
/// Features:
/// - Numeric keypad input
/// - Quick amount buttons (100, 200, 500, 1000)
/// - Amount validation (min/max)
/// - Fuel type selection (optional)
class AmountEntryScreen extends ConsumerStatefulWidget {
  const AmountEntryScreen({super.key});

  @override
  ConsumerState<AmountEntryScreen> createState() => _AmountEntryScreenState();
}

class _AmountEntryScreenState extends ConsumerState<AmountEntryScreen> {
  final _amountController = TextEditingController();
  String? _errorText;
  bool _isGenerating = false;
  String? _selectedFuelType;
  String? _vehicleNumber;

  // Quick amount presets
  final List<double> _quickAmounts = [100, 200, 500, 1000];

  @override
  void initState() {
    super.initState();
    // Pre-fill amount from query parameter (e.g., on retry from payment failed)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final amount = GoRouterState.of(context).uri.queryParameters['amount'];
      if (amount != null && amount.isNotEmpty) {
        _amountController.text = amount;
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onQuickAmount(double amount) {
    setState(() {
      _amountController.text = amount.toStringAsFixed(0);
      _errorText = null;
    });
  }

  void _validateAndGenerate() async {
    final amountText = _amountController.text.trim();

    // Validation
    if (amountText.isEmpty) {
      setState(() => _errorText = 'Please enter an amount');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _errorText = 'Please enter a valid amount');
      return;
    }

    if (amount < 10) {
      setState(() => _errorText = 'Minimum amount is ₹10');
      return;
    }

    if (amount > 100000) {
      setState(() => _errorText = 'Maximum amount is ₹1,00,000');
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorText = null;
    });

    // Generate QR
    final description = _selectedFuelType != null
        ? 'Fuel: $_selectedFuelType' +
            (_vehicleNumber != null ? ' | Vehicle: $_vehicleNumber' : '')
        : (_vehicleNumber != null ? 'Vehicle: $_vehicleNumber' : null);

    await ref.read(qrPaymentProvider.notifier).generateQR(
          amountRupees: amount,
          description: description,
        );

    if (!mounted) return;

    final qrState = ref.read(qrPaymentProvider);

    if (qrState.error != null) {
      setState(() {
        _isGenerating = false;
        _errorText = qrState.error;
      });
      return;
    }

    if (qrState.hasQR) {
      // Navigate to QR display screen
      context.go('/qr/display');
    } else {
      setState(() {
        _isGenerating = false;
        _errorText = 'Failed to generate QR code';
      });
    }
  }

  String get _formattedAmount {
    final text = _amountController.text.trim();
    if (text.isEmpty) return '₹0.00';

    final amount = double.tryParse(text);
    if (amount == null) return '₹0.00';

    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final license = ref.watch(licenseProvider).profile;
    final stationName = license?.stationName ?? 'Unknown Station';

    return Scaffold(
      backgroundColor: FuelPOSTheme.backgroundDark,
      body: Row(
        children: [
          // Sidebar
          const SidebarNavWidget(
            currentRoute: '/qr/entry',
          ),

          // Main content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(stationName),
                  const SizedBox(height: 32),

                  // Amount entry card
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Card(
                          color: FuelPOSTheme.cardDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: FuelPOSTheme.borderDark),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Title
                                const Text(
                                  'Generate Payment QR',
                                  style: TextStyle(
                                    color: FuelPOSTheme.textPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Enter amount for customer to pay',
                                  style: TextStyle(
                                    color: FuelPOSTheme.textSecondary,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 32),

                                // Amount display
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: FuelPOSTheme.surfaceDark,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _errorText != null
                                          ? FuelPOSTheme.errorRed
                                          : FuelPOSTheme.borderDark,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Amount',
                                        style: TextStyle(
                                          color: FuelPOSTheme.textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _formattedAmount,
                                        style: const TextStyle(
                                          color: FuelPOSTheme.textPrimary,
                                          fontSize: 48,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Amount input field
                                TextField(
                                  controller: _amountController,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  autofocus: true,
                                  style: const TextStyle(
                                    color: FuelPOSTheme.textPrimary,
                                    fontSize: 24,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Enter Amount (₹)',
                                    labelStyle: TextStyle(
                                      color: FuelPOSTheme.textSecondary,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.currency_rupee,
                                      color: FuelPOSTheme.textSecondary,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: FuelPOSTheme.borderDark,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: FuelPOSTheme.borderDark,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: FuelPOSTheme.primaryBlue,
                                      ),
                                    ),
                                    errorText: _errorText,
                                    errorStyle: TextStyle(
                                      color: FuelPOSTheme.errorRed,
                                    ),
                                  ),
                                  onChanged: (_) =>
                                      setState(() => _errorText = null),
                                  onSubmitted: (_) => _validateAndGenerate(),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d{0,2}')),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Quick amount buttons
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  alignment: WrapAlignment.center,
                                  children: _quickAmounts.map((amount) {
                                    return ActionChip(
                                      label: Text(
                                        '₹${amount.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          color: FuelPOSTheme.textPrimary,
                                        ),
                                      ),
                                      backgroundColor: FuelPOSTheme.cardDark,
                                      side: BorderSide(
                                          color: FuelPOSTheme.borderDark),
                                      onPressed: () => _onQuickAmount(amount),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 24),

                                // Optional fuel type selection
                                _buildFuelTypeSelector(),
                                const SizedBox(height: 16),

                                // Optional vehicle number
                                TextField(
                                  onChanged: (value) => _vehicleNumber =
                                      value.isEmpty ? null : value,
                                  style: const TextStyle(
                                    color: FuelPOSTheme.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Vehicle Number (Optional)',
                                    labelStyle: TextStyle(
                                      color: FuelPOSTheme.textSecondary,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.directions_car,
                                      color: FuelPOSTheme.textSecondary,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: FuelPOSTheme.borderDark,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: FuelPOSTheme.borderDark,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Generate QR button
                                SizedBox(
                                  height: 56,
                                  child: ElevatedButton.icon(
                                    onPressed: _isGenerating
                                        ? null
                                        : _validateAndGenerate,
                                    icon: _isGenerating
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.qr_code),
                                    label: Text(
                                      _isGenerating
                                          ? 'Generating...'
                                          : 'Generate QR Code',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          FuelPOSTheme.primaryGreen,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String stationName) {
    return Row(
      children: [
        Text(
          'FuelPOS',
          style: TextStyle(
            color: FuelPOSTheme.textMuted,
            fontSize: 14,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.chevron_right,
            color: FuelPOSTheme.textMuted,
            size: 18,
          ),
        ),
        Text(
          stationName,
          style: TextStyle(
            color: FuelPOSTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.chevron_right,
            color: FuelPOSTheme.textMuted,
            size: 18,
          ),
        ),
        Text(
          'New Payment',
          style: TextStyle(
            color: FuelPOSTheme.textPrimary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildFuelTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fuel Type (Optional)',
          style: TextStyle(
            color: FuelPOSTheme.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Petrol'),
                selected: _selectedFuelType == 'Petrol',
                onSelected: (selected) {
                  setState(() {
                    _selectedFuelType = selected ? 'Petrol' : null;
                  });
                },
                selectedColor: FuelPOSTheme.petrolBlue.withValues(alpha: 0.3),
                backgroundColor: FuelPOSTheme.cardDark,
                labelStyle: TextStyle(
                  color: _selectedFuelType == 'Petrol'
                      ? FuelPOSTheme.petrolBlue
                      : FuelPOSTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: const Text('Diesel'),
                selected: _selectedFuelType == 'Diesel',
                onSelected: (selected) {
                  setState(() {
                    _selectedFuelType = selected ? 'Diesel' : null;
                  });
                },
                selectedColor: FuelPOSTheme.dieselOrange.withValues(alpha: 0.3),
                backgroundColor: FuelPOSTheme.cardDark,
                labelStyle: TextStyle(
                  color: _selectedFuelType == 'Diesel'
                      ? FuelPOSTheme.dieselOrange
                      : FuelPOSTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
