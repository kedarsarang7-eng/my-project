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
import 'package:dukanx/core/responsive/responsive.dart';
import '../../providers/computer_job_providers.dart';
import '../../data/repositories/computer_repository.dart';
import '../../utils/computer_shop_validators.dart';
import '../widgets/product_search_bottom_sheet.dart';

/// Number of tabs rendered by [MultiUnitScreen].
const _kMultiUnitTabCount = 2;

class MultiUnitScreen extends ConsumerStatefulWidget {
  const MultiUnitScreen({super.key});

  @override
  ConsumerState<MultiUnitScreen> createState() => _MultiUnitScreenState();
}

class _MultiUnitScreenState extends ConsumerState<MultiUnitScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Multi-Unit Configuration',
              style: TextStyle(
                fontSize: responsiveValue<double>(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              'Box/Pcs Conversion Setup',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: DefaultTabController(
        length: _kMultiUnitTabCount,
        child: BoundedBox(
          maxWidth: 800,
          child: Builder(
            builder: (context) {
              // Verify the TabController is correctly resolved and its length
              // matches the expected tab count. If not, show an inline error
              // instead of crashing (Req 1.7).
              final TabController? controller = DefaultTabController.maybeOf(
                context,
              );
              if (controller == null ||
                  controller.length != _kMultiUnitTabCount) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tab Controller Error',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Unable to initialize the tab interface. '
                          'Please try reopening this screen.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  // Tab Bar
                  Container(
                    color: Theme.of(context).colorScheme.surface,
                    child: TabBar(
                      onTap: (index) => setState(() => _selectedTab = index),
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      labelColor: Theme.of(context).colorScheme.primary,
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
              );
            },
          ),
        ),
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
  final _formKey = GlobalKey<FormState>();
  String _primaryUnit = 'pcs';
  String _alternateUnit = 'box';
  final _conversionRateController = TextEditingController();
  bool _isLoading = false;

  // Picker state for product selection (Req 22.1, 22.2).
  String? _selectedProductId;
  String? _selectedProductLabel;

  final List<String> _unitOptions = ['pcs', 'box', 'set', 'bundle'];

  void _openProductPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) => ProductSearchBottomSheet(
          jobId: '',
          onProductSelected: (productId, productName, _, __) {
            setState(() {
              _selectedProductId = productId;
              _selectedProductLabel = productName;
            });
            Navigator.of(ctx).pop();
          },
        ),
      ),
    );
  }

  Future<void> _saveConfiguration() async {
    // Validate that a product is selected via picker (Req 22.1, 22.6).
    if (_selectedProductId == null || _selectedProductId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a product using the picker'),
        ),
      );
      return;
    }

    // Validate that primary ≠ alternate (Req 21.1)
    final unitPairError = ComputerShopValidators.validateUnitPair(
      _primaryUnit,
      _alternateUnit,
    );
    if (unitPairError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(unitPairError)));
      return;
    }

    // Validate conversion rate via form field validator (Req 21.3, 21.4)
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final rate = double.tryParse(_conversionRateController.text.trim());
    if (rate == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref
          .read(multiUnitConfigProvider.notifier)
          .configureMultiUnit(
            MultiUnitConfig(
              productId: _selectedProductId!,
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
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
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
                side: BorderSide(
                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                ),
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
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF3B82F6),
                        ),
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Product — Picker (Req 22.1, 22.2, 22.3)
                    _MultiUnitPickerTile(
                      label: 'Product *',
                      icon: Icons.inventory_2,
                      selectedLabel: _selectedProductLabel,
                      placeholder: 'Select Product',
                      onTap: () => _openProductPicker(),
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
                            onChanged: (v) =>
                                setState(() => _alternateUnit = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Conversion Rate
                    TextFormField(
                      controller: _conversionRateController,
                      keyboardType: TextInputType.number,
                      validator: ComputerShopValidators.validateConversionRate,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
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
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
  final _quantityController = TextEditingController();
  String _fromUnit = 'box';
  String _toUnit = 'pcs';

  // Picker state for product selection (Req 22.1, 22.2).
  String? _selectedProductId;
  String? _selectedProductLabel;

  final List<String> _unitOptions = ['pcs', 'box', 'set', 'bundle'];

  void _openProductPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) => ProductSearchBottomSheet(
          jobId: '',
          onProductSelected: (productId, productName, _, __) {
            setState(() {
              _selectedProductId = productId;
              _selectedProductLabel = productName;
            });
            Navigator.of(ctx).pop();
          },
        ),
      ),
    );
  }

  Future<void> _convert() async {
    if (_selectedProductId == null || _selectedProductId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a product using the picker'),
        ),
      );
      return;
    }

    if (_quantityController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a quantity')));
      return;
    }

    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid quantity')));
      return;
    }

    // Validate that source ≠ target (Req 21.2)
    final conversionPairError = ComputerShopValidators.validateConversionPair(
      _fromUnit,
      _toUnit,
    );
    if (conversionPairError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(conversionPairError)));
      return;
    }

    try {
      await ref
          .read(multiUnitConfigProvider.notifier)
          .convertUnit(
            productId: _selectedProductId!,
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

                  // Product — Picker (Req 22.1, 22.2, 22.3)
                  _MultiUnitPickerTile(
                    label: 'Product',
                    icon: Icons.inventory_2,
                    selectedLabel: _selectedProductLabel,
                    placeholder: 'Select Product',
                    onTap: () => _openProductPicker(),
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
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
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
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
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

// ============================================================================
// Shared Picker Tile Widget (Multi-Unit Screen)
// ============================================================================

/// A tappable tile that displays a selected item label or a placeholder,
/// styled to match the form field appearance. Used to replace raw UUID text
/// fields with picker-based selection (Req 22.2).
class _MultiUnitPickerTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? selectedLabel;
  final String placeholder;
  final VoidCallback onTap;

  const _MultiUnitPickerTile({
    required this.label,
    required this.icon,
    required this.selectedLabel,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedLabel != null && selectedLabel!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          hasSelection ? selectedLabel! : placeholder,
          style: TextStyle(
            fontSize: 16,
            color: hasSelection
                ? Theme.of(context).colorScheme.onSurface
                : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}
