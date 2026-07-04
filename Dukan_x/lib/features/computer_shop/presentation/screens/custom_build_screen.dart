// ============================================================================
// Computer Shop — Custom Build / BOM Checkout Screen
// ============================================================================
// Features:
// - Compose a bill-of-materials (BOM) from available component serials
//   (Computer_Repository.getSerials, filtered to available status)
// - Checkout the build against a non-empty invoice reference
//   (Computer_Repository.checkoutBuild)
// - Show the resulting unit reference on success; retain the BOM/invoice on
//   failure so the staff member can retry without re-entering data
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/computer_job_providers.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Maximum number of components a single build may contain (Req 10.1).
const int _maxBomComponents = 100;

/// Determines whether a serial record returned by
/// `Computer_Repository.getSerials` is available to be added to a build
/// (i.e. not already assigned to another build or unit) — Req 10.2.
///
/// The backend primarily tracks this via a boolean `isSold` flag, but this
/// helper also honors an explicit string `status` field when present (e.g.
/// `'AVAILABLE'` vs `'SOLD'`), matching the status-field convention used
/// elsewhere in this module.
bool isSerialAvailable(Map<String, dynamic> serial) {
  final status = serial['status'];
  if (status is String && status.trim().isNotEmpty) {
    return status.trim().toUpperCase() == 'AVAILABLE';
  }
  return serial['isSold'] != true;
}

class CustomBuildScreen extends ConsumerStatefulWidget {
  const CustomBuildScreen({super.key});

  @override
  ConsumerState<CustomBuildScreen> createState() => _CustomBuildScreenState();
}

class _CustomBuildScreenState extends ConsumerState<CustomBuildScreen> {
  final _invoiceController = TextEditingController();

  /// The bill-of-materials being assembled. Each entry carries the fields
  /// required by `checkoutBuild` (productId, serialNumber) plus the serial
  /// record id (for de-duplication) and a display label.
  final List<Map<String, dynamic>> _bom = [];

  bool _isFetchingSerials = false;
  String? _addComponentError;

  @override
  void dispose() {
    _invoiceController.dispose();
    super.dispose();
  }

  Set<String> get _addedSerialIds =>
      _bom.map((c) => c['serialId'] as String).toSet();

  Future<void> _addComponent() async {
    if (_bom.length >= _maxBomComponents) {
      setState(
        () => _addComponentError =
            'Build limit reached: a maximum of $_maxBomComponents components '
            'is allowed.',
      );
      return;
    }

    setState(() {
      _isFetchingSerials = true;
      _addComponentError = null;
    });

    List<Map<String, dynamic>> serials;
    try {
      final repository = ref.read(computerRepositoryProvider);
      serials = await repository.getSerials();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFetchingSerials = false;
        _addComponentError = 'Failed to load serials: $e';
      });
      return;
    }

    if (!mounted) return;

    // Only available serials not already in the BOM are selectable (Req 10.2).
    final addedIds = _addedSerialIds;
    final available = serials.where((s) {
      final id = s['id']?.toString() ?? '';
      return isSerialAvailable(s) && !addedIds.contains(id);
    }).toList();

    setState(() => _isFetchingSerials = false);

    // Zero available serials — block adding and show indication (Req 10.3).
    if (available.isEmpty) {
      setState(
        () => _addComponentError =
            'No serials available. Nothing can be added to this build right now.',
      );
      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AvailableSerialsSheet(serials: available),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _addComponentError = null;
      _bom.add({
        'serialId': selected['id']?.toString() ?? '',
        'productId': selected['productId']?.toString() ?? '',
        'serialNumber': selected['serialNumber']?.toString() ?? '',
      });
    });
  }

  void _removeComponent(String serialId) {
    setState(() => _bom.removeWhere((c) => c['serialId'] == serialId));
  }

  Future<void> _checkout() async {
    final invoiceRef = _invoiceController.text.trim();

    // Precondition: BOM must have 1-100 components and a non-empty invoice
    // reference, or no repository call is made (Req 10.4, Property 12).
    if (_bom.isEmpty || _bom.length > _maxBomComponents || invoiceRef.isEmpty) {
      final missing = <String>[];
      if (_bom.isEmpty) missing.add('at least one component');
      if (invoiceRef.isEmpty) missing.add('an invoice reference');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Missing required input: ${missing.join(' and ')}.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final components = _bom
        .map(
          (c) => {
            'productId': c['productId'],
            'serialNumber': c['serialNumber'],
          },
        )
        .toList();

    await ref
        .read(buildCheckoutProvider.notifier)
        .checkout(components: components, invoiceId: invoiceRef);
  }

  void _startNewBuild() {
    setState(() {
      _bom.clear();
      _invoiceController.clear();
      _addComponentError = null;
    });
    ref.read(buildCheckoutProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final checkoutState = ref.watch(buildCheckoutProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Custom Build',
              style: TextStyle(
                fontSize: responsiveValue<double>(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              'Assemble Components & Checkout',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Checkout failure — surface returned error and retain BOM +
              // invoice reference unchanged (Req 10.6).
              if (checkoutState.error != null)
                _ErrorBanner(error: checkoutState.error!),

              // Checkout success — show confirmation with the unit reference
              // (Req 10.5).
              if (checkoutState.success && checkoutState.error == null)
                _BuildSuccessCard(
                  unitReference: checkoutState.unitReference ?? '',
                  onStartNewBuild: _startNewBuild,
                ),

              if ((checkoutState.error != null) ||
                  (checkoutState.success && checkoutState.error == null))
                const SizedBox(height: 24),

              _BomCard(
                bom: _bom,
                isFetchingSerials: _isFetchingSerials,
                addComponentError: _addComponentError,
                onAddComponent: _addComponent,
                onRemoveComponent: _removeComponent,
                maxComponents: _maxBomComponents,
              ),
              const SizedBox(height: 24),

              _CheckoutCard(
                invoiceController: _invoiceController,
                isLoading: checkoutState.isLoading,
                onCheckout: _checkout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Error Banner
// ============================================================================

class _ErrorBanner extends StatelessWidget {
  final String error;

  const _ErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: TextStyle(fontSize: 14, color: Colors.red.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Build Success Card
// ============================================================================

class _BuildSuccessCard extends StatelessWidget {
  final String unitReference;
  final VoidCallback onStartNewBuild;

  const _BuildSuccessCard({
    required this.unitReference,
    required this.onStartNewBuild,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.shade200, width: 2),
      ),
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.check_circle, size: 48, color: Colors.green.shade600),
            const SizedBox(height: 12),
            Text(
              'Build Checked Out Successfully',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade800,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              'Unit Reference: $unitReference',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onStartNewBuild,
              icon: const Icon(Icons.add),
              label: const Text('Start New Build'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BOM Card
// ============================================================================

class _BomCard extends StatelessWidget {
  final List<Map<String, dynamic>> bom;
  final bool isFetchingSerials;
  final String? addComponentError;
  final VoidCallback onAddComponent;
  final ValueChanged<String> onRemoveComponent;
  final int maxComponents;

  const _BomCard({
    required this.bom,
    required this.isFetchingSerials,
    required this.addComponentError,
    required this.onAddComponent,
    required this.onRemoveComponent,
    required this.maxComponents,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.memory,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bill of Materials',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '${bom.length} / $maxComponents',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (bom.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No components added yet. Tap "Add Component" to select an '
                  'available serial.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: bom.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final component = bom[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.developer_board),
                    title: Text(
                      component['serialNumber']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Product: ${component['productId']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      tooltip: 'Remove component',
                      onPressed: () =>
                          onRemoveComponent(component['serialId'] as String),
                    ),
                  );
                },
              ),

            if (addComponentError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        addComponentError!,
                        style: TextStyle(color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: isFetchingSerials ? null : onAddComponent,
                icon: isFetchingSerials
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(
                  isFetchingSerials ? 'Loading serials...' : 'Add Component',
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
// Checkout Card
// ============================================================================

class _CheckoutCard extends StatelessWidget {
  final TextEditingController invoiceController;
  final bool isLoading;
  final VoidCallback onCheckout;

  const _CheckoutCard({
    required this.invoiceController,
    required this.isLoading,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.point_of_sale,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Checkout',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            TextField(
              controller: invoiceController,
              decoration: InputDecoration(
                labelText: 'Invoice Reference *',
                hintText: 'Enter the invoice identifier for this build',
                prefixIcon: const Icon(Icons.receipt_long),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : onCheckout,
                icon: isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(isLoading ? 'Checking out...' : 'Checkout Build'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
}

// ============================================================================
// Available Serials Bottom Sheet
// ============================================================================

/// Lists the available serials passed in by the caller (already filtered to
/// available status and excluding serials already in the BOM). Tapping an
/// item returns it to the caller via `Navigator.pop`.
class _AvailableSerialsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> serials;

  const _AvailableSerialsSheet({required this.serials});

  @override
  State<_AvailableSerialsSheet> createState() => _AvailableSerialsSheetState();
}

class _AvailableSerialsSheetState extends State<_AvailableSerialsSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.serials
        : widget.serials.where((s) {
            final serialNumber = (s['serialNumber']?.toString() ?? '')
                .toLowerCase();
            final productId = (s['productId']?.toString() ?? '').toLowerCase();
            return serialNumber.contains(query) || productId.contains(query);
          }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Available Serial',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Only components not yet assigned to a build are shown',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    labelText: 'Search',
                    hintText: 'Serial number or product id',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No matching serials',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final serial = filtered[index];
                            return ListTile(
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.developer_board,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              title: Text(
                                serial['serialNumber']?.toString() ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Product: ${serial['productId']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => Navigator.of(context).pop(serial),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
