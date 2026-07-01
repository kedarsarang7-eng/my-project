import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../data/repositories/restaurant_ops_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class RestaurantTableOpsScreen extends StatefulWidget {
  const RestaurantTableOpsScreen({super.key});

  @override
  State<RestaurantTableOpsScreen> createState() => _RestaurantTableOpsScreenState();
}

class _RestaurantTableOpsScreenState extends State<RestaurantTableOpsScreen>
    with SingleTickerProviderStateMixin {
  final RestaurantOpsRepository _repo = RestaurantOpsRepository();
  late final TabController _tab;

  List<Map<String, dynamic>> _reservations = const [];
  List<Map<String, dynamic>> _waitlist = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final r = await _repo.listReservations();
    final w = await _repo.listWaitlist();
    if (!mounted) return;
    setState(() {
      _reservations = r;
      _waitlist = w;
      _loading = false;
    });
  }

  Future<void> _createReservation() async {
    final guest = TextEditingController();
    final phone = TextEditingController();
    final people = TextEditingController(text: '2');
    final notes = TextEditingController();
    final when = DateTime.now().add(const Duration(hours: 1));
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Reservation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: guest, decoration: const InputDecoration(labelText: 'Guest name')),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
              TextField(controller: people, decoration: const InputDecoration(labelText: 'People'), keyboardType: TextInputType.number),
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _repo.createReservation(
                guestName: guest.text.trim(),
                phone: phone.text.trim(),
                peopleCount: int.tryParse(people.text) ?? 2,
                reservationAt: when.toUtc().toIso8601String(),
                notes: notes.text,
              );
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    await _refresh();
  }

  Future<void> _addWaitlist() async {
    final guest = TextEditingController();
    final phone = TextEditingController();
    final people = TextEditingController(text: '2');
    final notes = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Waitlist Entry'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: guest, decoration: const InputDecoration(labelText: 'Guest name')),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
              TextField(controller: people, decoration: const InputDecoration(labelText: 'People'), keyboardType: TextInputType.number),
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _repo.addToWaitlist(
                guestName: guest.text.trim(),
                phone: phone.text.trim(),
                peopleCount: int.tryParse(people.text) ?? 2,
                notes: notes.text,
              );
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    await _refresh();
  }

  Future<void> _showTableOperations() async {
    final from = TextEditingController();
    final to = TextEditingController();
    final mergeSources = TextEditingController();
    final splitTable = TextEditingController();
    final splitCount = TextEditingController(text: '2');
    final billId = TextEditingController();
    final people = TextEditingController(text: '2');
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Table / Bill Operations'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: from, decoration: const InputDecoration(labelText: 'Transfer from tableId')),
              TextField(controller: to, decoration: const InputDecoration(labelText: 'Transfer to tableId')),
              TextField(controller: mergeSources, decoration: const InputDecoration(labelText: 'Merge source tableIds (comma)')),
              TextField(controller: splitTable, decoration: const InputDecoration(labelText: 'Split tableId')),
              TextField(controller: splitCount, decoration: const InputDecoration(labelText: 'Split count'), keyboardType: TextInputType.number),
              TextField(controller: billId, decoration: const InputDecoration(labelText: 'Bill ID (split bill)')),
              TextField(controller: people, decoration: const InputDecoration(labelText: 'People count'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton(
            onPressed: () async {
              if (from.text.isNotEmpty && to.text.isNotEmpty) {
                await _repo.transferTable(fromTableId: from.text.trim(), toTableId: to.text.trim());
              }
              if (mergeSources.text.isNotEmpty && to.text.isNotEmpty) {
                await _repo.mergeTables(
                  sourceTableIds: mergeSources.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                  targetTableId: to.text.trim(),
                );
              }
              if (splitTable.text.isNotEmpty) {
                await _repo.splitTable(
                  tableId: splitTable.text.trim(),
                  splitCount: int.tryParse(splitCount.text) ?? 2,
                );
              }
              if (billId.text.isNotEmpty) {
                await _repo.splitBill(
                  billId: billId.text.trim(),
                  mode: 'equal',
                  peopleCount: int.tryParse(people.text) ?? 2,
                );
              }
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Run'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? FuturisticColors.darkBackground
          : FuturisticColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppGradients.secondaryGradient,
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
              ),
              child: const Icon(Icons.table_restaurant, color: Colors.white, size: 18),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              'Restaurant Table Ops',
              style: AppTypography.headlineMedium.copyWith(
                color: isDark
                    ? FuturisticColors.darkTextPrimary
                    : FuturisticColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: FuturisticColors.primary,
          tabs: const [
            Tab(text: 'Reservations'),
            Tab(text: 'Waitlist'),
          ],
        ),
        actions: [
          IconButton(onPressed: _showTableOperations, icon: const Icon(Icons.swap_horiz), tooltip: 'Transfer/Merge/Split'),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _tab.index == 0 ? _createReservation() : _addWaitlist(),
        backgroundColor: FuturisticColors.primary,
        icon: const Icon(Icons.add),
        label: Text(_tab.index == 0 ? 'Reservation' : 'Waitlist'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth > 1200
                    ? 1100.0
                    : constraints.maxWidth;
                return Center(
                  child: SizedBox(
                    width: maxWidth,
                    child: TabBarView(
                      controller: _tab,
                      children: [
                        _buildReservationList(),
                        _buildWaitlist(),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildReservationList() {
    if (_reservations.isEmpty) return const Center(child: Text('No reservations'));
    return ListView.builder(
      itemCount: _reservations.length,
      itemBuilder: (_, i) {
        final item = _reservations[i];
        final id = '${item['id'] ?? ''}';
        final status = '${item['status'] ?? 'pending'}';
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: GlassContainer(
            borderRadius: AppBorderRadius.lg,
            child: ListTile(
              title: Text(
                '${item['guestName'] ?? 'Guest'} (${item['peopleCount'] ?? '-'})',
                style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('Phone: ${item['phone'] ?? '-'} | Status: $status'),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  await _repo.updateReservationStatus(reservationId: id, status: value);
                  await _refresh();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'confirmed', child: Text('Confirm')),
                  PopupMenuItem(value: 'seated', child: Text('Seat')),
                  PopupMenuItem(value: 'cancelled', child: Text('Cancel')),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaitlist() {
    if (_waitlist.isEmpty) return const Center(child: Text('No waitlist entries'));
    return ListView.builder(
      itemCount: _waitlist.length,
      itemBuilder: (_, i) {
        final item = _waitlist[i];
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: GlassContainer(
            borderRadius: AppBorderRadius.lg,
            child: ListTile(
              title: Text(
                '${item['guestName'] ?? 'Guest'} (${item['peopleCount'] ?? '-'})',
                style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('Phone: ${item['phone'] ?? '-'}'),
              trailing: IconButton(
                icon: const Icon(Icons.event_seat, color: FuturisticColors.primary),
                onPressed: () async {
                  final table = TextEditingController();
                  await showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Seat Waitlist'),
                      content: TextField(
                        controller: table,
                        decoration: const InputDecoration(labelText: 'Table ID'),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () async {
                            await _repo.seatWaitlist(
                              waitlistId: '${item['id'] ?? ''}',
                              tableId: table.text.trim(),
                            );
                            if (!mounted) return;
                            Navigator.pop(context);
                          },
                          child: const Text('Seat'),
                        ),
                      ],
                    ),
                  );
                  await _refresh();
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
