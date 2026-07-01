import 'package:flutter/material.dart';
import '../../data/hardware_ops_repository.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class HardwareInvoiceProfileScreen extends StatefulWidget {
  const HardwareInvoiceProfileScreen({super.key});

  @override
  State<HardwareInvoiceProfileScreen> createState() =>
      _HardwareInvoiceProfileScreenState();
}

class _HardwareInvoiceProfileScreenState
    extends State<HardwareInvoiceProfileScreen> {
  final _repo = HardwareOpsRepository();
  bool _loading = true;
  String? _defaultProfileId;
  List<Map<String, dynamic>> _profiles = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _repo.getInvoiceProfiles();
      if (!mounted) return;
      setState(() {
        _defaultProfileId = data['defaultProfileId']?.toString();
        final rows = (data['profiles'] as List?) ?? const [];
        _profiles = rows
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } on HardwareOpsException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load invoice profiles: ${e.message}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _save() async {
    try {
      await _repo.saveInvoiceProfiles(
        profiles: _profiles,
        defaultProfileId: _defaultProfileId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice profiles saved')),
      );
    } on HardwareOpsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: ${e.message}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Format Profiles'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save',
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : DesktopContentContainer(
              maxWidth: 1400,
              padding: const EdgeInsets.all(14),
              child: ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _summaryStrip(cs),
                  const SizedBox(height: 12),
                  if (_profiles.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 40,
                              color: cs.primary,
                            ),
                            const SizedBox(height: 10),
                            const Text('No invoice profile yet'),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: _showAddDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Create First Profile'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    ..._profiles.map((profile) => _profileCard(profile, cs)),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _showAddDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Profile'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
      ),
    );
  }

  Widget _summaryStrip(ColorScheme cs) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _summaryChip(
          icon: Icons.layers_outlined,
          label: 'Profiles',
          value: '${_profiles.length}',
          color: cs.primary,
        ),
        _summaryChip(
          icon: Icons.check_circle_outline,
          label: 'Default',
          value: _defaultProfileName(),
          color: cs.tertiary,
        ),
      ],
    );
  }

  Widget _summaryChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, size: 14, color: color),
      ),
      label: Text('$label: $value'),
    );
  }

  Widget _profileCard(Map<String, dynamic> profile, ColorScheme cs) {
    final id = (profile['id'] ?? '').toString();
    final isDefault = id == _defaultProfileId;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (profile['name'] ?? id).toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (isDefault)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: const Text('Default'),
                    avatar: Icon(Icons.star, size: 14, color: cs.primary),
                  )
                else
                  TextButton.icon(
                    onPressed: () => setState(() => _defaultProfileId = id),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Set Default'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _boolTag('Logo', profile['showLogo'] == true),
                _boolTag('Customer GSTIN', profile['showCustomerGstin'] == true),
                _boolTag('Item HSN', profile['showItemHsn'] == true),
                _boolTag('Round Off', profile['showRoundOff'] == true),
                _boolTag('Payment Summary', profile['showPaymentSummary'] == true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _boolTag(String label, bool enabled) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text('$label: ${enabled ? "On" : "Off"}'),
      avatar: Icon(
        enabled ? Icons.check : Icons.close,
        size: 14,
        color: enabled ? Colors.green : Colors.red,
      ),
    );
  }

  String _defaultProfileName() {
    if (_defaultProfileId == null || _defaultProfileId!.isEmpty) return 'Not set';
    for (final p in _profiles) {
      if ((p['id'] ?? '').toString() == _defaultProfileId) {
        return (p['name'] ?? _defaultProfileId).toString();
      }
    }
    return _defaultProfileId!;
  }

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    bool showLogo = true;
    bool showHsn = true;
    bool showGstin = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('New Invoice Profile'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Profile Name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  value: showLogo,
                  onChanged: (v) => setLocal(() => showLogo = v),
                  title: const Text('Show logo'),
                ),
                SwitchListTile.adaptive(
                  value: showHsn,
                  onChanged: (v) => setLocal(() => showHsn = v),
                  title: const Text('Show item HSN'),
                ),
                SwitchListTile.adaptive(
                  value: showGstin,
                  onChanged: (v) => setLocal(() => showGstin = v),
                  title: const Text('Show customer GSTIN'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    final profile = <String, dynamic>{
      'id': 'profile_${DateTime.now().millisecondsSinceEpoch}',
      'name': nameCtrl.text.trim(),
      'showLogo': showLogo,
      'showCustomerGstin': showGstin,
      'showItemHsn': showHsn,
      'showRoundOff': true,
      'showPaymentSummary': true,
    };
    setState(() {
      _profiles = [..._profiles, profile];
      _defaultProfileId ??= profile['id'] as String;
    });
  }
}
