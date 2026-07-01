// ============================================================================
// DECORATION & CATERING — CATERING MANAGEMENT SCREEN
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/dc_models.dart';
import '../../data/repositories/dc_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DcCateringScreen extends ConsumerStatefulWidget {
  const DcCateringScreen({super.key});

  @override
  ConsumerState<DcCateringScreen> createState() => _DcCateringScreenState();
}

class _DcCateringScreenState extends ConsumerState<DcCateringScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  MenuCategory? _filterCategory;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
        children: [
          _buildHeader(context),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabs,
              labelColor: const Color(0xFFD97706),
              unselectedLabelColor: const Color(0xFF6B7280),
              indicatorColor: const Color(0xFFD97706),
              tabs: const [
                Tab(text: 'Menu Items'),
                Tab(text: 'Packages'),
                Tab(text: 'Meal Planner'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _MenuItemsTab(filterCategory: _filterCategory, onFilterChanged: (c) => setState(() => _filterCategory = c)),
                _PackagesTab(),
                _MealPlannerTab(),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Catering Management', style: TextStyle(fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 22), fontWeight: FontWeight.bold, color: const Color(0xFF1A1A2E))),
              const SizedBox(height: 4),
              const Text('Menu items, packages and meal planning', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            ],
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _addPackageDialog(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Package'),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFD97706), side: const BorderSide(color: Color(0xFFD97706))),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _addMenuItemDialog(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Menu Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addMenuItemDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    MenuCategory category = MenuCategory.veg;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(children: [Icon(Icons.restaurant_menu_rounded, color: Color(0xFFD97706)), SizedBox(width: 8), Text('Add Menu Item')]),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(nameCtrl, 'Item Name'),
                const SizedBox(height: 12),
                DropdownButtonFormField<MenuCategory>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: MenuCategory.values.map((c) {
                    final item = CateringMenuItem(id: '', name: '', category: c, pricePerPlate: 0);
                    return DropdownMenuItem(value: c, child: Row(
                      children: [
                        Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(color: item.categoryColor, shape: BoxShape.circle)),
                        Text(item.categoryLabel),
                      ],
                    ));
                  }).toList(),
                  onChanged: (v) => setS(() => category = v!),
                ),
                const SizedBox(height: 12),
                _field(priceCtrl, 'Price per Plate (₹)', keyboard: TextInputType.number),
                const SizedBox(height: 12),
                _field(descCtrl, 'Description (optional)', maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                await ref.read(dcRepositoryProvider).createMenuItem(CateringMenuItem(
                  id: 'M${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text,
                  category: category,
                  pricePerPlate: double.tryParse(priceCtrl.text) ?? 0,
                  description: descCtrl.text,
                ));
                ref.invalidate(dcMenuItemsProvider);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
              child: const Text('Add Item'),
            ),
          ],
        ),
      ),
    );
  }

  void _addPackageDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final minGuestsCtrl = TextEditingController(text: '100');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Add Catering Package'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(nameCtrl, 'Package Name'),
              const SizedBox(height: 12),
              _field(descCtrl, 'Description', maxLines: 2),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _field(priceCtrl, 'Price/Plate (₹)', keyboard: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _field(minGuestsCtrl, 'Min Guests', keyboard: TextInputType.number)),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              await ref.read(dcRepositoryProvider).createPackage(CateringPackage(
                id: 'CP${DateTime.now().millisecondsSinceEpoch}',
                name: nameCtrl.text,
                description: descCtrl.text,
                pricePerPlate: double.tryParse(priceCtrl.text) ?? 0,
                minGuests: int.tryParse(minGuestsCtrl.text) ?? 100,
              ));
              ref.invalidate(dcPackagesProvider);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
            child: const Text('Add Package'),
          ),
        ],
      ),
    );
  }

  TextField _field(TextEditingController ctrl, String label, {TextInputType keyboard = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
    );
  }
}

// ---------------------------------------------------------------------------
// Menu Items Tab
// ---------------------------------------------------------------------------
class _MenuItemsTab extends ConsumerWidget {
  final MenuCategory? filterCategory;
  final ValueChanged<MenuCategory?> onFilterChanged;
  const _MenuItemsTab({required this.filterCategory, required this.onFilterChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(dcMenuItemsProvider);
    return menuAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        final filtered = filterCategory == null ? items : items.where((i) => i.category == filterCategory).toList();
        return Column(
          children: [
            _buildCategoryFilter(),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No items found'))
                  : GridView.builder(
                      padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 240, mainAxisExtent: 130, crossAxisSpacing: 12, mainAxisSpacing: 12,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) => _MenuItemCard(item: filtered[i]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryFilter() {
    final cats = [null, ...MenuCategory.values];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: cats.map((c) {
            final label = c == null ? 'All' : CateringMenuItem(id: '', name: '', category: c, pricePerPlate: 0).categoryLabel;
            final color = c == null ? const Color(0xFF6B7280) : CateringMenuItem(id: '', name: '', category: c, pricePerPlate: 0).categoryColor;
            final selected = filterCategory == c;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => onFilterChanged(c),
                selectedColor: color.withValues(alpha: 0.15),
                checkmarkColor: color,
                labelStyle: TextStyle(color: selected ? color : const Color(0xFF6B7280), fontSize: 12),
                side: BorderSide(color: selected ? color : const Color(0xFFE5E7EB)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final CateringMenuItem item;
  const _MenuItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: item.categoryColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: item.categoryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(item.categoryLabel, style: TextStyle(fontSize: 10, color: item.categoryColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (item.description != null)
            Text(item.description!, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)), maxLines: 1, overflow: TextOverflow.ellipsis),
          Row(
            children: [
              const Icon(Icons.currency_rupee_rounded, size: 14, color: Color(0xFF059669)),
              Text('${item.pricePerPlate.toStringAsFixed(0)}/plate',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 13)),
              const Spacer(),
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: item.isAvailable ? Colors.green : Colors.red, shape: BoxShape.circle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Packages Tab
// ---------------------------------------------------------------------------
class _PackagesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pkgsAsync = ref.watch(dcPackagesProvider);
    return pkgsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (pkgs) => pkgs.isEmpty
          ? const Center(child: Text('No packages yet'))
          : ListView.separated(
              padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
              itemCount: pkgs.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) => _PackageCard(package: pkgs[i]),
            ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final CateringPackage package;
  const _PackageCard({required this.package});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: const Color(0xFFD97706).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.restaurant_rounded, color: Color(0xFFD97706), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(package.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(package.description, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _chip('Min ${package.minGuests} guests', const Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    _chip('${package.menuItemIds.length} items', const Color(0xFF7C3AED)),
                    if (package.includesService) ...[
                      const SizedBox(width: 8),
                      _chip('Service included', const Color(0xFF059669)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${package.pricePerPlate.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 22), fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
              const Text('per plate', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

// ---------------------------------------------------------------------------
// Meal Planner Tab
// ---------------------------------------------------------------------------
class _MealPlannerTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MealPlannerTab> createState() => _MealPlannerTabState();
}

class _MealPlannerTabState extends ConsumerState<_MealPlannerTab> {
  final _guestCtrl = TextEditingController(text: '200');
  String? _selectedPackageId;

  @override
  Widget build(BuildContext context) {
    final pkgsAsync = ref.watch(dcPackagesProvider);
    final menuAsync = ref.watch(dcMenuItemsProvider);

    return pkgsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (pkgs) {
        if (pkgs.isNotEmpty && (_selectedPackageId == null || !pkgs.any((p) => p.id == _selectedPackageId))) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedPackageId = pkgs.first.id);
          });
        }
        final selectedPkg = pkgs.isEmpty ? null : pkgs.where((p) => p.id == _selectedPackageId).firstOrNull ?? pkgs.first;
        final guests = int.tryParse(_guestCtrl.text) ?? 200;
        final totalCost = selectedPkg != null ? selectedPkg.pricePerPlate * guests : 0.0;

        return Padding(
          padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Meal Planner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedPkg?.id,
                            decoration: const InputDecoration(labelText: 'Select Package', border: OutlineInputBorder(), isDense: true),
                            items: pkgs.map((p) => DropdownMenuItem<String>(value: p.id, child: Text(p.name))).toList(),
                            onChanged: (v) { if (v != null) setState(() => _selectedPackageId = v); },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: _guestCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Guest Count', border: OutlineInputBorder(), isDense: true),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ]),
                      if (selectedPkg != null) ...[
                        const SizedBox(height: 20),
                        const Text('Menu Items in Package', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 8),
                        menuAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, st) => const SizedBox(),
                          data: (allItems) {
                            final pkgItems = allItems.where((m) => selectedPkg.menuItemIds.contains(m.id)).toList();
                            return Column(
                              children: pkgItems.map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(color: item.categoryColor, shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Text(item.name, style: const TextStyle(fontSize: 13)),
                                    const Spacer(),
                                    Text(item.categoryLabel, style: TextStyle(fontSize: 11, color: item.categoryColor)),
                                    const SizedBox(width: 8),
                                    Text('₹${item.pricePerPlate}/plate', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                  ],
                                ),
                              )).toList(),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 240,
                child: Column(
                  children: [
                    _costCard('Per Plate', '₹${selectedPkg?.pricePerPlate.toStringAsFixed(0) ?? '0'}', const Color(0xFF2563EB)),
                    const SizedBox(height: 12),
                    _costCard('Guest Count', '$guests', const Color(0xFF7C3AED)),
                    const SizedBox(height: 12),
                    _costCard('Total Cost', '₹${(totalCost / 1000).toStringAsFixed(1)}K', const Color(0xFF059669)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Raw Material Estimate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFD97706))),
                          const SizedBox(height: 8),
                          _rawMatRow('Rice', '${(guests * 0.15).toStringAsFixed(0)} kg'),
                          _rawMatRow('Oil', '${(guests * 0.05).toStringAsFixed(0)} L'),
                          _rawMatRow('Vegetables', '${(guests * 0.2).toStringAsFixed(0)} kg'),
                          _rawMatRow('Gas Cylinders', '${(guests ~/ 50 + 1)} pcs'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _costCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _rawMatRow(String item, String qty) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record, size: 6, color: Color(0xFFD97706)),
          const SizedBox(width: 6),
          Expanded(child: Text(item, style: const TextStyle(fontSize: 12))),
          Text(qty, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        ],
      ),
    );
  }
}
