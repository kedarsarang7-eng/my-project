import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../data/repositories/restaurant_ops_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class RestaurantDeliveryOpsScreen extends StatefulWidget {
  const RestaurantDeliveryOpsScreen({super.key});

  @override
  State<RestaurantDeliveryOpsScreen> createState() => _RestaurantDeliveryOpsScreenState();
}

class _RestaurantDeliveryOpsScreenState extends State<RestaurantDeliveryOpsScreen> {
  final RestaurantOpsRepository _repo = RestaurantOpsRepository();
  final TextEditingController _billId = TextEditingController();
  Map<String, dynamic>? _tracking;
  bool _loading = false;

  Future<void> _assignRider() async {
    final riderId = TextEditingController();
    final riderName = TextEditingController();
    final riderPhone = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Assign Rider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: riderId, decoration: const InputDecoration(labelText: 'Rider ID')),
            TextField(controller: riderName, decoration: const InputDecoration(labelText: 'Rider Name')),
            TextField(controller: riderPhone, decoration: const InputDecoration(labelText: 'Rider Phone')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _repo.assignDeliveryRider(
                billId: _billId.text.trim(),
                riderId: riderId.text.trim(),
                riderName: riderName.text,
                riderPhone: riderPhone.text,
              );
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
    await _loadTracking();
  }

  Future<void> _updateStatus() async {
    final statuses = [
      'assigned',
      'picked_up',
      'out_for_delivery',
      'delivered',
      'failed',
      'cancelled',
    ];
    String selected = statuses.first;
    final note = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update Delivery Status'),
        content: StatefulBuilder(
          builder: (_, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selected,
                items: statuses.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (value) => setLocal(() => selected = value ?? selected),
              ),
              TextField(controller: note, decoration: const InputDecoration(labelText: 'Note')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _repo.updateDeliveryStatus(
                billId: _billId.text.trim(),
                status: selected,
                note: note.text,
              );
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
    await _loadTracking();
  }

  Future<void> _loadTracking() async {
    if (_billId.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final data = await _repo.getDeliveryTracking(_billId.text.trim());
    if (!mounted) return;
    setState(() {
      _tracking = data;
      _loading = false;
    });
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
          'Delivery Operations',
          style: AppTypography.headlineMedium.copyWith(
            color: isDark
                ? FuturisticColors.darkTextPrimary
                : FuturisticColors.textPrimary,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth > 1200 ? 1000.0 : constraints.maxWidth;
          return Center(
            child: SizedBox(
              width: maxWidth,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    GlassContainer(
                      borderRadius: AppBorderRadius.lg,
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _billId,
                              decoration: const InputDecoration(labelText: 'Bill ID'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(onPressed: _loadTracking, child: const Text('Load')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _billId.text.trim().isEmpty ? null : _assignRider,
                          icon: const Icon(Icons.delivery_dining),
                          label: const Text('Assign Rider'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _billId.text.trim().isEmpty ? null : _updateStatus,
                          icon: const Icon(Icons.timeline),
                          label: const Text('Update Status'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _tracking == null
                              ? const Center(child: Text('No tracking loaded'))
                              : GlassContainer(
                                  borderRadius: AppBorderRadius.lg,
                                  child: ListView(
                                    children: [
                                      ListTile(
                                        title: const Text('Current Status'),
                                        subtitle: Text('${_tracking!['status'] ?? '-'}'),
                                      ),
                                      ListTile(
                                        title: const Text('Rider'),
                                        subtitle: Text(
                                          '${_tracking!['riderName'] ?? '-'} (${_tracking!['riderPhone'] ?? '-'})',
                                        ),
                                      ),
                                      ListTile(
                                        title: const Text('Timeline'),
                                        subtitle: Text('${_tracking!['timeline'] ?? _tracking!['events'] ?? '-'}'),
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
