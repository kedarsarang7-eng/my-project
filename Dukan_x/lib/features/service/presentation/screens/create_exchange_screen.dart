/// Create Exchange Screen
/// Futuristic UI for creating new device exchange
library;

import 'package:flutter/material.dart';
import 'package:dukanx/core/compat/firebase_auth_compat.dart';
import 'package:dukanx/core/database/app_database.dart';
import '../../models/exchange.dart';
import '../../services/exchange_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class CreateExchangeScreen extends StatefulWidget {
  const CreateExchangeScreen({super.key});

  @override
  State<CreateExchangeScreen> createState() => _CreateExchangeScreenState();
}

class _CreateExchangeScreenState extends State<CreateExchangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // Customer Info
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();

  // Old Device
  final _oldDeviceNameController = TextEditingController();
  final _oldDeviceBrandController = TextEditingController();
  final _oldDeviceModelController = TextEditingController();
  final _oldImeiController = TextEditingController();
  final _oldDeviceNotesController = TextEditingController();
  String _oldDeviceCondition = 'GOOD';
  final _oldDeviceValueController = TextEditingController(text: '0');

  // New Device
  final _newProductNameController = TextEditingController();
  final _newImeiController = TextEditingController();
  final _newDevicePriceController = TextEditingController(text: '0');
  final _additionalDiscountController = TextEditingController(text: '0');

  late ExchangeService _exchangeService;
  String? _userId;

  @override
  void initState() {
    super.initState();
    final db = AppDatabase.instance;
    _exchangeService = ExchangeService(db);
    _userId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _oldDeviceNameController.dispose();
    _oldDeviceBrandController.dispose();
    _oldDeviceModelController.dispose();
    _oldImeiController.dispose();
    _oldDeviceNotesController.dispose();
    _oldDeviceValueController.dispose();
    _newProductNameController.dispose();
    _newImeiController.dispose();
    _newDevicePriceController.dispose();
    _additionalDiscountController.dispose();
    super.dispose();
  }

  Map<String, double> get _calculated {
    final newPrice = double.tryParse(_newDevicePriceController.text) ?? 0;
    final oldValue = double.tryParse(_oldDeviceValueController.text) ?? 0;
    final discount = double.tryParse(_additionalDiscountController.text) ?? 0;
    return Exchange.calculateExchange(
      newDevicePrice: newPrice,
      oldDeviceValue: oldValue,
      additionalDiscount: discount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: BoundedBox(
        maxWidth: 800,
        child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDark),
              _buildProgressIndicator(isDark),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() => _currentStep = index);
                    },
                    children: [
                      _buildCustomerStep(isDark),
                      _buildOldDeviceStep(isDark),
                      _buildNewDeviceStep(isDark),
                      _buildSummaryStep(isDark),
                    ],
                  ),
                ),
              ),
              _buildNavigationButtons(isDark),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.close,
                color: isDark ? Colors.white : Colors.black87,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Exchange',
                  style: TextStyle(
                    fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  _getStepTitle(),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Step 1: Customer Details';
      case 1:
        return 'Step 2: Old Device (Trade-in)';
      case 2:
        return 'Step 3: New Device';
      case 3:
        return 'Step 4: Review & Confirm';
      default:
        return '';
    }
  }

  Widget _buildProgressIndicator(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 4,
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      )
                    : null,
                color: isActive
                    ? null
                    : (isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.08)),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCustomerStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Customer Information',
            Icons.person_outline,
            isDark,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _customerNameController,
            label: 'Customer Name',
            icon: Icons.person,
            isDark: isDark,
            validator: (v) => v?.isEmpty == true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _customerPhoneController,
            label: 'Phone Number',
            icon: Icons.phone,
            isDark: isDark,
            keyboardType: TextInputType.phone,
            validator: (v) => v?.isEmpty == true ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildOldDeviceStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Trade-in Device',
            Icons.phone_android,
            isDark,
            color: Colors.orange,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _oldDeviceNameController,
            label: 'Device Name',
            icon: Icons.smartphone,
            isDark: isDark,
            validator: (v) => v?.isEmpty == true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _oldDeviceBrandController,
                  label: 'Brand',
                  icon: Icons.branding_watermark,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _oldDeviceModelController,
                  label: 'Model',
                  icon: Icons.devices,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _oldImeiController,
            label: 'IMEI / Serial Number',
            icon: Icons.qr_code,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _buildConditionSelector(isDark),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _oldDeviceNotesController,
            label: 'Condition Notes',
            icon: Icons.notes,
            isDark: isDark,
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          _buildPriceField(
            controller: _oldDeviceValueController,
            label: 'Exchange Value (₹)',
            subtitle: 'Value given to customer for old device',
            isDark: isDark,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildConditionSelector(bool isDark) {
    final conditions = ['EXCELLENT', 'GOOD', 'FAIR', 'POOR', 'DAMAGED'];
    final colors = [
      Colors.green,
      Colors.teal,
      Colors.orange,
      Colors.deepOrange,
      Colors.red,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Device Condition',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(conditions.length, (index) {
            final isSelected = _oldDeviceCondition == conditions[index];
            return GestureDetector(
              onTap: () {
                setState(() => _oldDeviceCondition = conditions[index]);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            colors[index],
                            colors[index].withOpacity(0.8),
                          ],
                        )
                      : null,
                  color: isSelected
                      ? null
                      : (isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? colors[index]
                        : (isDark ? Colors.white12 : Colors.black12),
                  ),
                ),
                child: Text(
                  conditions[index],
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildNewDeviceStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'New Device',
            Icons.smartphone,
            isDark,
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _newProductNameController,
            label: 'Product Name',
            icon: Icons.smartphone,
            isDark: isDark,
            validator: (v) => v?.isEmpty == true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _newImeiController,
            label: 'IMEI / Serial Number',
            icon: Icons.qr_code,
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          _buildPriceField(
            controller: _newDevicePriceController,
            label: 'New Device Price (₹)',
            subtitle: 'MRP of the new device',
            isDark: isDark,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          _buildPriceField(
            controller: _additionalDiscountController,
            label: 'Additional Discount (₹)',
            subtitle: 'Extra discount on top of exchange',
            isDark: isDark,
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStep(bool isDark) {
    final calc = _calculated;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Exchange Summary', Icons.receipt_long, isDark),
          const SizedBox(height: 24),
          // Customer Card
          _buildSummaryCard(
            icon: Icons.person,
            title: 'Customer',
            content:
                '${_customerNameController.text}\n${_customerPhoneController.text}',
            color: Colors.blue,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          // Old Device Card
          _buildSummaryCard(
            icon: Icons.phone_android,
            title: 'Trade-in Device',
            content:
                '${_oldDeviceNameController.text}\n${_oldDeviceBrandController.text} ${_oldDeviceModelController.text}\nCondition: $_oldDeviceCondition',
            color: Colors.orange,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          // New Device Card
          _buildSummaryCard(
            icon: Icons.smartphone,
            title: 'New Device',
            content: _newProductNameController.text,
            color: Colors.green,
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          // Calculation Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withOpacity(isDark ? 0.3 : 0.15),
                  const Color(0xFF8B5CF6).withOpacity(isDark ? 0.2 : 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF6366F1).withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                _buildCalcRow(
                  'New Device Price',
                  '₹${_newDevicePriceController.text}',
                  isDark,
                ),
                _buildCalcRow(
                  'Exchange Value',
                  '- ₹${_oldDeviceValueController.text}',
                  isDark,
                  isGreen: true,
                ),
                if ((double.tryParse(_additionalDiscountController.text) ?? 0) >
                    0)
                  _buildCalcRow(
                    'Additional Discount',
                    '- ₹${_additionalDiscountController.text}',
                    isDark,
                    isGreen: true,
                  ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Amount to Pay',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      '₹${calc['amountToPay']?.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: responsiveValue<double>(context, mobile: 22, tablet: 24, desktop: 28),
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalcRow(
    String label,
    String value,
    bool isDark, {
    bool isGreen = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isGreen
                  ? Colors.green
                  : (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    bool isDark, {
    Color color = const Color(0xFF6366F1),
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
        prefixIcon: Icon(icon, color: isDark ? Colors.white38 : Colors.black38),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
        ),
      ),
    );
  }

  Widget _buildPriceField({
    required TextEditingController controller,
    required String label,
    required String subtitle,
    required bool isDark,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
              fontWeight: FontWeight.bold,
              color: color,
            ),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: TextStyle(
                fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
                fontWeight: FontWeight.bold,
                color: color,
              ),
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Back',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _currentStep == 3 ? 'Create Exchange' : 'Continue',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _previousStep() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextStep() {
    if (_currentStep < 3) {
      // Validate current step
      if (_currentStep == 0) {
        if (_customerNameController.text.isEmpty ||
            _customerPhoneController.text.isEmpty) {
          _showError('Please fill in customer details');
          return;
        }
      } else if (_currentStep == 1) {
        if (_oldDeviceNameController.text.isEmpty) {
          _showError('Please enter old device name');
          return;
        }
      } else if (_currentStep == 2) {
        if (_newProductNameController.text.isEmpty) {
          _showError('Please enter new product name');
          return;
        }
      }

      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _createExchange();
    }
  }

  Future<void> _createExchange() async {
    setState(() => _isLoading = true);

    try {
      await _exchangeService.createExchange(
        userId: _userId!,
        customerName: _customerNameController.text,
        customerPhone: _customerPhoneController.text,
        oldDeviceName: _oldDeviceNameController.text,
        oldDeviceBrand: _oldDeviceBrandController.text,
        oldDeviceModel: _oldDeviceModelController.text,
        oldImeiSerial: _oldImeiController.text,
        oldDeviceCondition: _oldDeviceCondition,
        oldDeviceNotes: _oldDeviceNotesController.text,
        oldDeviceValue: double.tryParse(_oldDeviceValueController.text) ?? 0,
        newProductName: _newProductNameController.text,
        newImeiSerial: _newImeiController.text,
        newDevicePrice: double.tryParse(_newDevicePriceController.text) ?? 0,
        additionalDiscount:
            double.tryParse(_additionalDiscountController.text) ?? 0,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Exchange created successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Failed to create exchange: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
