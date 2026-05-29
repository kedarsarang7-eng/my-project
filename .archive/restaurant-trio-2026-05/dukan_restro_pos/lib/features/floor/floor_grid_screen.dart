// ============================================================================
// FLOOR GRID SCREEN — Table status overview
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/pos_providers.dart';
import '../../models/pos_table.dart';
import '../../services/pos_api_service.dart';

class FloorGridScreen extends ConsumerStatefulWidget {
  const FloorGridScreen({super.key});
  @override
  ConsumerState<FloorGridScreen> createState() => _FloorGridScreenState();
}

class _FloorGridScreenState extends ConsumerState<FloorGridScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<String> _floors = ['All Tables'];
  List<PosTable> _tables = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  static const _orange = Color(0xFFEA580C);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 1, vsync: this);
    _loadTables();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadTables());
  }

  Future<void> _loadTables() async {
    final session = ref.read(vendorSessionProvider);
    if (session == null) {
      if (mounted) context.go('/login');
      return;
    }
    final tables = await PosApiService.fetchTables(session.vendorId);
    final floors = [
      'All Tables',
      ...tables.map((t) => t.floor ?? 'Main').toSet(),
    ];
    if (mounted) {
      setState(() {
        _tables = tables;
        _floors = floors;
        _isLoading = false;
      });
      _tabs = TabController(length: floors.length, vsync: this);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Color _tableColor(PosTableStatus s) {
    switch (s) {
      case PosTableStatus.free:
        return const Color(0xFF10B981);
      case PosTableStatus.occupied:
        return _orange;
      case PosTableStatus.reserved:
        return const Color(0xFF8B5CF6);
      case PosTableStatus.dirty:
        return const Color(0xFFEF4444);
      case PosTableStatus.bill_requested:
        return const Color(0xFFDC2626); // Red
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(vendorSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.restaurant_menu,
                color: _orange,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DukanX Restro POS',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                if (session != null)
                  Text(
                    session.staffName,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: _orange,
          labelColor: _orange,
          unselectedLabelColor: Colors.grey,
          tabs: _floors.map((f) => Tab(text: f)).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.kitchen_outlined),
            tooltip: 'Kitchen Display',
            onPressed: () => context.push('/kds'),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTables),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(vendorSessionProvider.notifier).logout();
              if (mounted) context.go('/login');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : TabBarView(
              controller: _tabs,
              children: _floors.map((floor) {
                final tables = floor == 'All Tables'
                    ? _tables
                    : _tables
                          .where((t) => (t.floor ?? 'Main') == floor)
                          .toList();
                return _buildGrid(tables);
              }).toList(),
            ),
      // Status legend
      bottomNavigationBar: Container(
        height: 60,
        color: const Color(0xFF1A1A1A),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            _legend(const Color(0xFF10B981), 'Free'),
            _legend(_orange, 'Occupied'),
            _legend(const Color(0xFF8B5CF6), 'Reserved'),
            _legend(const Color(0xFFDC2626), 'Bill Req'),
            _legend(const Color(0xFFEF4444), 'Dirty'),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<PosTable> tables) {
    if (tables.isEmpty) {
      return const Center(
        child: Text(
          'No tables in this zone',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: tables.length,
      itemBuilder: (ctx, i) => _buildTableCard(tables[i]),
    );
  }

  Widget _buildTableCard(PosTable table) {
    final color = _tableColor(table.status);
    final isOccupied = table.status == PosTableStatus.occupied;

    return GestureDetector(
      onTap: () {
        ref.read(activeTableIdProvider.notifier).set(table.id);
        ref.read(activeTableNumberProvider.notifier).set(table.number);
        context.push('/table/${table.id}?number=${table.number}');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
          boxShadow: isOccupied
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  table.number,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Table ${table.number}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                table.status.label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (table.capacity != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person, size: 11, color: Colors.grey[600]),
                  Text(
                    ' ${table.capacity}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }
}
