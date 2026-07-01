// ============================================================================
// DECORATION & CATERING — STAFF & VENDOR MANAGEMENT SCREEN
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/dc_models.dart';
import '../../data/repositories/dc_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DcStaffScreen extends ConsumerStatefulWidget {
  const DcStaffScreen({super.key});

  @override
  ConsumerState<DcStaffScreen> createState() => _DcStaffScreenState();
}

class _DcStaffScreenState extends ConsumerState<DcStaffScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  StaffRole? _roleFilter;
  String _staffSearch = '';
  String _vendorSearch = '';

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
          children: [
            _buildHeader(context),
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabs,
                labelColor: const Color(0xFF059669),
                unselectedLabelColor: const Color(0xFF6B7280),
                indicatorColor: const Color(0xFF059669),
                tabs: const [
                  Tab(text: 'Staff & Workers'),
                  Tab(text: 'Vendors'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _StaffTab(
                    roleFilter: _roleFilter,
                    search: _staffSearch,
                    onRoleFilter: (r) => setState(() => _roleFilter = r),
                    onSearch: (s) => setState(() => _staffSearch = s),
                  ),
                  _VendorTab(
                    search: _vendorSearch,
                    onSearch: (s) => setState(() => _vendorSearch = s),
                  ),
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
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
      ),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Staff & Vendor Management',
                style: TextStyle(
                  fontSize: responsiveValue<double>(
                    context,
                    mobile: 18,
                    tablet: 20,
                    desktop: 22,
                  ),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Workforce and supplier management',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _addVendorDialog(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Vendor'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF059669),
                  side: const BorderSide(color: Color(0xFF059669)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _addStaffDialog(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Staff'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addStaffDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final wageCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    StaffRole role = StaffRole.helper;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Row(
            children: [
              Icon(Icons.person_add_rounded, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Text('Add Staff Member'),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(nameCtrl, 'Full Name'),
                const SizedBox(height: 12),
                _field(phoneCtrl, 'Phone', keyboard: TextInputType.phone),
                const SizedBox(height: 12),
                DropdownButtonFormField<StaffRole>(
                  value: role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: StaffRole.values.map((r) {
                    final dummy = DcStaff(
                      id: '',
                      name: '',
                      phone: '',
                      role: r,
                      dailyWage: 0,
                    );
                    return DropdownMenuItem(
                      value: r,
                      child: Text(dummy.roleLabel),
                    );
                  }).toList(),
                  onChanged: (v) => setS(() => role = v!),
                ),
                const SizedBox(height: 12),
                _field(
                  wageCtrl,
                  'Daily Wage (₹)',
                  keyboard: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _field(addrCtrl, 'Address (optional)'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                await ref
                    .read(dcRepositoryProvider)
                    .createStaff(
                      DcStaff(
                        id: 'S${DateTime.now().millisecondsSinceEpoch}',
                        name: nameCtrl.text,
                        phone: phoneCtrl.text,
                        role: role,
                        dailyWage: double.tryParse(wageCtrl.text) ?? 0,
                        address: addrCtrl.text,
                        joinDate: DateTime.now(),
                      ),
                    );
                ref.invalidate(dcStaffProvider);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Staff'),
            ),
          ],
        ),
      ),
    );
  }

  void _addVendorDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.store_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Add Vendor'),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(nameCtrl, 'Vendor Name'),
              const SizedBox(height: 12),
              _field(phoneCtrl, 'Phone', keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _field(
                emailCtrl,
                'Email (optional)',
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _field(categoryCtrl, 'Category (e.g. Flowers, Tent)'),
              const SizedBox(height: 12),
              _field(addrCtrl, 'Address (optional)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              await ref
                  .read(dcRepositoryProvider)
                  .createVendor(
                    DcVendor(
                      id: 'V${DateTime.now().millisecondsSinceEpoch}',
                      name: nameCtrl.text,
                      phone: phoneCtrl.text,
                      email: emailCtrl.text.isEmpty ? null : emailCtrl.text,
                      category: categoryCtrl.text,
                      address: addrCtrl.text.isEmpty ? null : addrCtrl.text,
                      createdAt: DateTime.now(),
                    ),
                  );
              ref.invalidate(dcVendorsProvider);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Vendor'),
          ),
        ],
      ),
    );
  }

  TextField _field(
    TextEditingController ctrl,
    String label, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Staff Tab
// ---------------------------------------------------------------------------
class _StaffTab extends ConsumerWidget {
  final StaffRole? roleFilter;
  final String search;
  final ValueChanged<StaffRole?> onRoleFilter;
  final ValueChanged<String> onSearch;

  const _StaffTab({
    required this.roleFilter,
    required this.search,
    required this.onRoleFilter,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(dcStaffProvider);
    return staffAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (staff) {
        var filtered = staff;
        if (roleFilter != null)
          filtered = filtered.where((s) => s.role == roleFilter).toList();
        if (search.isNotEmpty) {
          final q = search.toLowerCase();
          filtered = filtered
              .where((s) => s.name.toLowerCase().contains(q))
              .toList();
        }

        return Column(
          children: [
            _buildFilters(staff),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No staff found'))
                  : GridView.builder(
                      padding: EdgeInsets.all(
                        responsiveValue<double>(
                          context,
                          mobile: 16,
                          tablet: 20,
                          desktop: 24,
                        ),
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 260,
                            mainAxisExtent: 160,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) => _StaffCard(
                        staff: filtered[i],
                        onDelete: () async {
                          await ref
                              .read(dcRepositoryProvider)
                              .deleteStaff(filtered[i].id);
                          ref.invalidate(dcStaffProvider);
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilters(List<DcStaff> all) {
    final roles = [null, ...StaffRole.values];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            height: 36,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search staff...',
                prefixIcon: const Icon(Icons.search, size: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
              ),
              onChanged: onSearch,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: roles.map((r) {
                  final label = r == null
                      ? 'All'
                      : DcStaff(
                          id: '',
                          name: '',
                          phone: '',
                          role: r,
                          dailyWage: 0,
                        ).roleLabel;
                  final color = r == null
                      ? const Color(0xFF6B7280)
                      : DcStaff(
                          id: '',
                          name: '',
                          phone: '',
                          role: r,
                          dailyWage: 0,
                        ).roleColor;
                  final selected = roleFilter == r;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) => onRoleFilter(r),
                      selectedColor: color.withValues(alpha: 0.15),
                      checkmarkColor: color,
                      labelStyle: TextStyle(
                        color: selected ? color : const Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: selected ? color : const Color(0xFFE5E7EB),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final DcStaff staff;
  final VoidCallback onDelete;
  const _StaffCard({required this.staff, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: staff.roleColor.withValues(alpha: 0.15),
                child: Text(
                  staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: staff.roleColor,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      staff.phone,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: Color(0xFF9CA3AF),
                ),
                onPressed: onDelete,
                tooltip: 'Delete staff member',
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: staff.roleColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  staff.roleLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: staff.roleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: staff.isAvailable ? Colors.green : Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                staff.isAvailable ? 'Available' : 'Busy',
                style: TextStyle(
                  fontSize: 10,
                  color: staff.isAvailable ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.currency_rupee_rounded,
                size: 12,
                color: Color(0xFF6B7280),
              ),
              Text(
                '${staff.dailyWage.toStringAsFixed(0)}/day',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF374151),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vendor Tab
// ---------------------------------------------------------------------------
class _VendorTab extends ConsumerWidget {
  final String search;
  final ValueChanged<String> onSearch;
  const _VendorTab({required this.search, required this.onSearch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorsAsync = ref.watch(dcVendorsProvider);
    return vendorsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (vendors) {
        final filtered = search.isEmpty
            ? vendors
            : vendors
                  .where(
                    (v) =>
                        v.name.toLowerCase().contains(search.toLowerCase()) ||
                        v.category.toLowerCase().contains(search.toLowerCase()),
                  )
                  .toList();
        return Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: SizedBox(
                width: 280,
                height: 36,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search vendors...',
                    prefixIcon: const Icon(Icons.search, size: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                  ),
                  onChanged: onSearch,
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No vendors found'))
                  : ListView.separated(
                      padding: EdgeInsets.all(
                        responsiveValue<double>(
                          context,
                          mobile: 16,
                          tablet: 20,
                          desktop: 24,
                        ),
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) => _VendorCard(
                        vendor: filtered[i],
                        onDelete: () async {
                          await ref
                              .read(dcRepositoryProvider)
                              .deleteVendor(filtered[i].id);
                          ref.invalidate(dcVendorsProvider);
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _VendorCard extends StatelessWidget {
  final DcVendor vendor;
  final VoidCallback onDelete;
  const _VendorCard({required this.vendor, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
            child: Text(
              vendor.name[0].toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF2563EB),
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      vendor.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        vendor.category,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      vendor.phone,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    if (vendor.email != null) ...[
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.email_outlined,
                        size: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        vendor.email!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  _Star(rating: vendor.rating),
                  const SizedBox(width: 4),
                  Text(
                    vendor.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Paid: ₹${(vendor.totalPaid / 1000).toStringAsFixed(1)}K',
                style: const TextStyle(fontSize: 11, color: Color(0xFF059669)),
              ),
              if (vendor.totalDue > 0)
                Text(
                  'Due: ₹${(vendor.totalDue / 1000).toStringAsFixed(1)}K',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFDC2626),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Color(0xFF9CA3AF),
              size: 18,
            ),
            onPressed: onDelete,
            tooltip: 'Delete vendor',
          ),
        ],
      ),
    );
  }
}

class _Star extends StatelessWidget {
  final double rating;
  const _Star({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating.floor()
              ? Icons.star_rounded
              : (i < rating
                    ? Icons.star_half_rounded
                    : Icons.star_border_rounded),
          color: Colors.amber,
          size: 14,
        ),
      ),
    );
  }
}
