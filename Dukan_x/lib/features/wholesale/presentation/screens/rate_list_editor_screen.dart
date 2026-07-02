import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../../core/database/app_database.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../data/wholesale_repository.dart';
import '../../domain/paise_money.dart';
import '../../domain/rate_list.dart';

/// Rate-list editor screen for the wholesale vertical.
///
/// Lists existing rate lists for products, allows creating/editing rate lists
/// with quantity slabs (minQty, maxQty, unitPaise), optionally party-specific
/// (select a customer) or generic (no party).
///
/// Persists via [WholesaleRepository.saveRateList].
///
/// (§4, §15; Requirement 11.7)
class RateListEditorScreen extends StatefulWidget {
  const RateListEditorScreen({super.key});

  @override
  State<RateListEditorScreen> createState() => _RateListEditorScreenState();
}

class _RateListEditorScreenState extends State<RateListEditorScreen> {
  final WholesaleRepository _repository = WholesaleRepositoryImpl();
  final AppDatabase _db = sl<AppDatabase>();

  List<RateList> _rateLists = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRateLists();
  }

  Future<void> _loadRateLists() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final lists = await _repository.getAllRateLists();
      setState(() {
        _rateLists = lists;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load rate lists: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createOrEditRateList([RateList? existing]) async {
    final result = await Navigator.push<RateList>(
      context,
      MaterialPageRoute(
        builder: (_) => _RateListFormScreen(
          repository: _repository,
          db: _db,
          existing: existing,
        ),
      ),
    );

    if (result != null) {
      _loadRateLists();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Lists & Pricing Tiers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRateLists,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createOrEditRateList(),
        icon: const Icon(Icons.add),
        label: const Text('New Rate List'),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadRateLists,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_rateLists.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.price_change_outlined, size: 48, color: theme.hintColor),
            const SizedBox(height: 16),
            Text(
              'No rate lists configured',
              style: TextStyle(color: theme.hintColor, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Create rate lists to set tiered pricing for your products.',
              style: TextStyle(color: theme.hintColor, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _rateLists.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final rateList = _rateLists[index];
        final isPartySpecific = rateList.partyId != null;

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPartySpecific
                  ? theme.colorScheme.tertiary.withOpacity(0.1)
                  : theme.colorScheme.primary.withOpacity(0.1),
              child: Icon(
                isPartySpecific
                    ? Icons.person_outline
                    : Icons.inventory_2_outlined,
                color: isPartySpecific
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.primary,
              ),
            ),
            title: Text(
              'Product: ${rateList.productId}',
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPartySpecific
                      ? 'Party-specific (${rateList.partyId})'
                      : 'Generic (all parties)',
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
                const SizedBox(height: 4),
                Text(
                  '${rateList.slabs.length} slab${rateList.slabs.length == 1 ? '' : 's'}: '
                  '${_slabsSummary(rateList.slabs)}',
                  style: TextStyle(fontSize: 11, color: theme.hintColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _createOrEditRateList(rateList),
              tooltip: 'Edit rate list',
            ),
            onTap: () => _createOrEditRateList(rateList),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  String _slabsSummary(List<PricingSlab> slabs) {
    return slabs
        .map((s) {
          final range = s.maxQty != null
              ? '${s.minQty}–${s.maxQty}'
              : '${s.minQty}+';
          return '$range @ ${PaiseMoney.formatRupees(s.unitPaise)}';
        })
        .join(', ');
  }
}

/// Internal form screen for creating/editing a single rate list.
class _RateListFormScreen extends StatefulWidget {
  final WholesaleRepository repository;
  final AppDatabase db;
  final RateList? existing;

  const _RateListFormScreen({
    required this.repository,
    required this.db,
    this.existing,
  });

  @override
  State<_RateListFormScreen> createState() => _RateListFormScreenState();
}

class _RateListFormScreenState extends State<_RateListFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productIdController = TextEditingController();
  final _partyIdController = TextEditingController();

  bool _isPartySpecific = false;
  List<_SlabFormData> _slabs = [];
  bool _isSaving = false;

  // Product/customer picker data.
  List<_PickerItem> _products = [];
  List<_PickerItem> _customers = [];

  @override
  void initState() {
    super.initState();
    _loadPickerData();

    if (widget.existing != null) {
      _productIdController.text = widget.existing!.productId;
      _isPartySpecific = widget.existing!.partyId != null;
      _partyIdController.text = widget.existing!.partyId ?? '';
      _slabs = widget.existing!.slabs
          .map(
            (s) => _SlabFormData(
              minQtyController: TextEditingController(
                text: s.minQty.toString(),
              ),
              maxQtyController: TextEditingController(
                text: s.maxQty?.toString() ?? '',
              ),
              unitPaiseController: TextEditingController(
                text: (s.unitPaise ~/ 100).toString(),
              ),
            ),
          )
          .toList();
    }

    // Always have at least one slab row.
    if (_slabs.isEmpty) {
      _addSlab();
    }
  }

  Future<void> _loadPickerData() async {
    try {
      final session = sl<SessionManager>();
      final tenantId = session.currentBusinessId ?? session.userId;
      if (tenantId == null || tenantId.isEmpty) return;

      final productResults = await widget.db
          .customSelect(
            'SELECT id, name FROM products '
            'WHERE user_id = ? AND is_active = 1 '
            'ORDER BY name ASC LIMIT 200',
            variables: [Variable<String>(tenantId)],
          )
          .get();

      final customerResults = await widget.db
          .customSelect(
            'SELECT id, name FROM customers '
            'WHERE user_id = ? AND is_active = 1 '
            'ORDER BY name ASC LIMIT 200',
            variables: [Variable<String>(tenantId)],
          )
          .get();

      if (mounted) {
        setState(() {
          _products = productResults
              .map(
                (r) => _PickerItem(
                  id: r.read<String>('id'),
                  name: r.read<String>('name'),
                ),
              )
              .toList();
          _customers = customerResults
              .map(
                (r) => _PickerItem(
                  id: r.read<String>('id'),
                  name: r.read<String>('name'),
                ),
              )
              .toList();
        });
      }
    } catch (_) {
      // Non-critical — picker data is optional UI convenience.
    }
  }

  void _addSlab() {
    setState(() {
      _slabs.add(
        _SlabFormData(
          minQtyController: TextEditingController(),
          maxQtyController: TextEditingController(),
          unitPaiseController: TextEditingController(),
        ),
      );
    });
  }

  void _removeSlab(int index) {
    setState(() {
      _slabs[index].dispose();
      _slabs.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_slabs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one pricing slab'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final slabs = _slabs.map((s) {
        final minQty = int.parse(s.minQtyController.text.trim());
        final maxQtyText = s.maxQtyController.text.trim();
        final maxQty = maxQtyText.isEmpty ? null : int.parse(maxQtyText);
        // User enters rate in rupees; we store in paise.
        final unitRupees = int.parse(s.unitPaiseController.text.trim());
        final unitPaise = unitRupees * 100;
        return PricingSlab(
          minQty: minQty,
          maxQty: maxQty,
          unitPaise: unitPaise,
        );
      }).toList();

      final rateList = RateList(
        id: widget.existing?.id ?? '',
        tenantId: '', // Will be resolved by repository.
        partyId: _isPartySpecific ? _partyIdController.text.trim() : null,
        productId: _productIdController.text.trim(),
        slabs: slabs,
        createdAt: DateTime.now(),
      );

      final saved = await widget.repository.saveRateList(rateList);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existing != null
                  ? 'Rate list updated'
                  : 'Rate list created',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, saved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _productIdController.dispose();
    _partyIdController.dispose();
    for (final slab in _slabs) {
      slab.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Rate List' : 'New Rate List'),
        actions: [
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Product selection.
            _buildProductField(theme),
            const SizedBox(height: 16),

            // Party-specific toggle.
            SwitchListTile(
              title: const Text('Party-specific rate list'),
              subtitle: const Text(
                'When enabled, this rate list applies only to the selected customer',
              ),
              value: _isPartySpecific,
              onChanged: (val) => setState(() => _isPartySpecific = val),
            ),
            if (_isPartySpecific) ...[
              const SizedBox(height: 8),
              _buildCustomerField(theme),
            ],
            const SizedBox(height: 24),

            // Slabs section.
            Row(
              children: [
                Text('Pricing Slabs', style: theme.textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addSlab,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Slab'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._slabs.asMap().entries.map((entry) {
              return _buildSlabRow(entry.key, entry.value, theme);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildProductField(ThemeData theme) {
    return Autocomplete<_PickerItem>(
      displayStringForOption: (item) => item.name,
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return _products;
        final query = textEditingValue.text.toLowerCase();
        return _products.where((p) => p.name.toLowerCase().contains(query));
      },
      onSelected: (item) {
        _productIdController.text = item.id;
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        // Seed the autocomplete controller with the product name if editing.
        if (widget.existing != null && controller.text.isEmpty) {
          final match = _products.where(
            (p) => p.id == widget.existing!.productId,
          );
          if (match.isNotEmpty) {
            controller.text = match.first.name;
          } else {
            controller.text = widget.existing!.productId;
          }
        }
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Product',
            hintText: 'Search or select a product',
            prefixIcon: Icon(Icons.inventory_2_outlined),
            border: OutlineInputBorder(),
          ),
          validator: (val) {
            if (_productIdController.text.trim().isEmpty &&
                (val == null || val.trim().isEmpty)) {
              return 'Product is required';
            }
            return null;
          },
          onChanged: (val) {
            // If user types directly (no autocomplete), use as product ID.
            final match = _products.where(
              (p) => p.name.toLowerCase() == val.toLowerCase(),
            );
            if (match.isNotEmpty) {
              _productIdController.text = match.first.id;
            } else {
              _productIdController.text = val.trim();
            }
          },
        );
      },
    );
  }

  Widget _buildCustomerField(ThemeData theme) {
    return Autocomplete<_PickerItem>(
      displayStringForOption: (item) => item.name,
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return _customers;
        final query = textEditingValue.text.toLowerCase();
        return _customers.where((c) => c.name.toLowerCase().contains(query));
      },
      onSelected: (item) {
        _partyIdController.text = item.id;
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        if (widget.existing?.partyId != null && controller.text.isEmpty) {
          final match = _customers.where(
            (c) => c.id == widget.existing!.partyId,
          );
          if (match.isNotEmpty) {
            controller.text = match.first.name;
          } else {
            controller.text = widget.existing!.partyId!;
          }
        }
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Customer',
            hintText: 'Search or select a customer',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
          ),
          validator: (val) {
            if (_isPartySpecific &&
                _partyIdController.text.trim().isEmpty &&
                (val == null || val.trim().isEmpty)) {
              return 'Customer is required for party-specific lists';
            }
            return null;
          },
          onChanged: (val) {
            final match = _customers.where(
              (c) => c.name.toLowerCase() == val.toLowerCase(),
            );
            if (match.isNotEmpty) {
              _partyIdController.text = match.first.id;
            } else {
              _partyIdController.text = val.trim();
            }
          },
        );
      },
    );
  }

  Widget _buildSlabRow(int index, _SlabFormData slab, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Slab ${index + 1}', style: theme.textTheme.labelLarge),
                  const Spacer(),
                  if (_slabs.length > 1)
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: () => _removeSlab(index),
                      tooltip: 'Remove slab',
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: slab.minQtyController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Min Qty',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Required';
                        }
                        final n = int.tryParse(val.trim());
                        if (n == null || n < 1) return 'Must be ≥ 1';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: slab.maxQtyController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Max Qty',
                        hintText: 'Empty = no limit',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      // maxQty is optional — null means unlimited.
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: slab.unitPaiseController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Rate (₹)',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Required';
                        }
                        final n = int.tryParse(val.trim());
                        if (n == null || n < 0) return 'Must be ≥ 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Internal model for slab form fields.
class _SlabFormData {
  final TextEditingController minQtyController;
  final TextEditingController maxQtyController;
  final TextEditingController unitPaiseController;

  _SlabFormData({
    required this.minQtyController,
    required this.maxQtyController,
    required this.unitPaiseController,
  });

  void dispose() {
    minQtyController.dispose();
    maxQtyController.dispose();
    unitPaiseController.dispose();
  }
}

/// Internal model for product/customer picker items.
class _PickerItem {
  final String id;
  final String name;

  const _PickerItem({required this.id, required this.name});
}
