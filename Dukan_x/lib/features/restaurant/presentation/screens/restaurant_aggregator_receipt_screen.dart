import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../data/repositories/restaurant_ops_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class RestaurantAggregatorReceiptScreen extends StatefulWidget {
  const RestaurantAggregatorReceiptScreen({super.key});

  @override
  State<RestaurantAggregatorReceiptScreen> createState() => _RestaurantAggregatorReceiptScreenState();
}

class _RestaurantAggregatorReceiptScreenState extends State<RestaurantAggregatorReceiptScreen>
    with SingleTickerProviderStateMixin {
  final RestaurantOpsRepository _repo = RestaurantOpsRepository();
  late final TabController _tab;
  List<Map<String, dynamic>> _orders = const [];
  List<Map<String, dynamic>> _receiptLogs = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final orders = await _repo.listAggregatorOrders();
    final logs = await _repo.listReceiptLogs();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _receiptLogs = logs;
      _loading = false;
    });
  }

  Future<void> _updateAggregatorStatus(String billId) async {
    String selected = 'accepted';
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aggregator Status'),
        content: DropdownButtonFormField<String>(
          value: selected,
          items: const [
            DropdownMenuItem(value: 'accepted', child: Text('accepted')),
            DropdownMenuItem(value: 'preparing', child: Text('preparing')),
            DropdownMenuItem(value: 'ready', child: Text('ready')),
            DropdownMenuItem(value: 'dispatched', child: Text('dispatched')),
            DropdownMenuItem(value: 'delivered', child: Text('delivered')),
            DropdownMenuItem(value: 'cancelled', child: Text('cancelled')),
          ],
          onChanged: (v) => selected = v ?? selected,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _repo.updateAggregatorOrderStatus(billId: billId, status: selected);
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
    await _refresh();
  }

  Future<void> _sendReceipt(String billId) async {
    final email = TextEditingController();
    final phone = TextEditingController();
    bool emailOn = true;
    bool smsOn = false;
    bool whatsappOn = true;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setLocal) => AlertDialog(
          title: const Text('Send Receipt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                value: emailOn,
                onChanged: (v) => setLocal(() => emailOn = v ?? false),
                title: const Text('Email'),
              ),
              CheckboxListTile(
                value: smsOn,
                onChanged: (v) => setLocal(() => smsOn = v ?? false),
                title: const Text('SMS'),
              ),
              CheckboxListTile(
                value: whatsappOn,
                onChanged: (v) => setLocal(() => whatsappOn = v ?? false),
                title: const Text('WhatsApp'),
              ),
              TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final channels = <String>[
                  if (emailOn) 'email',
                  if (smsOn) 'sms',
                  if (whatsappOn) 'whatsapp',
                ];
                await _repo.sendReceipt(
                  billId: billId,
                  channels: channels,
                  email: email.text,
                  phone: phone.text,
                );
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Send'),
            ),
          ],
        ),
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
          'Aggregator & Receipt Ops',
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
            Tab(text: 'Aggregator Orders'),
            Tab(text: 'Receipt Logs'),
          ],
        ),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth > 1200 ? 1100.0 : constraints.maxWidth;
                return Center(
                  child: SizedBox(
                    width: maxWidth,
                    child: TabBarView(
                      controller: _tab,
                      children: [
                        _buildOrders(),
                        _buildLogs(),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildOrders() {
    if (_orders.isEmpty) return const Center(child: Text('No aggregator orders'));
    return ListView.builder(
      itemCount: _orders.length,
      itemBuilder: (_, i) {
        final o = _orders[i];
        final billId = '${o['billId'] ?? o['id'] ?? ''}';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          child: GlassContainer(
            borderRadius: AppBorderRadius.lg,
            child: ListTile(
              title: Text('Order ${o['sourceOrderId'] ?? billId}'),
              subtitle: Text('Status: ${o['status'] ?? '-'} | Source: ${o['source'] ?? '-'}'),
              trailing: Wrap(
                spacing: 8,
                children: [
                  IconButton(
                    icon: const Icon(Icons.sync),
                    tooltip: 'Update status',
                    onPressed: billId.isEmpty ? null : () => _updateAggregatorStatus(billId),
                  ),
                  IconButton(
                    icon: const Icon(Icons.receipt_long),
                    tooltip: 'Send receipt',
                    onPressed: billId.isEmpty ? null : () => _sendReceipt(billId),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogs() {
    if (_receiptLogs.isEmpty) return const Center(child: Text('No receipt logs'));
    return ListView.builder(
      itemCount: _receiptLogs.length,
      itemBuilder: (_, i) {
        final l = _receiptLogs[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          child: GlassContainer(
            borderRadius: AppBorderRadius.lg,
            child: ListTile(
              title: Text('Bill ${l['billId'] ?? '-'}'),
              subtitle: Text('Channel: ${l['channel'] ?? '-'} | Status: ${l['status'] ?? '-'}'),
            ),
          ),
        );
      },
    );
  }
}
