// Old Gold Exchange Screen - PML Act Compliance
// Full KYC capture for legal compliance

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/customers_repository.dart';
import '../../data/models/jewellery_product_model.dart';
import '../../data/repositories/jewellery_repository_offline.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class OldGoldExchangeScreen extends StatefulWidget {
  const OldGoldExchangeScreen({super.key});

  @override
  State<OldGoldExchangeScreen> createState() => _OldGoldExchangeScreenState();
}

class _OldGoldExchangeScreenState extends State<OldGoldExchangeScreen> {
  final JewelleryRepositoryOffline _repository = JewelleryRepositoryOffline(
    sl(),
    sl<SessionManager>(),
  );

  // Form state
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  // Customer info
  Customer? _selectedCustomer;
  final _customerIdTypeController = TextEditingController();
  final _customerIdNumberController = TextEditingController();

  // Old gold details
  MetalType _selectedMetalType = MetalType.gold22k;
  final _weightController = TextEditingController();
  final _purityPercentageController = TextEditingController();
  String _purityTestMethod = 'XRF';

  // Exchange calculation
  final _goldRateController = TextEditingController();
  final _exchangeValueController = TextEditingController();
  final _cashAdjustmentController = TextEditingController();
  final _notesController = TextEditingController();

  // New item (optional)
  final _newItemDescriptionController = TextEditingController();
  MetalType? _newItemMetalType;
  final _newItemWeightController = TextEditingController();
  final _newItemPriceController = TextEditingController();

  // Calculated values
  double _calculatedValue = 0;
  double _actualPurity = 91.6; // Default for 22K

  final List<String> _idTypes = ['AADHAAR', 'PAN', 'PASSPORT', 'VOTER_ID'];
  final List<String> _testMethods = ['XRF', 'ACID', 'TOUCHSTONE', 'VISUAL'];

  @override
  void initState() {
    super.initState();
    _loadTodayRate();
    _weightController.addListener(_calculateValue);
    _goldRateController.addListener(_calculateValue);
    _purityPercentageController.addListener(_calculateValue);
  }

  @override
  void dispose() {
    _customerIdTypeController.dispose();
    _customerIdNumberController.dispose();
    _weightController.dispose();
    _purityPercentageController.dispose();
    _goldRateController.dispose();
    _exchangeValueController.dispose();
    _cashAdjustmentController.dispose();
    _notesController.dispose();
    _newItemDescriptionController.dispose();
    _newItemWeightController.dispose();
    _newItemPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadTodayRate() async {
    await _repository.initialize();
    final rate = await _repository.getTodayGoldRate();
    if (rate != null) {
      setState(() {
        _goldRateController.text = rate
            .getGoldRatePerGram(_selectedMetalType)
            .toString();
      });
    }
  }

  void _calculateValue() {
    final weight = double.tryParse(_weightController.text) ?? 0;
    final rate = double.tryParse(_goldRateController.text) ?? 0;
    final purity =
        double.tryParse(_purityPercentageController.text) ?? _actualPurity;

    // Calculate: weight * rate * (purity/100)
    final value = weight * rate * (purity / 100);

    setState(() {
      _calculatedValue = value;
      _exchangeValueController.text = value.toStringAsFixed(2);
    });
  }

  void _updateMetalType(MetalType type) {
    setState(() {
      _selectedMetalType = type;
      _actualPurity = type.purityPercentage;
      _purityPercentageController.text = _actualPurity.toStringAsFixed(1);
    });
    _loadTodayRate();
  }

  Future<void> _saveExchange() async {
    // Validate required fields
    if (_selectedCustomer == null) {
      _showError('Please select a customer');
      return;
    }

    if (_customerIdTypeController.text.isEmpty ||
        _customerIdNumberController.text.isEmpty) {
      _showError('Customer ID proof is required for PML Act compliance');
      return;
    }

    final weight = double.tryParse(_weightController.text);
    if (weight == null || weight <= 0) {
      _showError('Please enter a valid weight');
      return;
    }

    final rate = double.tryParse(_goldRateController.text);
    if (rate == null || rate <= 0) {
      _showError('Please enter a valid gold rate');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final exchangeValue = double.tryParse(_exchangeValueController.text) ?? 0;
      final cashAdjustment =
          double.tryParse(_cashAdjustmentController.text) ?? 0;

      await _repository.createOldGoldExchange(
        customerId: _selectedCustomer!.id,
        customerName: _selectedCustomer!.name,
        customerPhone: _selectedCustomer!.phone,
        customerIdType: _customerIdTypeController.text,
        customerIdNumber: _customerIdNumberController.text,
        oldGoldMetalType: _selectedMetalType,
        oldGoldWeightGrams: weight,
        oldGoldRatePerGramPaisa: (rate * 100).round(),
        oldGoldValuePaisa: (exchangeValue * 100).round(),
        purityTestMethod: _purityTestMethod,
        actualPurityPercentage: double.tryParse(
          _purityPercentageController.text,
        ),
        newItemDescription: _newItemDescriptionController.text.isNotEmpty
            ? _newItemDescriptionController.text
            : null,
        newItemMetalType: _newItemMetalType,
        newItemWeightGrams: double.tryParse(_newItemWeightController.text),
        newItemTotalPaisa: double.tryParse(_newItemPriceController.text) != null
            ? (double.parse(_newItemPriceController.text) * 100).round()
            : null,
        exchangeValuePaisa: (exchangeValue * 100).round(),
        cashAdjustmentPaisa: (cashAdjustment * 100).round(),
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Old gold exchange recorded successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Failed to save exchange: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Old Gold Exchange'),
        backgroundColor: const Color(0xFFD4AF37),
        foregroundColor: Colors.white,
        actions: [
          // PML Act compliance badge
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user,
                  size: 16,
                  color: Colors.white.withOpacity(0.9),
                ),
                const SizedBox(width: 6),
                Text(
                  'PML Act Compliant',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Stepper(
          type: context.isMobile
              ? StepperType.vertical
              : StepperType.horizontal,
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 3) {
              setState(() => _currentStep++);
            } else {
              _saveExchange();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            }
          },
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _isSaving ? null : details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: _isSaving && _currentStep == 3
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(_currentStep == 3 ? 'SAVE EXCHANGE' : 'NEXT'),
                  ),
                  const SizedBox(width: 12),
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('BACK'),
                    ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Customer KYC'),
              content: _buildKYCStep(),
              isActive: _currentStep >= 0,
            ),
            Step(
              title: const Text('Gold Details'),
              content: _buildGoldDetailsStep(),
              isActive: _currentStep >= 1,
            ),
            Step(
              title: const Text('Valuation'),
              content: _buildValuationStep(),
              isActive: _currentStep >= 2,
            ),
            Step(
              title: const Text('Exchange'),
              content: _buildExchangeStep(),
              isActive: _currentStep >= 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKYCStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PML Act warning
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'PML Act (Prevention of Money Laundering Act) requires recording customer ID for all gold transactions exceeding specified limits.',
                      style: TextStyle(fontSize: 13, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Customer selection
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Select Customer'),
              subtitle: _selectedCustomer != null
                  ? Text(
                      '${_selectedCustomer!.name} - ${_selectedCustomer!.phone ?? 'No phone'}',
                    )
                  : const Text('Required for compliance'),
              trailing: ElevatedButton.icon(
                onPressed: () async {
                  // Navigate to customer selection
                  final customer = await Navigator.push<Customer>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomerSearchScreen(),
                    ),
                  );
                  if (customer != null) {
                    setState(() => _selectedCustomer = customer);
                  }
                },
                icon: const Icon(Icons.search),
                label: Text(_selectedCustomer != null ? 'CHANGE' : 'SELECT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const Divider(),
            const SizedBox(height: 16),

            // ID Type
            DropdownButtonFormField<String>(
              value: _customerIdTypeController.text.isNotEmpty
                  ? _customerIdTypeController.text
                  : null,
              decoration: InputDecoration(
                labelText: 'ID Type *',
                hintText: 'Select ID type',
                prefixIcon: const Icon(Icons.badge),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
              ),
              items: _idTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _customerIdTypeController.text = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // ID Number
            TextField(
              controller: _customerIdNumberController,
              decoration: InputDecoration(
                labelText: 'ID Number *',
                hintText: 'Enter ID number',
                prefixIcon: const Icon(Icons.numbers),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),

            // Document upload placeholder
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.grey),
              ),
              title: const Text('Customer Photo'),
              subtitle: const Text('Optional but recommended'),
              trailing: TextButton(
                onPressed: () {
                  // Image picker would go here
                },
                child: const Text('CAPTURE'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoldDetailsStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Metal Type',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children:
                  [
                    MetalType.gold24k,
                    MetalType.gold22k,
                    MetalType.gold18k,
                    MetalType.gold14k,
                    MetalType.silver,
                    MetalType.platinum,
                  ].map((type) {
                    final isSelected = _selectedMetalType == type;
                    return ChoiceChip(
                      label: Text(type.displayName),
                      selected: isSelected,
                      onSelected: (_) => _updateMetalType(type),
                      selectedColor: const Color(0xFFD4AF37),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : null,
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 24),

            // Weight
            TextField(
              controller: _weightController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: InputDecoration(
                labelText: 'Weight (grams) *',
                hintText: 'e.g., 10.5',
                prefixIcon: const Icon(Icons.scale),
                suffixText: 'g',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),

            // Purity Test Method
            DropdownButtonFormField<String>(
              value: _purityTestMethod,
              decoration: InputDecoration(
                labelText: 'Purity Test Method',
                prefixIcon: const Icon(Icons.science),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
              ),
              items: _testMethods.map((method) {
                return DropdownMenuItem(value: method, child: Text(method));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _purityTestMethod = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Actual purity percentage
            TextField(
              controller: _purityPercentageController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: InputDecoration(
                labelText: 'Actual Purity (%)',
                hintText: _actualPurity.toStringAsFixed(1),
                prefixIcon: const Icon(Icons.percent),
                suffixText: '%',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes',
                hintText: 'Any additional details about the old gold',
                prefixIcon: const Icon(Icons.notes),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValuationStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gold Rate',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _goldRateController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Rate per Gram (₹) *',
                hintText: 'Current market rate',
                prefixIcon: const Icon(Icons.currency_rupee),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFFD4AF37)),
                  onPressed: _loadTodayRate,
                  tooltip: 'Load today\'s rate',
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
              ),
            ),
            const SizedBox(height: 24),

            // Calculation summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFD4AF37).withOpacity(0.1),
                    const Color(0xFFD4AF37).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  _buildCalculationRow('Weight', '${_weightController.text} g'),
                  _buildCalculationRow(
                    'Rate',
                    '₹${_goldRateController.text}/g',
                  ),
                  _buildCalculationRow(
                    'Purity',
                    '${_purityPercentageController.text}%',
                  ),
                  const Divider(height: 24),
                  _buildCalculationRow(
                    'Exchange Value',
                    '₹${_calculatedValue.toStringAsFixed(2)}',
                    isBold: true,
                    valueColor: const Color(0xFFD4AF37),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExchangeStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exchange Details',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Exchange value (editable)
            TextField(
              controller: _exchangeValueController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Exchange Value (₹)',
                prefixIcon: const Icon(Icons.currency_exchange),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),

            // Cash adjustment
            TextField(
              controller: _cashAdjustmentController,
              keyboardType: TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: 'Cash Adjustment (₹)',
                hintText: 'Positive = customer pays, Negative = store pays',
                prefixIcon: const Icon(Icons.payments),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
              ),
            ),
            const SizedBox(height: 24),

            // New item (optional exchange)
            Text(
              'New Item (Optional)',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newItemDescriptionController,
              decoration: InputDecoration(
                labelText: 'Item Description',
                hintText: 'e.g., 22K Gold Ring with diamond',
                prefixIcon: const Icon(Icons.diamond),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
              ),
            ),
            const SizedBox(height: 12),
            ...context.isMobile
                ? [
                    DropdownButtonFormField<MetalType>(
                      value: _newItemMetalType,
                      decoration: InputDecoration(
                        labelText: 'Metal',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                      ),
                      items: MetalType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _newItemMetalType = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newItemWeightController,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Weight (g)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newItemPriceController,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Price (₹)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                      ),
                    ),
                  ]
                : [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<MetalType>(
                            value: _newItemMetalType,
                            decoration: InputDecoration(
                              labelText: 'Metal',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[50],
                            ),
                            items: MetalType.values.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type.displayName),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _newItemMetalType = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _newItemWeightController,
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Weight (g)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[50],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _newItemPriceController,
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Price (₹)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[50],
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

  Widget _buildCalculationRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: isBold ? 18 : 14,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

// Fully functional customer search and creation screen for KYC/compliance
class CustomerSearchScreen extends StatefulWidget {
  const CustomerSearchScreen({super.key});

  @override
  State<CustomerSearchScreen> createState() => _CustomerSearchScreenState();
}

class _CustomerSearchScreenState extends State<CustomerSearchScreen> {
  final CustomersRepository _customersRepo = sl<CustomersRepository>();
  final SessionManager _sessionManager = sl<SessionManager>();

  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];
  bool _isLoading = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _searchController.addListener(_filterCustomers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final ownerId = _sessionManager.userId;
      final result = await _customersRepo.getAll(userId: ownerId);
      if (result.success && result.data != null) {
        setState(() {
          _allCustomers = result.data!;
          _filteredCustomers = result.data!;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading customers: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterCustomers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = _allCustomers;
      } else {
        _filteredCustomers = _allCustomers.where((c) {
          final nameMatch = c.name.toLowerCase().contains(query);
          final phoneMatch = c.phone != null && c.phone!.contains(query);
          return nameMatch || phoneMatch;
        }).toList();
      }
    });
  }

  Future<void> _createNewCustomer() async {
    // Prefill name with search text if not a number
    final query = _searchController.text.trim();
    final isNum = RegExp(r'^\d+$').hasMatch(query);
    if (isNum) {
      _phoneController.text = query;
      _nameController.clear();
    } else {
      _nameController.text = query;
      _phoneController.clear();
    }
    _addressController.clear();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Customer'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: _isCreating
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      setDialogState(() => _isCreating = true);
                      try {
                        final ownerId = _sessionManager.userId ?? 'system';
                        final result = await _customersRepo.createCustomer(
                          userId: ownerId,
                          name: _nameController.text.trim(),
                          phone: _phoneController.text.trim(),
                          address: _addressController.text.trim(),
                        );
                        if (result.success && result.data != null) {
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(
                            context,
                            result.data,
                          ); // Return customer to exchange screen
                        } else {
                          throw Exception(
                            result.errorMessage ?? 'Failed to save customer',
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        setDialogState(() => _isCreating = false);
                      }
                    },
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('CREATE & SELECT'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Customer'),
        backgroundColor: const Color(0xFFD4AF37),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by Name or Phone',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredCustomers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'No customers found',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _createNewCustomer,
                            icon: const Icon(Icons.add),
                            label: const Text('Add New Customer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = _filteredCustomers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(
                                0xFFD4AF37,
                              ).withOpacity(0.2),
                              child: Text(
                                customer.name.isNotEmpty
                                    ? customer.name[0].toUpperCase()
                                    : 'C',
                                style: const TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              customer.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Phone: ${customer.phone}\nAddress: ${customer.address}',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pop(context, customer),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
