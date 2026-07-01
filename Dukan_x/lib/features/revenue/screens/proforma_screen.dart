// Proforma & Bids Screen - Create estimates and convert to invoices
//
// Author: DukanX Team
// Created: 2024-12-25

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/app_state_providers.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/session/session_manager.dart';
import '../../../widgets/glass_morphism.dart';
import '../models/revenue_models.dart';
import '../services/revenue_service.dart';
import '../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import 'package:dukanx/widgets/responsive/overflow_safe.dart';

class ProformaScreen extends ConsumerStatefulWidget {
  const ProformaScreen({super.key});

  @override
  ConsumerState<ProformaScreen> createState() => _ProformaScreenState();
}

class _ProformaScreenState extends ConsumerState<ProformaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _revenueService = RevenueService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;
    final ownerId = sl<SessionManager>().ownerId ?? '';

    return DesktopContentContainer(
      title: 'Proforma & Estimates',
      showScrollbar: false, // Handle scrolling in TabBarView
      actions: [
        DesktopActionButton(
          icon: Icons.add,
          label: 'New Estimate',
          onPressed: () => _showAddProformaSheet(context, ownerId),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Custom Tab Bar
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF8B5CF6), // Purple
              unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
              indicatorColor: const Color(0xFF8B5CF6),
              tabs: const [
                Tab(text: 'Active'),
                Tab(text: 'Converted'),
                Tab(text: 'Expired'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ProformaListView(
                  ownerId: ownerId,
                  statuses: const [
                    ProformaStatus.draft,
                    ProformaStatus.sent,
                    ProformaStatus.accepted,
                  ],
                  isDark: isDark,
                  onConvert: _handleConvert,
                ),
                _ProformaListView(
                  ownerId: ownerId,
                  statuses: const [ProformaStatus.converted],
                  isDark: isDark,
                  onConvert: _handleConvert,
                ),
                _ProformaListView(
                  ownerId: ownerId,
                  statuses: const [
                    ProformaStatus.expired,
                    ProformaStatus.rejected,
                  ],
                  isDark: isDark,
                  onConvert: _handleConvert,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConvert(String proformaId) async {
    final ownerId = sl<SessionManager>().ownerId!;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Convert to Invoice?'),
        content: Text(
          'This will create a new invoice from this estimate and mark it as converted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Convert'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _revenueService.convertProformaToInvoice(ownerId, proformaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estimate converted to Invoice!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddProformaSheet(BuildContext context, String ownerId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _AddProformaScreen(ownerId: ownerId)),
    );
  }
}

class _ProformaListView extends StatelessWidget {
  final String ownerId;
  final List<ProformaStatus> statuses;
  final bool isDark;
  final Function(String) onConvert;

  const _ProformaListView({
    required this.ownerId,
    required this.statuses,
    required this.isDark,
    required this.onConvert,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProformaInvoice>>(
      stream: RevenueService().streamProformas(ownerId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final proformas = snapshot.data!
            .where((p) => statuses.contains(p.status))
            .toList();

        if (proformas.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: responsiveValue<double>(
                    context,
                    mobile: 48,
                    tablet: 56,
                    desktop: 64,
                  ),
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No estimates in this category',
                  style: TextStyle(
                    fontSize: responsiveValue<double>(
                      context,
                      mobile: 14,
                      tablet: 16,
                      desktop: 18,
                    ),
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(
            responsiveValue<double>(
              context,
              mobile: 12,
              tablet: 16,
              desktop: 16,
            ),
          ),
          itemCount: proformas.length,
          itemBuilder: (context, index) {
            final proforma = proformas[index];
            return _ProformaCard(
              proforma: proforma,
              isDark: isDark,
              onConvert: onConvert,
            );
          },
        );
      },
    );
  }
}

class _ProformaCard extends StatelessWidget {
  final ProformaInvoice proforma;
  final bool isDark;
  final Function(String) onConvert;

  const _ProformaCard({
    required this.proforma,
    required this.isDark,
    required this.onConvert,
  });

  Color _getStatusColor() {
    switch (proforma.status) {
      case ProformaStatus.draft:
        return Colors.grey;
      case ProformaStatus.sent:
        return Colors.blue;
      case ProformaStatus.accepted:
        return Colors.green;
      case ProformaStatus.rejected:
        return Colors.red;
      case ProformaStatus.converted:
        return Colors.teal;
      case ProformaStatus.expired:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20B9',
      decimalDigits: 0,
    );
    final isExpiringSoon =
        proforma.validUntil.difference(DateTime.now()).inDays <= 3 &&
        proforma.status != ProformaStatus.converted &&
        proforma.status != ProformaStatus.expired;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.description,
                      color: Colors.purple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proforma.proformaNumber,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        proforma.customerName,
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  proforma.status.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Validity — stack vertically on mobile to prevent label/value overlap
          context.isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.event,
                          size: 18,
                          color: isExpiringSoon ? Colors.orange : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Valid until:',
                          style: TextStyle(
                            color: isExpiringSoon
                                ? Colors.orange
                                : (isDark ? Colors.white70 : Colors.black54),
                            fontWeight: isExpiringSoon
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 26),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              dateFormat.format(proforma.validUntil),
                              style: TextStyle(
                                color: isExpiringSoon
                                    ? Colors.orange
                                    : (isDark
                                          ? Colors.white70
                                          : Colors.black54),
                                fontWeight: isExpiringSoon
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isExpiringSoon) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'EXPIRING SOON',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      Icons.event,
                      size: 18,
                      color: isExpiringSoon ? Colors.orange : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Valid until: ${dateFormat.format(proforma.validUntil)}',
                      style: TextStyle(
                        color: isExpiringSoon
                            ? Colors.orange
                            : (isDark ? Colors.white70 : Colors.black54),
                        fontWeight: isExpiringSoon
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (isExpiringSoon) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'EXPIRING SOON',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
          const SizedBox(height: 12),

          // Items count
          Text(
            '${proforma.items.length} items',
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
          ),
          const Divider(height: 24),

          // Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currencyFormat.format(proforma.totalAmount),
                    style: TextStyle(
                      fontSize: responsiveValue<double>(
                        context,
                        mobile: 18,
                        tablet: 20,
                        desktop: 22,
                      ),
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (proforma.discountAmount > 0)
                    Text(
                      'Discount: ${currencyFormat.format(proforma.discountAmount)}',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                ],
              ),
              // Convert button
              if (proforma.status == ProformaStatus.accepted ||
                  proforma.status == ProformaStatus.sent ||
                  proforma.status == ProformaStatus.draft)
                ElevatedButton.icon(
                  onPressed: () => onConvert(proforma.id),
                  icon: Icon(Icons.transform, size: 18),
                  label: Text('Convert'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),

          // Notes
          if (proforma.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.note, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      proforma.notes,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Add Proforma Screen
class _AddProformaScreen extends ConsumerStatefulWidget {
  final String ownerId;

  const _AddProformaScreen({required this.ownerId});

  @override
  ConsumerState<_AddProformaScreen> createState() => _AddProformaScreenState();
}

class _AddProformaScreenState extends ConsumerState<_AddProformaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _revenueService = RevenueService();

  final _customerNameController = TextEditingController();
  final _termsController = TextEditingController(
    text: 'Prices valid for 30 days from date of estimate.',
  );
  final _notesController = TextEditingController();
  final _discountController = TextEditingController(text: '0');

  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  final List<ProformaItem> _items = [];
  bool _isSaving = false;

  double get _subtotal => _items.fold(0, (sum, item) => sum + item.amount);
  double get _discount => double.tryParse(_discountController.text) ?? 0;
  double get _totalAmount => _subtotal - _discount;

  @override
  void dispose() {
    _customerNameController.dispose();
    _termsController.dispose();
    _notesController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return DesktopContentContainer(
      title: 'New Estimate',
      child: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 900;
            if (isDesktop) {
              return Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column
                        Expanded(
                          flex: 6,
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildCustomerCard(isDark),
                                const SizedBox(height: 16),
                                _buildItemsCard(isDark),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right Column
                        Expanded(
                          flex: 4,
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildSummaryCard(isDark),
                                const SizedBox(height: 16),
                                _buildValidityCard(isDark),
                                const SizedBox(height: 16),
                                _buildTermsNotesCard(isDark),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                  const SizedBox(height: 16),
                ],
              );
            }

            // Mobile Layout
            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildCustomerCard(isDark),
                  const SizedBox(height: 16),
                  _buildValidityCard(isDark),
                  const SizedBox(height: 16),
                  _buildItemsCard(isDark),
                  const SizedBox(height: 16),
                  _buildSummaryCard(isDark),
                  const SizedBox(height: 16),
                  _buildTermsNotesCard(isDark),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCustomerCard(bool isDark) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerNameController,
            decoration: InputDecoration(
              labelText: 'Customer Name *',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (val) => val?.isEmpty == true ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildValidityCard(bool isDark) {
    return GlassCard(
      child: InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _validUntil,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (date != null) {
            setState(() => _validUntil = date);
          }
        },
        child: context.isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event, color: Colors.purple),
                      const SizedBox(width: 12),
                      Text(
                        'Valid Until',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.edit, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: Text(
                      DateFormat('dd MMM yyyy').format(_validUntil),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  const Icon(Icons.event, color: Colors.purple),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Valid Until',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          DateFormat('dd MMM yyyy').format(_validUntil),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit, color: Colors.grey),
                ],
              ),
      ),
    );
  }

  Widget _buildItemsCard(bool isDark) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAddItemDialog(isDark),
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
            ],
          ),
          if (_items.isEmpty)
            Padding(
              padding: EdgeInsets.all(
                responsiveValue<double>(
                  context,
                  mobile: 16,
                  tablet: 20,
                  desktop: 24,
                ),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2,
                      size: responsiveValue<double>(
                        context,
                        mobile: 40,
                        tablet: 48,
                        desktop: 48,
                      ),
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No items added',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: responsiveValue<double>(
                          context,
                          mobile: 14,
                          tablet: 16,
                          desktop: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...List.generate(_items.length, (index) {
              final item = _items[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  item.itemName,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  '${item.quantity.toStringAsFixed(0)} ${item.unit} \u00D7 \u20B9${item.rate.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '\u20B9${item.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _items.removeAt(index)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    return GlassCard(
      child: Column(
        children: [
          OverflowSafeLabelValueRow(
            label: 'Subtotal',
            value: '\u20B9${_subtotal.toStringAsFixed(0)}',
            labelStyle: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
            ),
            valueStyle: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          OverflowSafeLabelValueRow(
            label: 'Discount',
            labelStyle: const TextStyle(color: Colors.green),
            // The 100px-wide input is handed to the value slot, which the
            // shared widget already wraps in a [Flexible] so it stays
            // overflow-safe and can shrink on very narrow viewports.
            valueOverride: SizedBox(
              width: 100,
              child: TextFormField(
                controller: _discountController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixText: '- \u20B9',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 24),
          OverflowSafeLabelValueRow(
            label: 'Total',
            value: '\u20B9${_totalAmount.toStringAsFixed(0)}',
            labelStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            valueStyle: TextStyle(
              fontSize: responsiveValue<double>(
                context,
                mobile: 18,
                tablet: 20,
                desktop: 24,
              ),
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsNotesCard(bool isDark) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Terms & Conditions',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _termsController,
            maxLines: 2,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Notes',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Additional notes...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _items.isNotEmpty && !_isSaving ? _saveProforma : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save),
                  const SizedBox(width: 8),
                  const Text('Create Estimate', style: TextStyle(fontSize: 18)),
                ],
              ),
      ),
    );
  }

  void _showAddItemDialog(bool isDark) {
    final nameController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final rateController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Item Name'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: rateController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Rate (\u20B9)'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = double.tryParse(qtyController.text) ?? 0;
              final rate = double.tryParse(rateController.text) ?? 0;
              if (nameController.text.isNotEmpty && qty > 0 && rate > 0) {
                setState(() {
                  _items.add(
                    ProformaItem(
                      itemId: DateTime.now().millisecondsSinceEpoch.toString(),
                      itemName: nameController.text,
                      quantity: qty,
                      rate: rate,
                      amount: qty * rate,
                    ),
                  );
                });
                Navigator.pop(ctx);
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProforma() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Add at least one item')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final proforma = ProformaInvoice(
        id: '',
        ownerId: widget.ownerId,
        customerId: '',
        customerName: _customerNameController.text,
        proformaNumber: '',
        items: _items,
        subtotal: _subtotal,
        taxAmount: 0,
        discountAmount: _discount,
        totalAmount: _totalAmount,
        validUntil: _validUntil,
        status: ProformaStatus.draft,
        terms: _termsController.text,
        notes: _notesController.text,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await _revenueService.addProforma(widget.ownerId, proforma);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estimate created!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
