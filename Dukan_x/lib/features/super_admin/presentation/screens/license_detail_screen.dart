import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../data/super_admin_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// License Detail Screen — Full details + audit timeline + action buttons
/// BUG-LIC-013, 018-022: Missing screens added.
class LicenseDetailScreen extends StatefulWidget {
  final String licenseKey;
  const LicenseDetailScreen({super.key, required this.licenseKey});

  @override
  State<LicenseDetailScreen> createState() => _LicenseDetailScreenState();
}

class _LicenseDetailScreenState extends State<LicenseDetailScreen> {
  final SuperAdminRepository _repo = SuperAdminRepository();
  Map<String, dynamic>? _details;
  List<AuditEntry> _auditHistory = [];
  bool _isLoading = true;
  bool _isLoadingHistory = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final details = await _repo.getLicenseDetails(widget.licenseKey);
      setState(() { _details = details; _isLoading = false; });
      _loadHistory(); // Non-blocking
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final history = await _repo.getLicenseHistory(widget.licenseKey);
      if (mounted) setState(() { _auditHistory = history; _isLoadingHistory = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE': case 'ACTIVATED': return FuturisticColors.success;
      case 'EXPIRED': return FuturisticColors.warning;
      case 'SUSPENDED': return const Color(0xFFF97316);
      case 'REVOKED': case 'BANNED': return FuturisticColors.error;
      default: return FuturisticColors.textDisabled;
    }
  }

  Color _planColor(String plan) {
    switch (plan.toLowerCase()) {
      case 'enterprise': return const Color(0xFFA855F7);
      case 'premium': return const Color(0xFFF59E0B);
      case 'pro': return const Color(0xFF06B6D4);
      case 'basic': return FuturisticColors.primary;
      default: return FuturisticColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FuturisticColors.background,
      appBar: AppBar(
        title: const Text('License Details'),
        backgroundColor: FuturisticColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDetails),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: FuturisticColors.primary));
    if (_error != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, color: FuturisticColors.error, size: 48),
        const SizedBox(height: 16),
        Text(_error!, style: TextStyle(color: FuturisticColors.textSecondary)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _loadDetails, child: const Text('Retry')),
      ]));
    }

    final data = _details?['data'] ?? _details ?? {};
    final status = (data['status'] ?? 'unknown').toString();
    final plan = (data['plan'] ?? 'basic').toString();
    final tenantDetails = data['tenant_details'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── License Key Card ──
          _glassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: FuturisticColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.vpn_key, color: FuturisticColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SelectableText(
                          data['licenseKey']?.toString() ?? widget.licenseKey,
                          style: TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold, color: FuturisticColors.textPrimary, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 4),
                        Text('Tenant: ${data['tenantId'] ?? 'N/A'}', style: TextStyle(color: FuturisticColors.textSecondary, fontSize: 12)),
                      ]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18, color: FuturisticColors.primary),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: data['licenseKey']?.toString() ?? widget.licenseKey));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Key copied'), backgroundColor: FuturisticColors.primary));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(children: [
                  _badge(status, _statusColor(status)),
                  const SizedBox(width: 8),
                  _badge(plan, _planColor(plan)),
                  const SizedBox(width: 8),
                  if (data['businessType'] != null) _badge(data['businessType'], FuturisticColors.accent1),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Info Grid ──
          _glassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('License Information'),
                const SizedBox(height: 12),
                _infoRow('Created', _formatDate(data['createdAt'])),
                _infoRow('Expires', data['expiryDate'] != null ? _formatDate(data['expiryDate']) : 'Lifetime'),
                _infoRow('Max Devices', (data['maxDevices'] ?? 1).toString()),
                _infoRow('Max Users', (data['maxUsers'] ?? 10).toString()),
                _infoRow('Business Type', data['businessType'] ?? 'N/A'),
                _infoRow('Created By', data['createdBy'] ?? 'N/A'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Owner Info ──
          _glassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _sectionTitle('Owner Details'),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      onPressed: () => _showEditOwnerDialog(data),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _infoRow('Name', data['ownerName'] ?? tenantDetails?['name'] ?? 'Not set'),
                _infoRow('Email', data['ownerEmail'] ?? tenantDetails?['email'] ?? 'Not set'),
                _infoRow('Phone', data['ownerPhone'] ?? tenantDetails?['phone'] ?? 'Not set'),
                _infoRow('Business', data['businessName'] ?? 'Not set'),
                if (data['notes'] != null && data['notes'].toString().isNotEmpty)
                  _infoRow('Notes', data['notes']),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Features ──
          if (data['features'] != null && (data['features'] as List).isNotEmpty)
            _glassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Features'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: (data['features'] as List).map((f) => Chip(
                      label: Text(f.toString(), style: TextStyle(color: FuturisticColors.textPrimary, fontSize: 12)),
                      backgroundColor: FuturisticColors.surface,
                      side: BorderSide(color: FuturisticColors.primary.withValues(alpha: 0.3)),
                    )).toList(),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // ── Action Buttons ──
          _sectionTitle('Actions'),
          const SizedBox(height: 12),

          Wrap(
            spacing: 10, runSpacing: 10,
            children: [
              _actionButton('Upgrade Plan', Icons.upgrade, FuturisticColors.accent2, () => _showUpgradeDialog(data)),
              _actionButton('Extend', Icons.timer, FuturisticColors.accent1, () => _showExtendDialog(data)),
              _actionButton('Devices', Icons.devices, FuturisticColors.primary, () => _showDevicesDialog(data)),
              _actionButton('Biz Type', Icons.business, const Color(0xFF14B8A6), () => _showBusinessTypeDialog(data)),
              if (status.toUpperCase() == 'ACTIVE' || status.toUpperCase() == 'ACTIVATED') ...[
                _actionButton('Suspend', Icons.pause_circle, FuturisticColors.warning, () => _showStatusChangeDialog('suspend', data)),
                _actionButton('Revoke', Icons.block, FuturisticColors.error, () => _showStatusChangeDialog('revoke', data)),
              ],
              if (status.toUpperCase() == 'SUSPENDED' || status.toUpperCase() == 'EXPIRED' || status.toUpperCase() == 'INACTIVE')
                _actionButton('Reactivate', Icons.play_circle, FuturisticColors.success, () => _showStatusChangeDialog('reactivate', data)),
            ],
          ),

          const SizedBox(height: 24),

          // ── Audit History Timeline ──
          _sectionTitle('Modification History'),
          const SizedBox(height: 12),
          _buildAuditTimeline(),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildAuditTimeline() {
    if (_isLoadingHistory) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: FuturisticColors.primary, strokeWidth: 2)),
      );
    }
    if (_auditHistory.isEmpty) {
      return _glassCard(child: Row(children: [
        Icon(Icons.history, color: FuturisticColors.textDisabled, size: 20),
        const SizedBox(width: 12),
        Text('No audit history available', style: TextStyle(color: FuturisticColors.textSecondary, fontSize: 13)),
      ]));
    }

    return Column(
      children: _auditHistory.asMap().entries.map((entry) {
        final idx = entry.key;
        final audit = entry.value;
        final isLast = idx == _auditHistory.length - 1;
        return _buildTimelineItem(audit, isLast);
      }).toList(),
    );
  }

  Widget _buildTimelineItem(AuditEntry audit, bool isLast) {
    final actionColor = _actionColor(audit.action);
    final actionIcon = _actionIcon(audit.action);
    final timeStr = '${audit.timestamp.year}-${audit.timestamp.month.toString().padLeft(2, '0')}-${audit.timestamp.day.toString().padLeft(2, '0')} ${audit.timestamp.hour.toString().padLeft(2, '0')}:${audit.timestamp.minute.toString().padLeft(2, '0')}';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline rail
          SizedBox(
            width: 40,
            child: Column(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: actionColor, width: 2),
                ),
                child: Icon(actionIcon, size: 14, color: actionColor),
              ),
              if (!isLast) Expanded(
                child: Container(width: 2, color: FuturisticColors.border),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: FuturisticColors.premiumCardDecoration(borderRadius: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(audit.action.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(color: actionColor, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    const Spacer(),
                    Text(timeStr, style: TextStyle(color: FuturisticColors.textDisabled, fontSize: 11)),
                  ]),
                  if (audit.performedBy != null) ...[                    const SizedBox(height: 4),
                    Text('by ${audit.performedBy}', style: TextStyle(color: FuturisticColors.textSecondary, fontSize: 11)),
                  ],
                  if (audit.details != null) ...[                    const SizedBox(height: 6),
                    Text(audit.details!, style: TextStyle(color: FuturisticColors.textPrimary, fontSize: 12)),
                  ],
                  // Old → New diff
                  if (audit.oldValues != null || audit.newValues != null) ...[                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: FuturisticColors.background,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (audit.oldValues != null)
                            ...audit.oldValues!.entries.map((e) => Text(
                              '- ${e.key}: ${e.value}',
                              style: TextStyle(color: FuturisticColors.error.withValues(alpha: 0.8), fontSize: 11, fontFamily: 'monospace'),
                            )),
                          if (audit.newValues != null)
                            ...audit.newValues!.entries.map((e) => Text(
                              '+ ${e.key}: ${e.value}',
                              style: TextStyle(color: FuturisticColors.success.withValues(alpha: 0.8), fontSize: 11, fontFamily: 'monospace'),
                            )),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _actionColor(String action) {
    final a = action.toLowerCase();
    if (a.contains('create') || a.contains('generate') || a.contains('activate')) return FuturisticColors.success;
    if (a.contains('upgrade')) return const Color(0xFFA855F7);
    if (a.contains('extend') || a.contains('renew')) return FuturisticColors.accent1;
    if (a.contains('suspend') || a.contains('deactivate')) return FuturisticColors.warning;
    if (a.contains('revoke') || a.contains('block') || a.contains('expire')) return FuturisticColors.error;
    if (a.contains('transfer')) return FuturisticColors.primary;
    if (a.contains('update') || a.contains('change') || a.contains('edit')) return const Color(0xFF14B8A6);
    return FuturisticColors.textSecondary;
  }

  IconData _actionIcon(String action) {
    final a = action.toLowerCase();
    if (a.contains('create') || a.contains('generate')) return Icons.add_circle;
    if (a.contains('activate')) return Icons.check_circle;
    if (a.contains('upgrade')) return Icons.upgrade;
    if (a.contains('extend') || a.contains('renew')) return Icons.timer;
    if (a.contains('suspend')) return Icons.pause_circle;
    if (a.contains('revoke') || a.contains('block')) return Icons.block;
    if (a.contains('expire')) return Icons.hourglass_disabled;
    if (a.contains('transfer')) return Icons.swap_horiz;
    if (a.contains('owner') || a.contains('update') || a.contains('change')) return Icons.edit;
    if (a.contains('device')) return Icons.devices;
    return Icons.history;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _glassCard({required Widget child}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: FuturisticColors.premiumCardDecoration(),
    child: child,
  );

  Widget _sectionTitle(String t) => Text(t, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: FuturisticColors.textPrimary));

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      SizedBox(width: 120, child: Text(label, style: TextStyle(color: FuturisticColors.textSecondary, fontSize: 13))),
      Expanded(child: SelectableText(value, style: TextStyle(color: FuturisticColors.textPrimary, fontSize: 13))),
    ]),
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.4))),
    child: Text(text.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
  );

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: FuturisticColors.textPrimary, fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
    );
  }

  String _formatDate(dynamic d) {
    if (d == null) return 'N/A';
    final dt = DateTime.tryParse(d.toString());
    return dt != null ? '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}' : d.toString();
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  Future<void> _showUpgradeDialog(Map<String, dynamic> data) async {
    String selected = data['plan']?.toString().toLowerCase() ?? 'basic';
    final plans = ['basic', 'pro', 'premium', 'enterprise'];
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: FuturisticColors.surface,
      title: Text('Upgrade Plan', style: TextStyle(color: FuturisticColors.textPrimary)),
      content: StatefulBuilder(builder: (ctx, setSt) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Current: ${data['plan']?.toString().toUpperCase()}', style: TextStyle(color: FuturisticColors.textSecondary)),
        const SizedBox(height: 16),
        ...plans.map((p) => RadioListTile<String>(
          title: Text(p.toUpperCase(), style: TextStyle(color: FuturisticColors.textPrimary)),
          value: p, groupValue: selected,
          activeColor: FuturisticColors.primary,
          onChanged: (v) => setSt(() => selected = v!),
        )),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, selected),
          style: ElevatedButton.styleFrom(backgroundColor: FuturisticColors.primary),
          child: const Text('Upgrade', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));

    if (result != null && result != data['plan']?.toString().toLowerCase()) {
      try {
        await _repo.upgradeLicense(widget.licenseKey, result);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Plan upgraded to ${result.toUpperCase()}'), backgroundColor: FuturisticColors.success));
        _loadDetails();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: FuturisticColors.error));
      }
    }
  }

  Future<void> _showExtendDialog(Map<String, dynamic> data) async {
    String selected = '3 months';
    final durations = ['1 month', '3 months', '6 months', '12 months', '2 Years', '3 Years', 'Lifetime'];
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: FuturisticColors.surface,
      title: Text('Extend Duration', style: TextStyle(color: FuturisticColors.textPrimary)),
      content: StatefulBuilder(builder: (ctx, setSt) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Current expiry: ${_formatDate(data['expiryDate'])}', style: TextStyle(color: FuturisticColors.textSecondary)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: selected,
          dropdownColor: FuturisticColors.surface,
          style: TextStyle(color: FuturisticColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Add Duration', labelStyle: TextStyle(color: FuturisticColors.textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: FuturisticColors.border)),
          ),
          items: durations.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
          onChanged: (v) => setSt(() => selected = v!),
        ),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, selected),
          style: ElevatedButton.styleFrom(backgroundColor: FuturisticColors.accent1),
          child: const Text('Extend', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));

    if (result != null) {
      try {
        await _repo.extendLicense(widget.licenseKey, result);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Extended by $result'), backgroundColor: FuturisticColors.success));
        _loadDetails();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: FuturisticColors.error));
      }
    }
  }

  Future<void> _showStatusChangeDialog(String action, Map<String, dynamic> data) async {
    final reasonCtrl = TextEditingController();
    final isDestructive = action == 'revoke' || action == 'suspend';
    // BUG-LIC-022: Confirmation dialog for destructive actions
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: FuturisticColors.surface,
      title: Text('${action.toUpperCase()} License?',
        style: TextStyle(color: isDestructive ? FuturisticColors.error : FuturisticColors.success)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (isDestructive) Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: FuturisticColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.warning_amber, color: FuturisticColors.error),
            const SizedBox(width: 8),
            Expanded(child: Text('This will ${action == 'revoke' ? 'permanently revoke' : 'suspend'} the license. The tenant will lose access.',
              style: TextStyle(color: FuturisticColors.error, fontSize: 13))),
          ]),
        ),
        const SizedBox(height: 16),
        if (action != 'reactivate') TextField(
          controller: reasonCtrl,
          style: TextStyle(color: FuturisticColors.textPrimary),
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Reason (required)',
            labelStyle: TextStyle(color: FuturisticColors.textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: FuturisticColors.border)),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (action != 'reactivate' && reasonCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Reason is required')));
              return;
            }
            Navigator.pop(ctx, true);
          },
          style: ElevatedButton.styleFrom(backgroundColor: isDestructive ? FuturisticColors.error : FuturisticColors.success),
          child: Text(action.toUpperCase(), style: const TextStyle(color: Colors.white)),
        ),
      ],
    ));

    if (confirmed == true) {
      try {
        final tenantId = data['tenantId']?.toString() ?? '';
        await _repo.changeLicenseStatus(tenantId, action, reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim());
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('License ${action}d'), backgroundColor: FuturisticColors.success));
        _loadDetails();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: FuturisticColors.error));
      }
    }
    reasonCtrl.dispose();
  }

  Future<void> _showDevicesDialog(Map<String, dynamic> data) async {
    final ctrl = TextEditingController(text: (data['maxDevices'] ?? 1).toString());
    final result = await showDialog<int>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: FuturisticColors.surface,
      title: Text('Update Max Devices', style: TextStyle(color: FuturisticColors.textPrimary)),
      content: TextField(
        controller: ctrl, keyboardType: TextInputType.number,
        style: TextStyle(color: FuturisticColors.textPrimary),
        decoration: InputDecoration(
          labelText: 'Max Devices (1-10)', labelStyle: TextStyle(color: FuturisticColors.textSecondary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: FuturisticColors.border)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final n = int.tryParse(ctrl.text);
            if (n != null && n >= 1 && n <= 10) Navigator.pop(ctx, n);
          },
          style: ElevatedButton.styleFrom(backgroundColor: FuturisticColors.primary),
          child: const Text('Update', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
    ctrl.dispose();

    if (result != null) {
      try {
        await _repo.updateMaxDevices(widget.licenseKey, result);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Max devices → $result'), backgroundColor: FuturisticColors.success));
        _loadDetails();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: FuturisticColors.error));
      }
    }
  }

  Future<void> _showBusinessTypeDialog(Map<String, dynamic> data) async {
    final types = ['general', 'grocery', 'pharmacy', 'restaurant', 'clothing', 'electronics', 'mobile_shop', 'computer_shop', 'hardware', 'service', 'wholesale', 'petrol_pump', 'vegetables_broker', 'clinic', 'book_store', 'salon', 'other'];
    String selected = data['businessType']?.toString() ?? 'general';
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: FuturisticColors.surface,
      title: Text('Change Business Type', style: TextStyle(color: FuturisticColors.textPrimary)),
      content: StatefulBuilder(builder: (ctx, setSt) => SizedBox(
        width: 300, height: 300,
        child: ListView(children: types.map((t) => RadioListTile<String>(
          title: Text(t.toUpperCase(), style: TextStyle(color: FuturisticColors.textPrimary, fontSize: 13)),
          value: t, groupValue: selected, activeColor: FuturisticColors.primary,
          onChanged: (v) => setSt(() => selected = v!),
        )).toList()),
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, selected),
          style: ElevatedButton.styleFrom(backgroundColor: FuturisticColors.primary),
          child: const Text('Update', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));

    if (result != null && result != data['businessType']?.toString()) {
      try {
        await _repo.updateBusinessType(widget.licenseKey, result);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Business type → ${result.toUpperCase()}'), backgroundColor: FuturisticColors.success));
        _loadDetails();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: FuturisticColors.error));
      }
    }
  }

  Future<void> _showEditOwnerDialog(Map<String, dynamic> data) async {
    final nameCtrl = TextEditingController(text: data['ownerName']?.toString() ?? '');
    final emailCtrl = TextEditingController(text: data['ownerEmail']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: data['ownerPhone']?.toString() ?? '');
    final bizCtrl = TextEditingController(text: data['businessName']?.toString() ?? '');

    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: FuturisticColors.surface,
      title: Text('Edit Owner Details', style: TextStyle(color: FuturisticColors.textPrimary)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _dialogTextField(nameCtrl, 'Owner Name', Icons.person),
        const SizedBox(height: 12),
        _dialogTextField(emailCtrl, 'Email', Icons.email),
        const SizedBox(height: 12),
        _dialogTextField(phoneCtrl, 'Phone', Icons.phone),
        const SizedBox(height: 12),
        _dialogTextField(bizCtrl, 'Business Name', Icons.storefront),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: FuturisticColors.primary),
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));

    if (confirmed == true) {
      try {
        await _repo.updateOwnerDetails(widget.licenseKey,
          ownerName: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
          ownerEmail: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
          ownerPhone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
          businessName: bizCtrl.text.trim().isEmpty ? null : bizCtrl.text.trim(),
        );
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Owner updated'), backgroundColor: FuturisticColors.success));
        _loadDetails();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: FuturisticColors.error));
      }
    }
    nameCtrl.dispose(); emailCtrl.dispose(); phoneCtrl.dispose(); bizCtrl.dispose();
  }

  Widget _dialogTextField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: FuturisticColors.textPrimary),
      decoration: InputDecoration(
        labelText: label, labelStyle: TextStyle(color: FuturisticColors.textSecondary),
        prefixIcon: Icon(icon, size: 18, color: FuturisticColors.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: FuturisticColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: FuturisticColors.primary)),
        isDense: true,
      ),
    );
  }
}
