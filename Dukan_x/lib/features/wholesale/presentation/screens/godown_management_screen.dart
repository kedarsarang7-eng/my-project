import 'package:flutter/material.dart';

import '../../data/wholesale_repository.dart';
import '../../domain/warehouse.dart';

/// Screen for managing godowns (warehouses) for the current tenant.
///
/// Lists existing warehouses and allows adding new ones via
/// [WholesaleRepository.saveWarehouse].
///
/// Wired into the sidebar via the `godowns` item id in
/// `sidebar_navigation_handler.dart` (Phase 7, §2; Requirement 10.2, 10.5).
class GodownManagementScreen extends StatefulWidget {
  const GodownManagementScreen({super.key});

  @override
  State<GodownManagementScreen> createState() => _GodownManagementScreenState();
}

class _GodownManagementScreenState extends State<GodownManagementScreen> {
  late final WholesaleRepository _repository;
  List<Warehouse> _warehouses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = WholesaleRepositoryImpl();
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final warehouses = await _repository.getWarehousesForTenant();
      if (mounted) {
        setState(() {
          _warehouses = warehouses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addWarehouse() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Godown'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Godown Name',
            hintText: 'e.g. Main Warehouse, Cold Storage',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(nameController.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (name == null || name.trim().isEmpty) return;

    try {
      // Create a placeholder Warehouse (id/tenantId/createdAt assigned by repo)
      final placeholder = Warehouse(
        id: '',
        tenantId: '',
        name: name.trim(),
        createdAt: DateTime.now(),
      );
      await _repository.saveWarehouse(placeholder);
      await _loadWarehouses();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Godown "${name.trim()}" added'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add godown: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Godown Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWarehouses,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addWarehouse,
        icon: const Icon(Icons.add),
        label: const Text('Add Godown'),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Failed to load godowns', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadWarehouses,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_warehouses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warehouse_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text('No godowns configured', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Add your first godown to start tracking\nstock by location.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _addWarehouse,
              icon: const Icon(Icons.add),
              label: const Text('Add Godown'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _warehouses.length,
      itemBuilder: (context, index) {
        final warehouse = _warehouses[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.warehouse_outlined,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text(warehouse.name),
            subtitle: Text(
              'Created: ${_formatDate(warehouse.createdAt)}',
              style: theme.textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
