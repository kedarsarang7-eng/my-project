import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/di/service_locator.dart';
import '../core/repository/udhar_repository.dart';
import '../providers/app_state_providers.dart';

class UdharTab extends ConsumerWidget {
  final String customerId;

  const UdharTab({required this.customerId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeStateProvider);
    final palette = theme.palette;
    final isDark = theme.isDark;

    return Container(
      color: isDark ? const Color(0xFF0F172A) : palette.offWhite,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Credit Tracker',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : palette.mutedGray,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddPerson(context),
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  label: const Text(
                    'Add Person',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.royalBlue,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<UdharPerson>>(
              stream: sl<UdharRepository>().watchPeople(userId: customerId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final people = snap.data ?? [];
                if (people.isEmpty) {
                  return Center(
                    child: Text(
                      'No udhar entries yet',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : palette.darkGray,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: people.length,
                  itemBuilder: (context, index) {
                    final p = people[index];
                    final balance = p.balance;
                    final subtitle = balance == 0
                        ? 'Settled'
                        : (balance > 0
                              ? 'You will receive ₹${balance.toStringAsFixed(0)}'
                              : 'You will pay ₹${(balance.abs()).toStringAsFixed(0)}');

                    final isPositive = balance > 0;
                    final color = balance == 0
                        ? palette.darkGray
                        : (isPositive ? palette.leafGreen : palette.tomatoRed);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      elevation: isDark ? 0 : 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.1),
                          child: Text(
                            p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                            style: TextStyle(color: color),
                          ),
                        ),
                        title: Text(
                          p.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : palette.mutedGray,
                          ),
                        ),
                        subtitle: Text(
                          subtitle,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!p.isSynced)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Icon(
                                  Icons.sync,
                                  size: 16,
                                  color: isDark ? Colors.white54 : Colors.grey,
                                ),
                              ),
                            IconButton(
                              icon: Icon(
                                Icons.history,
                                color: isDark
                                    ? Colors.white70
                                    : palette.darkGray,
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UdharDetailScreen(
                                    customerId: customerId,
                                    personId: p.id,
                                    personName: p.name,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete,
                                color: palette.tomatoRed,
                              ),
                              onPressed: () => _confirmDelete(context, p),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPerson(BuildContext context) {
    final nameCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    // Dialog theme handling is usually global, but we can verify later
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Person'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                hintText: 'Name',
                labelText: 'Name',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                hintText: 'Note (Optional)',
                labelText: 'Note',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              await sl<UdharRepository>().createPerson(
                userId: customerId,
                name: name,
                note: noteCtrl.text.trim(),
              );
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, UdharPerson p) {
    // Assuming context has ThemeProvider logic from parent
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Person?"),
        content: Text(
          "Delete ${p.name} and all associated transactions? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await sl<UdharRepository>().deletePerson(
                userId: customerId,
                personId: p.id,
              );
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class UdharDetailScreen extends ConsumerWidget {
  final String customerId;
  final String personId;
  final String personName;

  const UdharDetailScreen({
    required this.customerId,
    required this.personId,
    required this.personName,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeStateProvider);
    final palette = theme.palette;
    final isDark = theme.isDark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          personName,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      ),
      backgroundColor: isDark ? const Color(0xFF0F172A) : palette.offWhite,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransaction(context),
        backgroundColor: palette.royalBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<UdharTransaction>>(
        stream: sl<UdharRepository>().watchTransactions(personId: personId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final txs = snap.data ?? [];
          if (txs.isEmpty) {
            return Center(
              child: Text(
                'No transactions yet',
                style: TextStyle(
                  color: isDark ? Colors.white54 : palette.darkGray,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: txs.length,
            itemBuilder: (context, index) {
              final t = txs[index];
              // final amount = (t['amount'] ?? 0).toDouble();
              // final type = (t['type'] ?? 'given') as String;

              final isGiven = t.type == 'given';
              final color = isGiven ? palette.leafGreen : palette.tomatoRed;

              return ListTile(
                leading: Icon(
                  isGiven ? Icons.arrow_outward : Icons.arrow_downward,
                  color: color,
                ),
                title: Text(
                  '${isGiven ? 'I Gave' : 'I Took'} ₹${t.amount.toStringAsFixed(0)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${t.reason ?? 'No Reason'} • ${_formatDate(t.date)}',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : palette.darkGray,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!t.isSynced)
                      Icon(
                        Icons.sync,
                        size: 16,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                    // Edit not implemented in repo yet, keeping delete
                    IconButton(
                      icon: Icon(Icons.delete, color: palette.tomatoRed),
                      onPressed: () => _confirmDeleteTx(context, t),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) {
    return "${d.day}/${d.month}/${d.year}";
  }

  void _showAddTransaction(BuildContext context) {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String type = 'given';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        // Needed for Dropdown update
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Transaction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Amount',
                  labelText: 'Amount',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  hintText: 'Reason (optional)',
                  labelText: 'Reason',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: type,
                items: const [
                  DropdownMenuItem(
                    value: 'given',
                    child: Text('I Gave Money (Get Back)'),
                  ),
                  DropdownMenuItem(
                    value: 'taken',
                    child: Text('I Took Money (Pay Back)'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => type = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (amt <= 0) return;

                await sl<UdharRepository>().addTransaction(
                  userId: customerId,
                  personId: personId,
                  amount: amt,
                  type: type,
                  reason: reasonCtrl.text.trim(),
                  date: DateTime.now(),
                );

                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTx(BuildContext context, UdharTransaction t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Transaction?"),
        content: const Text("This will reverse the balance effect."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await sl<UdharRepository>().deleteTransaction(
                userId: customerId,
                personId: personId,
                txId: t.id,
              );
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
