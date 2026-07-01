import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../data/repositories/restaurant_ops_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class RestaurantPricingAdminScreen extends StatefulWidget {
  const RestaurantPricingAdminScreen({super.key});

  @override
  State<RestaurantPricingAdminScreen> createState() =>
      _RestaurantPricingAdminScreenState();
}

class _RestaurantPricingAdminScreenState
    extends State<RestaurantPricingAdminScreen>
    with SingleTickerProviderStateMixin {
  final RestaurantOpsRepository _repo = RestaurantOpsRepository();
  late final TabController _tab;
  List<Map<String, dynamic>> _combos = const [];
  List<Map<String, dynamic>> _happyHours = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final combos = await _repo.listCombos();
    final happyHours = await _repo.listHappyHours();
    if (!mounted) return;
    setState(() {
      _combos = combos;
      _happyHours = happyHours;
      _loading = false;
    });
  }

  Future<void> _createCombo() async {
    final name = TextEditingController();
    final price = TextEditingController(text: '10000');
    final items = TextEditingController(
      text: '[{"menuItemId":"id","quantity":1}]',
    );
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Combo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: price,
              decoration: const InputDecoration(
                labelText: 'Bundle price (cents)',
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: items,
              decoration: const InputDecoration(labelText: 'Items JSON'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _repo.createCombo(
                name: name.text.trim(),
                bundlePriceCents: int.tryParse(price.text) ?? 0,
                items: const [
                  {'menuItemId': 'pending-selection', 'quantity': 1},
                ],
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

  Future<void> _createHappyHour() async {
    final name = TextEditingController();
    final value = TextEditingController(text: '10');
    final start = TextEditingController(text: '17:00');
    final end = TextEditingController(text: '20:00');
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Happy Hour'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: value,
              decoration: const InputDecoration(labelText: 'Discount value'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: start,
              decoration: const InputDecoration(labelText: 'Start HH:mm'),
            ),
            TextField(
              controller: end,
              decoration: const InputDecoration(labelText: 'End HH:mm'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _repo.createHappyHour(
                name: name.text.trim(),
                discountType: 'percent',
                discountValue: num.tryParse(value.text) ?? 10,
                menuItemIds: const [],
                daysOfWeek: const [1, 2, 3, 4, 5, 6, 0],
                startTime: start.text.trim(),
                endTime: end.text.trim(),
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
        title: Text(
          'Pricing Admin',
          style: AppTypography.headlineMedium.copyWith(
            color: isDark
                ? FuturisticColors.darkTextPrimary
                : FuturisticColors.textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: FuturisticColors.primary,
          tabs: const [
            Tab(text: 'Combos'),
            Tab(text: 'Happy Hours'),
          ],
        ),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _tab.index == 0 ? _createCombo() : _createHappyHour(),
        backgroundColor: FuturisticColors.primary,
        icon: const Icon(Icons.add),
        label: Text(_tab.index == 0 ? 'Add Combo' : 'Add Happy Hour'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth > 1200
                    ? 1000.0
                    : constraints.maxWidth;
                return Center(
                  child: SizedBox(
                    width: maxWidth,
                    child: TabBarView(
                      controller: _tab,
                      children: [_buildComboList(), _buildHappyHourList()],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildComboList() {
    if (_combos.isEmpty) return const Center(child: Text('No combos'));
    return ListView.builder(
      itemCount: _combos.length,
      itemBuilder: (_, i) {
        final c = _combos[i];
        final comboId = '${c['id'] ?? ''}';
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: GlassContainer(
            borderRadius: AppBorderRadius.lg,
            child: ListTile(
              title: Text('${c['name'] ?? 'Combo'}'),
              subtitle: Text('Bundle: ${c['bundlePriceCents'] ?? '-'} cents'),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: comboId.isEmpty
                    ? null
                    : () async {
                        await _repo.deleteCombo(comboId);
                        await _refresh();
                      },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHappyHourList() {
    if (_happyHours.isEmpty) return const Center(child: Text('No happy hours'));
    return ListView.builder(
      itemCount: _happyHours.length,
      itemBuilder: (_, i) {
        final h = _happyHours[i];
        final happyHourId = '${h['id'] ?? ''}';
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: GlassContainer(
            borderRadius: AppBorderRadius.lg,
            child: ListTile(
              title: Text('${h['name'] ?? 'Happy Hour'}'),
              subtitle: Text(
                '${h['discountType'] ?? 'percent'} ${h['discountValue'] ?? '-'}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: happyHourId.isEmpty
                    ? null
                    : () async {
                        await _repo.deleteHappyHour(happyHourId);
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
