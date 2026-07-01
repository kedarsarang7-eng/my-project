import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/app_database.dart';
import '../../../core/di/service_locator.dart';
import '../../../providers/app_state_providers.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:dukanx/core/responsive/responsive.dart';

class CommissionLedgerScreen extends ConsumerStatefulWidget {
  const CommissionLedgerScreen({super.key});

  @override
  ConsumerState<CommissionLedgerScreen> createState() =>
      _CommissionLedgerScreenState();
}

class _CommissionLedgerScreenState
    extends ConsumerState<CommissionLedgerScreen> {
  final _db = sl<AppDatabase>();
  Stream<List<CommissionLedgerEntity>>? _stream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    final userId = ref.read(authStateProvider).userId;
    if (userId != null) {
      _stream =
          (_db.select(_db.commissionLedger)
                ..where((t) => t.userId.equals(userId))
                ..orderBy([(t) => OrderingTerm.desc(t.date)]))
              .watch();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_stream == null) {
      return const Center(child: Text("Please login"));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Commission Ledger")),
      body: StreamBuilder<List<CommissionLedgerEntity>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          if (data.isEmpty) {
            return const Center(child: Text("No commission records found"));
          }

          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: const Icon(
                      Icons.currency_rupee,
                      color: Colors.green,
                    ),
                  ),
                  title: Text(
                    "Sale: ₹${(item.saleAmount / 100).toStringAsFixed(0)}",
                  ),
                  subtitle: Text(
                    "Date: ${DateFormat('dd MMM yyyy').format(item.date)}\nFarmer ID: ${item.farmerId.substring(0, 5)}...",
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "+ ₹${(item.commissionAmount / 100).toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Comm (${item.commissionRate}%)",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
