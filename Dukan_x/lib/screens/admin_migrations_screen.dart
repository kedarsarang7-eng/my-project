import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import '../core/di/service_locator.dart';
import '../core/repository/bills_repository.dart';
import '../core/repository/customers_repository.dart';
import '../core/session/session_manager.dart';
// import '../models/customer.dart';

class AdminMigrationsScreen extends StatefulWidget {
  const AdminMigrationsScreen({super.key});

  @override
  State<AdminMigrationsScreen> createState() => _AdminMigrationsScreenState();
}

class _AdminMigrationsScreenState extends State<AdminMigrationsScreen> {
  bool _running = false;
  String _message = '';
  bool _preview = true;
  int _batchSize = 200; // Less relevant for local DB but kept for UI
  Map<String, double>? _previewResult;

  Future<void> _runRecompute({required bool dryRun}) async {
    final ownerId = sl<SessionManager>().ownerId;
    if (ownerId == null) {
      setState(() => _message = 'Error: No active session/owner found.');
      return;
    }

    setState(() {
      _running = true;
      _message = dryRun ? 'Previewing changes...' : 'Running recompute...';
      _previewResult = null;
    });

    try {
      // 1. Fetch all customers
      final customersResult = await sl<CustomersRepository>().getAll(
        userId: ownerId,
      );
      if (!customersResult.isSuccess || customersResult.data == null) {
        throw Exception('Failed to fetch customers: ${customersResult.error}');
      }
      final customers = customersResult.data!;

      // 2. Fetch all bills
      final billsResult = await sl<BillsRepository>().getAll(userId: ownerId);
      if (!billsResult.isSuccess || billsResult.data == null) {
        throw Exception('Failed to fetch bills: ${billsResult.error}');
      }
      final bills = billsResult.data!;

      final updates = <String, double>{};
      final customersToUpdate = <Customer>[];

      int count = 0;

      // 3. Compute Dues
      for (final customer in customers) {
        final customerBills = bills
            .where(
              (b) => b.customerId == customer.id && b.status != 'Cancelled',
            )
            .toList();

        // Calculate expected dues from bills
        double calculatedDues = 0;
        for (final bill in customerBills) {
          calculatedDues += (bill.grandTotal - bill.paidAmount);
        }

        // Determine difference (tolerance for float)
        final diff = (calculatedDues - customer.totalDues).abs();
        if (diff > 1.0) {
          // If difference is more than 1 rupee
          updates['${customer.name} (${customer.phone})'] = calculatedDues;

          if (!dryRun) {
            customersToUpdate.add(customer.copyWith(totalDues: calculatedDues));
          }
        }
        count++;
      }

      if (dryRun) {
        setState(() {
          _previewResult = updates;
          _message =
              'Preview completed. Found ${updates.length} discrepancies out of $count customers.';
        });
      } else {
        // Apply updates
        int updatedCount = 0;
        for (final c in customersToUpdate) {
          await sl<CustomersRepository>().updateCustomer(c, userId: ownerId);
          updatedCount++;
        }

        setState(() {
          _message =
              'Recompute completed successfully. Updated $updatedCount customers.';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Error: $e';
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Migrations'),
        backgroundColor: Colors.green.shade700,
      ),
      body: ResponsiveContainer(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recompute customer dues from bills',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will iterate all bills locally and update each customer\'s `totalDues` to match outstanding amounts. Use this if totals are inconsistent.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _running
                        ? null
                        : () async {
                            await _runRecompute(dryRun: true);
                          },
                    icon: const Icon(Icons.visibility),
                    label: const Text('Preview (dry-run)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _running
                        ? null
                        : () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Confirm recompute'),
                                content: const Text(
                                  'This will overwrite `totalDues` for all customers based on local bills. \n\nEnsure all bills are synced effectively if using multi-device before running this.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Run'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) await _runRecompute(dryRun: false);
                          },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Run recompute'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Scan limit/Batch:'),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    initialValue: _batchSize.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(isDense: true),
                    onChanged: (v) =>
                        setState(() => _batchSize = int.tryParse(v) ?? 200),
                  ),
                ),
                const SizedBox(width: 16),
                const Text('Preview:'),
                Switch(
                  value: _preview,
                  onChanged: (v) => setState(() => _preview = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_running) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(_message),
            const SizedBox(height: 12),
            if (_previewResult != null)
              Expanded(
                child: ListView(
                  children: _previewResult!.entries
                      .take(200)
                      .map(
                        (e) => ListTile(
                          title: Text(e.key),
                          trailing: Text('₹${e.value.toStringAsFixed(2)}'),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    ));
  }
}
