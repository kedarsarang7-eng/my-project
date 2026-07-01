import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../data/super_admin_repository.dart';
import 'license_detail_screen.dart';
import 'generate_license_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// License List Screen — Paginated, Filterable, Searchable
/// BUG-LIC-012: Missing screen added.
class LicenseListScreen extends StatefulWidget {
  const LicenseListScreen({super.key});

  @override
  State<LicenseListScreen> createState() => _LicenseListScreenState();
}

class _LicenseListScreenState extends State<LicenseListScreen> {
  final SuperAdminRepository _repo = SuperAdminRepository();
  List<LicenseData> _allLicenses = [];
  List<LicenseData> _filtered = [];
  bool _isLoading = true;
  String? _error;

  // Filters
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _planFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadLicenses();
  }

  Future<void> _loadLicenses() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final licenses = await _repo.listLicenses();
      setState(() {
        _allLicenses = licenses;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _applyFilters() {
    _filtered = _allLicenses.where((l) {
      // Status filter
      if (_statusFilter != 'all' && l.status.toLowerCase() != _statusFilter) return false;
      // Plan filter
      if (_planFilter != 'all' && l.plan.toLowerCase() != _planFilter) return false;
      // Search
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return (l.licenseKey.toLowerCase().contains(q)) ||
            (l.tenantId.toLowerCase().contains(q)) ||
            (l.ownerName?.toLowerCase().contains(q) ?? false) ||
            (l.ownerEmail?.toLowerCase().contains(q) ?? false) ||
            (l.ownerPhone?.toLowerCase().contains(q) ?? false) ||
            (l.tenantName?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE': case 'ACTIVATED': return FuturisticColors.success;
      case 'EXPIRED': return FuturisticColors.warning;
      case 'SUSPENDED': return const Color(0xFFF97316); // Orange
      case 'REVOKED': case 'BANNED': return FuturisticColors.error;
      case 'INACTIVE': return FuturisticColors.textDisabled;
      default: return FuturisticColors.textSecondary;
    }
  }

  Color _planColor(String plan) {
    switch (plan.toLowerCase()) {
      case 'enterprise': return const Color(0xFFA855F7); // Purple
      case 'premium': return const Color(0xFFF59E0B); // Amber
      case 'basic': return FuturisticColors.primary;
      default: return FuturisticColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FuturisticColors.background,
      appBar: AppBar(
        title: const Text('License Management'),
        backgroundColor: FuturisticColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export CSV to clipboard',
            onPressed: _filtered.isEmpty ? null : _exportCsv,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLicenses),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
        children: [
          // ── Search & Filters ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FuturisticColors.surface,
              border: Border(bottom: BorderSide(color: FuturisticColors.border)),
            ),
            child: Column(
              children: [
                // Search bar
                TextField(
                  style: TextStyle(color: FuturisticColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search by key, name, email, phone...',
                    hintStyle: TextStyle(color: FuturisticColors.textDisabled),
                    prefixIcon: Icon(Icons.search, color: FuturisticColors.textSecondary),
                    filled: true,
                    fillColor: FuturisticColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => setState(() { _searchQuery = v; _applyFilters(); }),
                ),
                const SizedBox(height: 12),
                // Filter chips row
                Row(
                  children: [
                    _buildFilterChip('Status', _statusFilter, ['all', 'active', 'expired', 'suspended', 'revoked', 'inactive'],
                      (v) => setState(() { _statusFilter = v; _applyFilters(); })),
                    const SizedBox(width: 12),
                    _buildFilterChip('Plan', _planFilter, ['all', 'basic', 'premium', 'enterprise'],
                      (v) => setState(() { _planFilter = v; _applyFilters(); })),
                    const Spacer(),
                    // Count badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: FuturisticColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${_filtered.length} licenses', style: TextStyle(color: FuturisticColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── List ──
          Expanded(child: _buildBody()),
        ],
      ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const GenerateLicenseScreen()));
          _loadLicenses(); // Refresh after returning
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Generate Key', style: TextStyle(color: Colors.white)),
        backgroundColor: FuturisticColors.primary,
      ),
    );
  }

  /// BUG-LIC-025: Export filtered licenses as CSV to clipboard
  void _exportCsv() {
    final header = 'License Key,Tenant ID,Owner,Email,Phone,Plan,Status,Business Type,Max Devices,Expiry';
    final rows = _filtered.map((l) {
      return [
        l.licenseKeyFull ?? l.licenseKey,
        l.tenantId,
        l.ownerName ?? l.tenantName ?? '-',
        l.ownerEmail ?? '-',
        l.ownerPhone ?? '-',
        l.plan,
        l.status,
        l.businessType ?? '-',
        l.maxDevices.toString(),
        l.expiryDate?.toIso8601String().split('T')[0] ?? 'Lifetime',
      ].join(',');
    }).join('\n');

    final csv = '$header\n$rows';
    Clipboard.setData(ClipboardData(text: csv));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_filtered.length} licenses exported to clipboard as CSV'),
        backgroundColor: FuturisticColors.primary,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  Widget _buildFilterChip(String label, String current, List<String> options, ValueChanged<String> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: FuturisticColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          dropdownColor: FuturisticColors.surface,
          style: TextStyle(color: FuturisticColors.textPrimary, fontSize: 13),
          icon: Icon(Icons.arrow_drop_down, color: FuturisticColors.textSecondary, size: 20),
          items: options.map((o) => DropdownMenuItem(
            value: o,
            child: Text(o == 'all' ? 'All $label' : o.toUpperCase(), style: const TextStyle(fontSize: 13)),
          )).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: FuturisticColors.primary));
    if (_error != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, color: FuturisticColors.error, size: 48),
        const SizedBox(height: 16),
        Text('Error: $_error', style: TextStyle(color: FuturisticColors.textSecondary)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _loadLicenses, child: const Text('Retry')),
      ]));
    }
    if (_filtered.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.vpn_key_off, color: FuturisticColors.textDisabled, size: 64),
        const SizedBox(height: 16),
        Text('No licenses found', style: TextStyle(color: FuturisticColors.textSecondary, fontSize: 16)),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filtered.length,
      itemBuilder: (context, index) => _buildLicenseCard(_filtered[index]),
    );
  }

  Widget _buildLicenseCard(LicenseData license) {
    final daysLeft = license.expiryDate?.difference(DateTime.now()).inDays;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => LicenseDetailScreen(licenseKey: license.licenseKeyFull ?? license.licenseKey),
        ));
        _loadLicenses();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: FuturisticColors.premiumCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Key + Status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    license.licenseKey,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.bold, color: FuturisticColors.textPrimary, letterSpacing: 1.1),
                  ),
                ),
                _buildBadge(license.status, _statusColor(license.status)),
                const SizedBox(width: 8),
                _buildBadge(license.plan, _planColor(license.plan)),
              ],
            ),
            const SizedBox(height: 12),

            // Owner info row
            Row(
              children: [
                Icon(Icons.person, size: 14, color: FuturisticColors.textSecondary),
                const SizedBox(width: 6),
                Text(license.ownerName ?? license.tenantName ?? license.tenantId,
                  style: TextStyle(color: FuturisticColors.textPrimary, fontSize: 13)),
                const SizedBox(width: 16),
                if (license.businessType != null) ...[
                  Icon(Icons.storefront, size: 14, color: FuturisticColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(license.businessType!, style: TextStyle(color: FuturisticColors.textSecondary, fontSize: 12)),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Bottom row: Expiry + devices
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: FuturisticColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  license.expiryDate != null
                      ? '${license.expiryDate!.toLocal().toString().split(' ')[0]}${daysLeft != null && daysLeft >= 0 ? ' ($daysLeft days left)' : daysLeft != null ? ' (EXPIRED)' : ''}'
                      : 'Lifetime',
                  style: TextStyle(
                    color: daysLeft != null && daysLeft < 7 ? FuturisticColors.warning : FuturisticColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Icon(Icons.devices, size: 14, color: FuturisticColors.textSecondary),
                const SizedBox(width: 4),
                Text('${license.maxDevices} device(s)', style: TextStyle(color: FuturisticColors.textSecondary, fontSize: 12)),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: FuturisticColors.textDisabled, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(text.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    );
  }
}
