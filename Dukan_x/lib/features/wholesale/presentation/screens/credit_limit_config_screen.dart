import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../../core/database/app_database.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../data/wholesale_repository.dart';
import '../../domain/paise_money.dart';

/// Credit-limit configuration screen for the wholesale vertical.
///
/// Lists customers and their current credit limits, allows editing the
/// credit limit per customer, and persists via
/// [WholesaleRepository.saveCreditLimit].
///
/// Gated behind `useCreditLimit` capability (§4, §5; Requirement 9.6).
/// All credit-limit values are stored in the existing `creditLimit`
/// RealColumn (float, rupees). The [CreditLimitEvaluator] converts to
/// paise internally: `limitPaise = (creditLimit * 100).round()`.
class CreditLimitConfigScreen extends StatefulWidget {
  const CreditLimitConfigScreen({super.key});

  @override
  State<CreditLimitConfigScreen> createState() =>
      _CreditLimitConfigScreenState();
}

class _CreditLimitConfigScreenState extends State<CreditLimitConfigScreen> {
  final WholesaleRepository _repository = WholesaleRepositoryImpl();
  final AppDatabase _db = sl<AppDatabase>();

  List<_CustomerCreditRow> _customers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = sl<SessionManager>();
      final tenantId = session.currentBusinessId ?? session.userId;
      if (tenantId == null || tenantId.isEmpty) {
        setState(() {
          _error = 'Unable to resolve tenant. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      // Query customers for this tenant with their credit limits.
      final results = await _db
          .customSelect(
            'SELECT id, name, credit_limit, total_dues FROM customers '
            'WHERE user_id = ? AND is_active = 1 '
            'ORDER BY name ASC',
            variables: [Variable<String>(tenantId)],
          )
          .get();

      final rows = results.map((row) {
        final creditLimitRupees = row.read<double>('credit_limit');
        return _CustomerCreditRow(
          id: row.read<String>('id'),
          name: row.read<String>('name'),
          creditLimitPaise: (creditLimitRupees * 100).round(),
          outstandingPaise: (row.read<double>('total_dues') * 100).round(),
        );
      }).toList();

      setState(() {
        _customers = rows;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load customers: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _editCreditLimit(_CustomerCreditRow customer) async {
    final controller = TextEditingController(
      text: customer.creditLimitPaise > 0
          ? (customer.creditLimitPaise ~/ 100).toString()
          : '',
    );

    final result = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Credit Limit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              customer.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Outstanding: ${PaiseMoney.formatRupees(customer.outstandingPaise)}',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Credit Limit (₹)',
                hintText: '0 = no limit',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter 0 or leave empty to remove the credit limit.',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              final rupees = int.tryParse(text) ?? 0;
              final paise = rupees * 100;
              Navigator.pop(context, paise);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return; // User cancelled.

    try {
      await _repository.saveCreditLimit(customer.id, result);
      _loadCustomers(); // Refresh the list.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result > 0
                  ? 'Credit limit set to ${PaiseMoney.formatRupees(result)} for ${customer.name}'
                  : 'Credit limit removed for ${customer.name}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Limit Configuration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCustomers,
            tooltip: 'Refresh',
          ),
        ],
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
                onPressed: _loadCustomers,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 48, color: theme.hintColor),
            const SizedBox(height: 16),
            Text(
              'No customers found',
              style: TextStyle(color: theme.hintColor, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Add customers to configure their credit limits.',
              style: TextStyle(color: theme.hintColor, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _customers.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final customer = _customers[index];
        final hasLimit = customer.creditLimitPaise > 0;
        final utilizationPercent = hasLimit && customer.outstandingPaise > 0
            ? (customer.outstandingPaise / customer.creditLimitPaise * 100)
                  .clamp(0.0, 999.0)
            : 0.0;
        final isNearLimit = utilizationPercent >= 80;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isNearLimit
                ? theme.colorScheme.error.withOpacity(0.1)
                : theme.colorScheme.primary.withOpacity(0.1),
            child: Icon(
              Icons.person_outline,
              color: isNearLimit
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
          ),
          title: Text(
            customer.name,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            hasLimit
                ? 'Limit: ${PaiseMoney.formatRupees(customer.creditLimitPaise)} • '
                      'Outstanding: ${PaiseMoney.formatRupees(customer.outstandingPaise)} '
                      '(${utilizationPercent.toStringAsFixed(0)}%)'
                : 'No limit set • '
                      'Outstanding: ${PaiseMoney.formatRupees(customer.outstandingPaise)}',
            style: TextStyle(
              fontSize: 12,
              color: isNearLimit ? theme.colorScheme.error : theme.hintColor,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasLimit)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isNearLimit
                        ? theme.colorScheme.error.withOpacity(0.1)
                        : theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    PaiseMoney.formatRupees(customer.creditLimitPaise),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isNearLimit
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _editCreditLimit(customer),
                tooltip: 'Edit credit limit',
              ),
            ],
          ),
          onTap: () => _editCreditLimit(customer),
        );
      },
    );
  }
}

/// Internal model for the credit-limit list.
class _CustomerCreditRow {
  final String id;
  final String name;
  final int creditLimitPaise;
  final int outstandingPaise;

  const _CustomerCreditRow({
    required this.id,
    required this.name,
    required this.creditLimitPaise,
    required this.outstandingPaise,
  });
}
