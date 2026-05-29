import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Staff Quick Pay Screen
/// 
/// Mobile-optimized quick payment screen for staff members.
/// Simple, fast payment entry with QR code generation.
class StaffQuickPayScreen extends ConsumerStatefulWidget {
  const StaffQuickPayScreen({super.key});

  @override
  ConsumerState<StaffQuickPayScreen> createState() => _StaffQuickPayScreenState();
}

class _StaffQuickPayScreenState extends ConsumerState<StaffQuickPayScreen> {
  final _amountController = TextEditingController();
  String _selectedFuelType = 'Petrol';
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _quickAmounts = [
    {'label': '₹500', 'value': 500},
    {'label': '₹1000', 'value': 1000},
    {'label': '₹2000', 'value': 2000},
    {'label': '₹5000', 'value': 5000},
  ];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _selectQuickAmount(int amount) {
    setState(() {
      _amountController.text = amount.toString();
    });
  }

  void _generateQR() {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    // Navigate to QR display
    context.push('/staff-mobile/qr-display', extra: {
      'amount': amount,
      'fuelType': _selectedFuelType,
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.go('/staff-mobile'),
        ),
        title: const Text(
          'Quick Pay',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Amount Input Section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount Display
                  _buildAmountDisplay(),
                  const SizedBox(height: 24),

                  // Fuel Type Selector
                  _buildFuelTypeSelector(),
                  const SizedBox(height: 24),

                  // Quick Amount Buttons
                  _buildQuickAmounts(),
                  const SizedBox(height: 24),

                  // Number Pad
                  _buildNumberPad(),
                ],
              ),
            ),
          ),

          // Generate QR Button
          _buildGenerateButton(),
        ],
      ),
    );
  }

  Widget _buildAmountDisplay() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A5F),
            Color(0xFF2D5A87),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter Amount',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            formatter.format(amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_selectedFuelType.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_gas_station,
                    color: _selectedFuelType == 'Petrol' 
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFFF59E0B),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _selectedFuelType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFuelTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Fuel Type',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildFuelTypeCard('Petrol', const Color(0xFF3B82F6)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFuelTypeCard('Diesel', const Color(0xFFF59E0B)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFuelTypeCard(String fuelType, Color color) {
    final isSelected = _selectedFuelType == fuelType;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFuelType = fuelType;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha:0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_gas_station,
              color: isSelected ? color : Colors.grey[400],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              fuelType,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAmounts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Amounts',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _quickAmounts.map((item) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _selectQuickAmount(item['value'] as int),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      item['label'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNumberPad() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.5,
      children: [
        ...['1', '2', '3', '4', '5', '6', '7', '8', '9'].map((digit) => _buildNumberButton(digit)),
        _buildNumberButton('.', isSpecial: true),
        _buildNumberButton('0'),
        _buildNumberButton('⌫', isSpecial: true, isBackspace: true),
      ],
    );
  }

  Widget _buildNumberButton(String digit, {bool isSpecial = false, bool isBackspace = false}) {
    return GestureDetector(
      onTap: () {
        if (isBackspace) {
          final currentText = _amountController.text;
          if (currentText.isNotEmpty) {
            setState(() {
              _amountController.text = currentText.substring(0, currentText.length - 1);
            });
          }
        } else if (digit == '.') {
          if (!_amountController.text.contains('.')) {
            setState(() {
              _amountController.text += digit;
            });
          }
        } else {
          setState(() {
            _amountController.text += digit;
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSpecial ? const Color(0xFFE2E8F0) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: isBackspace
              ? Icon(Icons.backspace_outlined, color: Colors.grey[700], size: 24)
              : Text(
                  digit,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: isSpecial ? const Color(0xFF1E3A5F) : const Color(0xFF1E293B),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _generateQR,
            icon: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.qr_code),
            label: Text(
              _isProcessing ? 'Processing...' : 'Generate QR Code',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}
