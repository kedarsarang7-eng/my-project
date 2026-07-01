import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import 'farmer_ledger_screen.dart';

/// Farmer Ledger entry point — lists all farmers for the current tenant,
/// allowing the user to select one to view their detailed ledger.
///
/// This is the sidebar navigation target for the `mandi_farmer_ledger` item.
/// Once a farmer is selected, it navigates to [FarmerLedgerScreen] with the
/// chosen farmer's ID.
///
/// Requirements: 12.2 (open corresponding screen within 1 second, no legacy
/// redirect).
class FarmerLedgerEntryScreen extends StatefulWidget {
  const FarmerLedgerEntryScreen({super.key});

  @override
  State<FarmerLedgerEntryScreen> createState() =>
      _FarmerLedgerEntryScreenState();
}

class _FarmerLedgerEntryScreenState extends State<FarmerLedgerEntryScreen> {
  late final AppDatabase _db;
  late final SessionManager _session;
  String? _selectedFarmerId;

  @override
  void initState() {
    super.initState();
    _db = sl<AppDatabase>();
    _session = sl<SessionManager>();
  }

  Stream<List<FarmerEntity>> _watchFarmers() {
    return (_db.select(_db.farmers)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // If a farmer is selected, show the detail ledger screen.
    if (_selectedFarmerId != null) {
      return FarmerLedgerScreen(
        key: ValueKey(_selectedFarmerId),
        farmerId: _selectedFarmerId!,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Farmer Ledger', style: theme.textTheme.titleLarge),
      ),
      body: StreamBuilder<List<FarmerEntity>>(
        stream: _watchFarmers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final farmers = snapshot.data ?? [];

          if (farmers.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No farmers found',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add farmers to view their ledger',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: farmers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final farmer = farmers[index];
              return _buildFarmerTile(farmer, theme);
            },
          );
        },
      ),
    );
  }

  Widget _buildFarmerTile(FarmerEntity farmer, ThemeData theme) {
    final balance = farmer.currentBalance;
    final isPayable = balance >= 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          farmer.name.isNotEmpty ? farmer.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        farmer.name,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        isPayable ? 'Payable' : 'Advance',
        style: theme.textTheme.bodySmall?.copyWith(
          color: isPayable
              ? theme.colorScheme.primary
              : theme.colorScheme.error,
        ),
      ),
      trailing: Text(
        '₹${balance.abs().toStringAsFixed(2)}',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: isPayable
              ? theme.colorScheme.primary
              : theme.colorScheme.error,
        ),
      ),
      onTap: () {
        setState(() {
          _selectedFarmerId = farmer.id;
        });
      },
    );
  }
}
