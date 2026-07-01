// Making Charges Calculator Screen
// Feature 2: Flexible Jewellery Pricing Calculation

import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../data/models/making_charges_model.dart';
import '../../data/services/making_charges_calculator.dart';
import '../../data/repositories/making_charges_repository.dart';
import '../../utils/jewellery_business_rules.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class MakingChargesCalculatorScreen extends StatefulWidget {
  const MakingChargesCalculatorScreen({super.key});

  @override
  State<MakingChargesCalculatorScreen> createState() =>
      _MakingChargesCalculatorScreenState();
}

class _MakingChargesCalculatorScreenState
    extends State<MakingChargesCalculatorScreen> {
  final MakingChargesRepository _repository = MakingChargesRepository(
    sl(),
    sl<SessionManager>(),
  );

  List<MakingChargesConfig> _configs = [];
  MakingChargesConfig? _selectedConfig;
  bool _isLoading = true;
  String? _error;

  // Calculation inputs
  final _weightController = TextEditingController();
  final _rateController = TextEditingController();
  final _stoneWeightController = TextEditingController();
  final _stoneRateController = TextEditingController();
  final _wastageController = TextEditingController();
  JewelleryComplexity _selectedComplexity = JewelleryComplexity.medium;
  GoldPurity _selectedPurity = GoldPurity.k22;

  MakingChargeResult? _calculationResult;
  Map<String, dynamic>? _totalPriceBreakdown;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _rateController.dispose();
    _stoneWeightController.dispose();
    _stoneRateController.dispose();
    _wastageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _repository.initialize();
      final configs = await _repository.getActiveConfigs();

      setState(() {
        _configs = configs;
        if (configs.isNotEmpty) {
          _selectedConfig = configs.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load configurations: $e';
        _isLoading = false;
      });
    }
  }

  void _calculate() {
    if (_selectedConfig == null) return;

    final weight = double.tryParse(_weightController.text);
    final rate = double.tryParse(_rateController.text);

    if (weight == null || weight <= 0 || rate == null || rate <= 0) {
      _showError('Please enter valid weight and rate');
      return;
    }

    final stoneWeight = double.tryParse(_stoneWeightController.text);
    final stoneRate = double.tryParse(_stoneRateController.text);
    final wastage = double.tryParse(_wastageController.text);

    try {
      // Calculate making charges
      final request = CalculateMakingChargesRequest(
        config: _selectedConfig!,
        metalWeightGrams: weight,
        metalRatePaisaPerGram: (rate * 100).round(),
        stoneWeightGrams: stoneWeight,
        stoneRatePaisa: stoneRate != null ? (stoneRate * 100).round() : null,
        wastagePercent: wastage,
        complexity: _selectedConfig!.type == MakingChargeType.complexity
            ? _selectedComplexity
            : null,
      );

      final result = MakingChargesCalculator.calculate(request);

      // Check for validation errors (Requirement 15.2)
      if (result.isError) {
        _showError(result.errorMessage ?? 'Invalid input');
        return;
      }

      // Calculate total price
      final breakdown = MakingChargesCalculator.calculateTotalPrice(
        metalWeightGrams: weight,
        metalRatePaisaPerGram: (rate * 100).round(),
        makingChargesConfig: _selectedConfig!,
        purity: _selectedPurity,
        stoneWeightGrams: stoneWeight,
        stoneRatePaisaPerGram: stoneRate != null
            ? (stoneRate * 100).round()
            : null,
        wastagePercent: wastage,
        complexity: _selectedComplexity,
      );

      // Check for validation errors from calculateTotalPrice (Requirement 15.2)
      if (breakdown['isError'] == true) {
        _showError(breakdown['errorMessage'] as String? ?? 'Invalid input');
        return;
      }

      setState(() {
        _calculationResult = result;
        _totalPriceBreakdown = breakdown;
      });
    } catch (e) {
      _showError('Calculation error: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      // R9.2: this screen is registered as a standalone GoRoute
      // (/jewellery/making-charges) and pushed full-screen, so it must expose
      // its own back affordance. The leading button is shown only when the
      // route can actually pop (a no-op safe `maybePop`).
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: const Text('Making Charges Calculator'),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildErrorWidget()
            : _buildMainContent(),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: Colors.red[700])),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final isDesktop = context.isDesktop;

    if (isDesktop) {
      return Row(
        children: [
          // Left panel - Configuration & Inputs
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(
                responsiveValue<double>(
                  context,
                  mobile: 16,
                  tablet: 20,
                  desktop: 24,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildConfigSelector(),
                  const SizedBox(height: 20),
                  _buildCalculationInputs(),
                ],
              ),
            ),
          ),
          // Right panel - Results
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(20),
              child: _calculationResult != null
                  ? _buildResultsPanel()
                  : _buildEmptyResults(),
            ),
          ),
        ],
      );
    }

    // Mobile/tablet: single-column scrollable layout
    return SingleChildScrollView(
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildConfigSelector(),
          const SizedBox(height: 20),
          _buildCalculationInputs(),
          if (_calculationResult != null) ...[
            const SizedBox(height: 20),
            _buildResultsPanel(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFD4AF37),
                    const Color(0xFFD4AF37).withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calculate, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Making Charges Calculator',
                    style: TextStyle(
                      fontSize: responsiveValue<double>(
                        context,
                        mobile: 18,
                        tablet: 20,
                        desktop: 22,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Flexible pricing calculation for jewellery',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfigSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Configuration',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MakingChargesConfig>(
              value: _selectedConfig,
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
              ),
              items: _configs.map((config) {
                return DropdownMenuItem(
                  value: config,
                  child: Text('${config.name} (${config.type.displayName})'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedConfig = value;
                  _calculationResult = null;
                  _totalPriceBreakdown = null;
                });
              },
            ),
            if (_selectedConfig != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedConfig!.description ?? '',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    _buildConfigDetailRow(
                      'Type',
                      _selectedConfig!.type.displayName,
                    ),
                    if (_selectedConfig!.displayRatePerGram != null)
                      _buildConfigDetailRow(
                        'Rate',
                        '₹${_selectedConfig!.displayRatePerGram}/g',
                      ),
                    if (_selectedConfig!.displayMinimumCharge != null)
                      _buildConfigDetailRow(
                        'Min Charge',
                        '₹${_selectedConfig!.displayMinimumCharge}',
                      ),
                    if (_selectedConfig!.displayMaximumCharge != null)
                      _buildConfigDetailRow(
                        'Max Charge',
                        '₹${_selectedConfig!.displayMaximumCharge}',
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfigDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationInputs() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product Details',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            // Metal Weight & Rate
            ..._buildResponsiveFieldPair(
              isDark: isDark,
              first: TextField(
                controller: _weightController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Metal Weight (g) *',
                  prefixIcon: const Icon(Icons.scale),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                ),
              ),
              second: TextField(
                controller: _rateController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Gold Rate (₹/g) *',
                  prefixIcon: const Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Stone Weight & Rate (Optional)
            ..._buildResponsiveFieldPair(
              isDark: isDark,
              first: TextField(
                controller: _stoneWeightController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Stone Weight (g)',
                  prefixIcon: const Icon(Icons.diamond),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                ),
              ),
              second: TextField(
                controller: _stoneRateController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Stone Rate (₹/g)',
                  prefixIcon: const Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Wastage
            TextField(
              controller: _wastageController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Wastage (%)',
                prefixIcon: const Icon(Icons.percent),
                hintText: 'e.g., 8',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
              ),
            ),
            const SizedBox(height: 12),

            // Complexity (only for complexity-based configs)
            if (_selectedConfig?.type == MakingChargeType.complexity)
              DropdownButtonFormField<JewelleryComplexity>(
                value: _selectedComplexity,
                decoration: InputDecoration(
                  labelText: 'Complexity Level',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                ),
                items: JewelleryComplexity.values.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c.displayName));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedComplexity = value);
                  }
                },
              ),

            const SizedBox(height: 20),

            // Calculate Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate),
                label: const Text('CALCULATE PRICE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsPanel() {
    if (_totalPriceBreakdown == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildTotalPriceCard(),
          const SizedBox(height: 16),
          _buildBreakdownCard(),
          if (_calculationResult?.steps.isNotEmpty ?? false) ...[
            const SizedBox(height: 16),
            _buildCalculationStepsCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalPriceCard() {
    final total = _totalPriceBreakdown!['totalDisplay'] as double;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFD4AF37),
              const Color(0xFFD4AF37).withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: EdgeInsets.all(
          responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
        ),
        child: Column(
          children: [
            const Text(
              'TOTAL PRICE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '₹${total.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Includes 3% GST',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownCard() {
    final breakdown = _totalPriceBreakdown!;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Price Breakdown',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Divider(height: 24),
            _buildBreakdownRow(
              'Metal Value',
              breakdown['metalValueDisplay'] as double,
            ),
            if (breakdown['wastageValueDisplay'] as double > 0)
              _buildBreakdownRow(
                'Wastage',
                breakdown['wastageValueDisplay'] as double,
              ),
            _buildBreakdownRow(
              'Making Charges',
              breakdown['makingChargesDisplay'] as double,
            ),
            if (breakdown['stoneValueDisplay'] as double > 0)
              _buildBreakdownRow(
                'Stone Value',
                breakdown['stoneValueDisplay'] as double,
              ),
            const Divider(height: 24),
            _buildBreakdownRow(
              'Subtotal',
              breakdown['subtotalDisplay'] as double,
            ),
            _buildBreakdownRow(
              'GST (${breakdown['gstPercent']}%)',
              breakdown['gstDisplay'] as double,
            ),
            const Divider(height: 24),
            _buildBreakdownRow(
              'TOTAL',
              breakdown['totalDisplay'] as double,
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
          Text(
            '₹${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isBold ? 18 : 14,
              color: isBold ? const Color(0xFFD4AF37) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationStepsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calculation Steps',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ..._calculationResult!.steps.map((step) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.description,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${step.formula} = ₹${(step.resultPaisa / 100).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calculate_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Enter product details to calculate',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Fill in weight and gold rate, then click Calculate',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// Returns a responsive pair of fields: side-by-side on desktop/tablet,
  /// stacked vertically on mobile to prevent overflow.
  List<Widget> _buildResponsiveFieldPair({
    required bool isDark,
    required Widget first,
    required Widget second,
  }) {
    if (context.isMobile) {
      return [first, const SizedBox(height: 12), second];
    }
    return [
      Row(
        children: [
          Expanded(child: first),
          const SizedBox(width: 12),
          Expanded(child: second),
        ],
      ),
    ];
  }
}
