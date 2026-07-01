// ============================================================================
// DECORATION & CATERING — DECORATION MANAGEMENT SCREEN
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/dc_models.dart';
import '../../data/repositories/dc_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DcDecorationScreen extends ConsumerStatefulWidget {
  const DcDecorationScreen({super.key});

  @override
  ConsumerState<DcDecorationScreen> createState() => _DcDecorationScreenState();
}

class _DcDecorationScreenState extends ConsumerState<DcDecorationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabs,
              labelColor: const Color(0xFF7C3AED),
              unselectedLabelColor: const Color(0xFF6B7280),
              indicatorColor: const Color(0xFF7C3AED),
              tabs: const [
                Tab(text: 'Decoration Themes'),
                Tab(text: 'Setup Checklist'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ThemesTab(),
                _ChecklistTab(),
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
              Text('Decoration Management', style: TextStyle(fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 22), fontWeight: FontWeight.bold, color: const Color(0xFF1A1A2E))),
              const SizedBox(height: 4),
              const Text('Themes, stage designs & setup tracking', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => _addThemeDialog(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Theme'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  void _addThemeDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String category = 'Floral';
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Add Decoration Theme'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _formField(nameCtrl, 'Theme Name'),
                const SizedBox(height: 12),
                _formField(descCtrl, 'Description', maxLines: 2),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: ['Floral', 'Modern', 'Traditional', 'Luxury', 'Fun', 'Rustic']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setS(() => category = v!),
                ),
                const SizedBox(height: 12),
                _formField(priceCtrl, 'Base Price (₹)', keyboard: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                await ref.read(dcRepositoryProvider).createTheme(DecorationTheme(
                  id: 'DT${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text,
                  description: descCtrl.text,
                  category: category,
                  basePrice: double.tryParse(priceCtrl.text) ?? 0,
                ));
                ref.invalidate(dcThemesProvider);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white),
              child: const Text('Add Theme'),
            ),
          ],
        ),
      ),
    );
  }

  TextField _formField(TextEditingController ctrl, String label, {TextInputType keyboard = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
    );
  }
}

// ---------------------------------------------------------------------------
// Themes Tab
// ---------------------------------------------------------------------------
class _ThemesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themesAsync = ref.watch(dcThemesProvider);
    return themesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (themes) => themes.isEmpty
          ? _emptyState(context)
          : GridView.builder(
              padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 320,
                mainAxisExtent: 240,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: themes.length,
              itemBuilder: (ctx, i) => _ThemeCard(theme: themes[i]),
            ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.palette_outlined, size: 64, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 16),
          Text('No themes yet', style: TextStyle(fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ), fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
          const SizedBox(height: 8),
          const Text('Add your first decoration theme', style: TextStyle(color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final DecorationTheme theme;
  const _ThemeCard({required this.theme});

  static const _categoryColors = {
    'Floral': Color(0xFFEC4899),
    'Modern': Color(0xFF2563EB),
    'Traditional': Color(0xFFD97706),
    'Luxury': Color(0xFFB8860B),
    'Fun': Color(0xFF7C3AED),
    'Rustic': Color(0xFF854D0E),
  };

  @override
  Widget build(BuildContext context) {
    final color = _categoryColors[theme.category] ?? const Color(0xFF6B7280);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Color banner
          Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Center(child: Icon(Icons.celebration_rounded, color: Colors.white.withValues(alpha: 0.8), size: 36)),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(theme.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(theme.category, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(theme.description, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.currency_rupee_rounded, size: 14, color: Color(0xFF059669)),
                    Text('${(theme.basePrice / 1000).toStringAsFixed(0)}K base price',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                    const Spacer(),
                    Text('${theme.includedItems.length} items', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Checklist Tab
// ---------------------------------------------------------------------------
class _ChecklistTab extends StatefulWidget {
  @override
  State<_ChecklistTab> createState() => _ChecklistTabState();
}

class _ChecklistTabState extends State<_ChecklistTab> {
  final List<_CheckItem> _items = [
    _CheckItem('Venue measurement and layout planning'),
    _CheckItem('Stage backdrop design confirmation'),
    _CheckItem('Floral arrangement order placed'),
    _CheckItem('Lighting equipment booked'),
    _CheckItem('Fabric and draping materials sourced'),
    _CheckItem('Entry arch design confirmed'),
    _CheckItem('Table centerpieces prepared'),
    _CheckItem('Photo booth setup materials ready'),
    _CheckItem('Sound system tested'),
    _CheckItem('Staff briefing completed'),
    _CheckItem('Transportation for materials arranged'),
    _CheckItem('On-site assembly team assigned'),
    _CheckItem('Customer walkthrough scheduled'),
    _CheckItem('Backup supplies packed'),
  ];

  @override
  Widget build(BuildContext context) {
    final done = _items.where((i) => i.done).length;
    return Padding(
      padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.checklist_rounded, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 8),
                        const Text('Event Setup Checklist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const Spacer(),
                        Text('$done / ${_items.length} completed',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  LinearProgressIndicator(
                    value: _items.isEmpty ? 0 : done / _items.length,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF7C3AED)),
                    minHeight: 4,
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: _items.asMap().entries.map((entry) {
                        final item = entry.value;
                        return CheckboxListTile(
                          value: item.done,
                          onChanged: (v) => setState(() => item.done = v ?? false),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 13,
                              decoration: item.done ? TextDecoration.lineThrough : null,
                              color: item.done ? const Color(0xFF9CA3AF) : const Color(0xFF374151),
                            ),
                          ),
                          activeColor: const Color(0xFF7C3AED),
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 260,
            child: Column(
              children: [
                _statCard('Total Items', '${_items.length}', Icons.list_alt_rounded, const Color(0xFF2563EB)),
                const SizedBox(height: 12),
                _statCard('Completed', '$done', Icons.check_circle_rounded, const Color(0xFF059669)),
                const SizedBox(height: 12),
                _statCard('Pending', '${_items.length - done}', Icons.pending_actions_rounded, const Color(0xFFD97706)),
                const SizedBox(height: 12),
                _statCard('Progress', '${(_items.isEmpty ? 0 : done * 100 ~/ _items.length)}%', Icons.donut_small_rounded, const Color(0xFF7C3AED)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20), fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckItem {
  final String label;
  bool done = false;
  _CheckItem(this.label);
}
