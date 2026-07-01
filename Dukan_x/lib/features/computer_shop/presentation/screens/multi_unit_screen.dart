// ============================================================================
// Computer Shop — Multi-Unit Configuration Screen
// ============================================================================
// Configure Box/Pcs conversions for products
// - Set primary and alternate units
// - Define conversion rates
// - Calculate conversions in real-time
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/computer_job_providers.dart';
import '../../data/repositories/computer_repository.dart';

class MultiUnitScreen extends ConsumerStatefulWidget {
  const MultiUnitScreen({super.key});

  @override
  ConsumerState<MultiUnitScreen> createState() => _MultiUnitScreenState();
}

class _MultiUnitScreenState extends ConsumerState<MultiUnitScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Multi-Unit Configuration',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            Text(
              'Box/Pcs Conversion Setup',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              onTap: (index) => setState(() => _selectedTab = index),
              indicatorColor: const Color(0xFF3B82F6),
              labelColor: const Color(0xFF3B82F6),
              unselectedLabelColor: Colors.grey.shade600,
              tabs: const [
                Tab(text: 'Configure', icon: Icon(Icons.settings)),
                Tab(text: 'Converter', icon: Icon(Icons.calculate)),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: const [_ConfigureTab(), _ConverterTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Configure Tab
// ============================================================================

class _ConfigureTab extends ConsumerStatefulWidget {
  const _ConfigureTab();

  @override
  ConsumerState<_ConfigureTab> createState() => _ConfigureTabState();
}

class _ConfigureTabState extends ConsumerState<_ConfigureTab> {
  final _productIdController = TextEditingController();
  String _primaryUnit = 'pcs';
  String _alternateUnit = 'box';
  final _conversionRateController = TextEditingController();
  bool _isLoading = false;

  final List<String> _unitOptions = ['pcs', 'box', 'set', 'bundle'];

  Future<void> _saveConfiguration() async {
    if (_productIdController.text.isEmpty ||
        _conversionRateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    final rate = double.tryParse(_conversionRateController.text);
    if (rate == null || rate <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid conversion rate')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref
          .read(multiUnitConfigProvider.notifier)
          .configureMultiUnit(
            MultiUnitConfig(
              productId: _productIdController.text.trim(),
              primaryUnit: _primaryUnit,
              alternateUnit: _alternateUnit,
              conversionRate: rate,
            ),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Configuration saved successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info Card
          Card(
            elevation: 0,
            color: const Color(0xFFEBF5FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: const Color(0xFF3B82F6).withOpacity(0.3)),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF3B82F6)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Configure how products are sold in different units. Example: 1 Box = 10 Pcs',
                      style: TextStyle(fontSize: 14, color: Color(0xFF3B82F6)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Configuration Form
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Unit Configuration',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 24),

                  // Product ID
                  TextField(
                    controller: _productIdController,
                    decoration: InputDecoration(
                      labelText: 'Product ID *',
                      hintText: 'Enter product UUID',
                      prefixIcon: const Icon(Icons.inventory_2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Units Row
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _primaryUnit,
                          decoration: InputDecoration(
                            labelText: 'Primary Unit *',
                            prefixIcon: const Icon(Icons.straighten),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: _unitOptions.map((unit) {
                            return DropdownMenuItem(
                              value: unit,
                              child: Text(unit.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _primaryUnit = v!),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.arrow_forward, color: Colors.grey),
                      ),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _alternateUnit,
                          decoration: InputDecoration(
                            labelText: 'Alternate Unit *',
                            prefixIcon: const Icon(Icons.swap_horiz),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: _unitOptions.map((unit) {
                            return DropdownMenuItem(
                              value: unit,
                              child: Text(unit.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _alternateUnit = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Conversion Rate
                  TextField(
                    controller: _conversionRateController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Conversion Rate *',
                      hintText: 'e.g., 10 (1 Box = 10 Pcs)',
                      prefixIcon: const Icon(Icons.calculate),
                      suffixText: '$_alternateUnit = 1 $_primaryUnit',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Example Text
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Example: If 1 Box contains 10 individual items, enter "10"',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Save Button
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveConfiguration,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Saving...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save),
                        SizedBox(width: 8),
                        Text(
                          'Save Configuration',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
}

// ============================================================================
// Converter Tab
// ============================================================================

class _ConverterTab extends ConsumerStatefulWidget {
  const _ConverterTab();

  @override
  ConsumerState<_ConverterTab> createState() => _ConverterTabState();
}

class _ConverterTabState extends ConsumerState<_ConverterTab> {
  final _productIdController = TextEditingController();
  final _quantityController = TextEditingController();
  String _fromUnit = 'box';
  String _toUnit = 'pcs';

  final List<String> _unitOptions = ['pcs', 'box', 'set', 'bundle'];

  Future<void> _convert() async {
    if (_productIdController.text.isEmpty || _quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter product ID and quantity')),
      );
      return;
    }

    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid quantity')));
      return;
    }

    try {
      await ref
          .read(multiUnitConfigProvider.notifier)
          .convertUnit(
            productId: _productIdController.text.trim(),
            fromUnit: _fromUnit,
            toUnit: _toUnit,
            quantity: quantity,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversion failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final multiUnitState = ref.watch(multiUnitConfigProvider);
    final conversion = multiUnitState.lastConversion;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Converter Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calculate, color: Color(0xFF3B82F6)),
                      SizedBox(width: 8),
                      Text(
                        'Unit Converter',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Product ID
                  TextField(
                    controller: _productIdController,
                    decoration: InputDecoration(
                      labelText: 'Product ID',
                      hintText: 'Enter product UUID',
                      prefixIcon: const Icon(Icons.inventory_2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quantity
                  TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      hintText: 'Enter quantity to convert',
                      prefixIcon: const Icon(Icons.format_list_numbered),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // From/To Units
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _fromUnit,
                          decoration: InputDecoration(
                            labelText: 'From',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: _unitOptions.map((unit) {
                            return DropdownMenuItem(
                              value: unit,
                              child: Text(unit.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _fromUnit = v!),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          Icons.arrow_forward,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _toUnit,
                          decoration: InputDecoration(
                            labelText: 'To',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: _unitOptions.map((unit) {
                            return DropdownMenuItem(
                              value: unit,
                              child: Text(unit.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _toUnit = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Convert Button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: multiUnitState.isLoading ? null : _convert,
                      icon: multiUnitState.isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.swap_horiz),
                      label: Text(
                        multiUnitState.isLoading ? 'Converting...' : 'Convert',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
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
          const SizedBox(height: 24),

          // Result Card
          if (conversion != null)
            Card(
              elevation: 0,
              color: const Color(0xFFDCFCE7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: const Color(0xFF22C55E).withOpacity(0.3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF22C55E),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      conversion.productName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Text(
                              '${conversion.from['quantity']}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              conversion.from['unit'].toString().toUpperCase(),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Icon(
                            Icons.arrow_forward,
                            size: 32,
                            color: Color(0xFF22C55E),
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              '${conversion.to['quantity'].toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF22C55E),
                              ),
                            ),
                            Text(
                              conversion.to['unit'].toString().toUpperCase(),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Rate: 1 ${conversion.from['unit'].toString().toUpperCase()} = ${conversion.conversionRate} ${conversion.to['unit'].toString().toUpperCase()}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
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
}
