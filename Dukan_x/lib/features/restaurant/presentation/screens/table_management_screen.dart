// ============================================================================
// TABLE MANAGEMENT SCREEN (VENDOR) - PREMIUM FUTURISTIC UI
// ============================================================================
// All existing functionality preserved:
// - Add/Edit/Delete tables, Bulk add
// - Table status management (Available/Occupied/Reserved/Cleaning)
// - QR code generation and printing
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../data/models/restaurant_table_model.dart';
import '../../data/repositories/restaurant_table_repository.dart';
import '../../../../providers/app_state_providers.dart';
import '../../domain/services/qr_code_service.dart';
import '../widgets/table_qr_code_widget.dart'; // Contains TableQrCodeDialog & BulkQrCodePrinter
import 'customer/customer_menu_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class TableManagementScreen extends ConsumerStatefulWidget {
  final String vendorId;

  const TableManagementScreen({super.key, required this.vendorId});

  @override
  ConsumerState<TableManagementScreen> createState() =>
      _TableManagementScreenState();
}

class _TableManagementScreenState extends ConsumerState<TableManagementScreen> {
  final RestaurantTableRepository _tableRepo = RestaurantTableRepository();
  final QrCodeService _qrService = QrCodeService();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? FuturisticColors.darkBackground
          : FuturisticColors.background,
      appBar: _buildPremiumAppBar(context, isDark),
      body: BoundedBox(
        maxWidth: 800,
        child: StreamBuilder<List<RestaurantTable>>(
          stream: _tableRepo.watchTables(widget.vendorId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    FuturisticColors.primary,
                  ),
                ),
              );
            }

            final tables = snapshot.data ?? [];

            if (tables.isEmpty) {
              return _buildEmptyState(isDark);
            }

            return GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 0.85,
              ),
              itemCount: tables.length,
              itemBuilder: (context, index) =>
                  _buildTableCard(tables[index], isDark),
            );
          },
        ),
      ),

      floatingActionButton: _buildPremiumFAB(),
    );
  }

  PreferredSizeWidget _buildPremiumAppBar(BuildContext context, bool isDark) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(
                  colors: [
                    FuturisticColors.darkSurface,
                    FuturisticColors.darkBackground,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : LinearGradient(
                  colors: [
                    FuturisticColors.surface,
                    FuturisticColors.background,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppGradients.secondaryGradient,
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              boxShadow: AppShadows.glowShadow(FuturisticColors.secondary),
            ),
            child: const Icon(
              Icons.table_restaurant,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'Table Management',
            style: AppTypography.headlineMedium.copyWith(
              color: isDark
                  ? FuturisticColors.darkTextPrimary
                  : FuturisticColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: [
        _buildAppBarAction(
          icon: Icons.add,
          onPressed: _showAddTableDialog,
          isDark: isDark,
          tooltip: 'Add Table',
        ),
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: isDark
                ? FuturisticColors.darkTextSecondary
                : FuturisticColors.textSecondary,
          ),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            _buildPopupMenuItem(
              value: 'bulk_add',
              icon: Icons.grid_view,
              title: 'Bulk Add Tables',
              color: FuturisticColors.secondary,
            ),
            _buildPopupMenuItem(
              value: 'generate_all_qr',
              icon: Icons.qr_code_scanner,
              title: 'Generate All QR',
              color: FuturisticColors.primary,
            ),
            _buildPopupMenuItem(
              value: 'print_all_qr',
              icon: Icons.print,
              title: 'Print All QR',
              color: FuturisticColors.accent2,
            ),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isDark,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          margin: const EdgeInsets.only(right: AppSpacing.sm),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: FuturisticColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            border: Border.all(
              color: FuturisticColors.primary.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Icon(icon, color: FuturisticColors.primary, size: 22),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem({
    required String value,
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppBorderRadius.sm),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(title, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildPremiumFAB() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.primaryGradient,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        boxShadow: AppShadows.glowShadow(FuturisticColors.primary),
      ),
      child: FloatingActionButton.extended(
        onPressed: _showAddTableDialog,
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Table',
          style: AppTypography.labelLarge.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: GlassContainer(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        borderRadius: AppBorderRadius.xxl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: AppGradients.secondaryGradient,
                shape: BoxShape.circle,
                boxShadow: AppShadows.glowShadow(FuturisticColors.secondary),
              ),
              child: const Icon(
                Icons.table_restaurant_outlined,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No tables configured',
              style: AppTypography.headlineMedium.copyWith(
                color: isDark
                    ? FuturisticColors.darkTextPrimary
                    : FuturisticColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add tables to start managing your restaurant floor',
              style: AppTypography.bodyMedium.copyWith(
                color: isDark
                    ? FuturisticColors.darkTextSecondary
                    : FuturisticColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            GlassButton(
              label: 'Bulk Add Tables',
              icon: Icons.grid_view,
              gradient: AppGradients.secondaryGradient,
              onPressed: _showBulkAddDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCard(RestaurantTable table, bool isDark) {
    final statusColor = _getStatusColor(table.status);
    final statusIcon = _getStatusIcon(table.status);
    final statusGradient = _getStatusGradient(table.status);

    return ModernCard(
      backgroundColor: isDark
          ? FuturisticColors.darkSurface
          : FuturisticColors.surface,
      onTap: () => _showTableActions(table),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Status header with gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              gradient: statusGradient,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppBorderRadius.xl),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(statusIcon, size: 14, color: Colors.white),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  table.status.displayName,
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Table info
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.table_restaurant,
                      size: 32,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Table ${table.tableNumber}',
                    style: AppTypography.labelLarge.copyWith(
                      color: isDark
                          ? FuturisticColors.darkTextPrimary
                          : FuturisticColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (table.section != null)
                    Text(
                      table.section!,
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark
                            ? FuturisticColors.darkTextSecondary
                            : FuturisticColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people,
                        size: 14,
                        color: isDark
                            ? FuturisticColors.darkTextSecondary
                            : FuturisticColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${table.capacity}',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark
                              ? FuturisticColors.darkTextSecondary
                              : FuturisticColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // QR status
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? FuturisticColors.darkDivider
                      : FuturisticColors.divider,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  table.qrCodeId != null
                      ? Icons.qr_code_2
                      : Icons.qr_code_scanner,
                  size: 14,
                  color: table.qrCodeId != null
                      ? FuturisticColors.success
                      : FuturisticColors.textHint,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  table.qrCodeId != null ? 'QR Ready' : 'No QR',
                  style: AppTypography.labelSmall.copyWith(
                    color: table.qrCodeId != null
                        ? FuturisticColors.success
                        : FuturisticColors.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return FuturisticColors.success;
      case TableStatus.occupied:
        return FuturisticColors.error;
      case TableStatus.reserved:
        return FuturisticColors.warning;
      case TableStatus.cleaning:
        return FuturisticColors.accent2;
    }
  }

  Gradient _getStatusGradient(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return AppGradients.primaryGradient;
      case TableStatus.occupied:
        return AppGradients.accentGradient;
      case TableStatus.reserved:
        return const LinearGradient(
          colors: [Color(0xFFFFD600), Color(0xFFFF9800)],
        );
      case TableStatus.cleaning:
        return AppGradients.secondaryGradient;
    }
  }

  IconData _getStatusIcon(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return Icons.check_circle;
      case TableStatus.occupied:
        return Icons.people;
      case TableStatus.reserved:
        return Icons.schedule;
      case TableStatus.cleaning:
        return Icons.cleaning_services;
    }
  }

  void _showTableActions(RestaurantTable table) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text('Table ${table.tableNumber}'),
              subtitle: Text(
                'Capacity: ${table.capacity} • ${table.status.displayName}',
              ),
            ),
            const Divider(height: 1),
            // Take Order (New connectivity feature)
            ListTile(
              leading: const Icon(
                Icons.restaurant_menu,
                color: FuturisticColors.primary,
              ),
              title: const Text(
                'Take Order',
                style: TextStyle(
                  color: FuturisticColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _navigateToMenu(table);
              },
            ),
            const Divider(height: 1),
            // Status actions
            if (table.status != TableStatus.available)
              ListTile(
                leading: const Icon(
                  Icons.check_circle,
                  color: FuturisticColors.success,
                ),
                title: const Text('Mark Available'),
                onTap: () {
                  Navigator.pop(context);
                  _updateTableStatus(table.id, TableStatus.available);
                },
              ),
            if (table.status != TableStatus.occupied)
              ListTile(
                leading: const Icon(
                  Icons.people,
                  color: FuturisticColors.error,
                ),
                title: const Text('Mark Occupied'),
                onTap: () {
                  Navigator.pop(context);
                  _updateTableStatus(table.id, TableStatus.occupied);
                },
              ),
            if (table.status != TableStatus.reserved)
              ListTile(
                leading: const Icon(Icons.schedule, color: Colors.orange),
                title: const Text('Mark Reserved'),
                onTap: () {
                  Navigator.pop(context);
                  _updateTableStatus(table.id, TableStatus.reserved);
                },
              ),
            if (table.status != TableStatus.cleaning)
              ListTile(
                leading: const Icon(
                  Icons.cleaning_services,
                  color: Colors.blue,
                ),
                title: const Text('Mark Cleaning'),
                onTap: () {
                  Navigator.pop(context);
                  _updateTableStatus(table.id, TableStatus.cleaning);
                },
              ),
            const Divider(height: 1),
            // QR Code
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: Text(
                table.qrCodeId != null ? 'View QR Code' : 'Generate QR Code',
              ),
              onTap: () {
                Navigator.pop(context);
                _handleQrCode(table);
              },
            ),
            // Edit
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Table'),
              onTap: () {
                Navigator.pop(context);
                _showEditTableDialog(table);
              },
            ),
            // Delete
            ListTile(
              leading: const Icon(Icons.delete, color: FuturisticColors.error),
              title: const Text(
                'Delete Table',
                style: TextStyle(color: FuturisticColors.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteTable(table);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateTableStatus(String tableId, TableStatus status) async {
    await _tableRepo.updateTableStatus(tableId, status);
  }

  Future<void> _handleQrCode(RestaurantTable table) async {
    // Get restaurant name
    final authState = ref.read(authStateProvider);
    final restaurantName = authState.session?.displayName ?? 'Restaurant';

    if (table.qrCodeId != null) {
      // Show existing QR
      if (mounted) {
        TableQrCodeDialog.show(
          context,
          table: table,
          restaurantName: restaurantName,
        );
      }
    } else {
      // Generate new QR
      await _qrService.generateTableQrCode(
        widget.vendorId,
        table.id,
        table.tableNumber,
      );
      if (mounted) {
        TableQrCodeDialog.show(
          context,
          table: table,
          restaurantName: restaurantName,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('QR Code generated!')));
      }
    }
  }

  /* REMOVED OLD DIALOG METHOD */

  void _showAddTableDialog() {
    final formKey = GlobalKey<FormState>();
    final numberController = TextEditingController();
    final capacityController = TextEditingController(text: '4');
    final sectionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Table'),
        content: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: numberController,
                decoration: const InputDecoration(
                  labelText: 'Table Number',
                  hintText: 'e.g., 1, A1, VIP-1',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter table number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Capacity',
                  hintText: 'Number of seats (1-50)',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  final capacity = int.tryParse(value);
                  if (capacity == null) {
                    return 'Enter a valid number';
                  }
                  if (capacity < 1 || capacity > 50) {
                    return 'Capacity must be between 1 and 50';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: sectionController,
                decoration: const InputDecoration(
                  labelText: 'Section (optional)',
                  hintText: 'e.g., Outdoor, VIP, Main Hall',
                ),
              ),
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
              if (!formKey.currentState!.validate()) {
                return;
              }

              await _tableRepo.createTable(
                vendorId: widget.vendorId,
                tableNumber: numberController.text,
                capacity: int.parse(capacityController.text),
                section: sectionController.text.isEmpty
                    ? null
                    : sectionController.text,
              );

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Table added!')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditTableDialog(RestaurantTable table) {
    final formKey = GlobalKey<FormState>();
    final numberController = TextEditingController(text: table.tableNumber);
    final capacityController = TextEditingController(
      text: table.capacity.toString(),
    );
    final sectionController = TextEditingController(text: table.section ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Table'),
        content: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: numberController,
                decoration: const InputDecoration(labelText: 'Table Number'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter table number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Capacity',
                  hintText: 'Seats (1-50)',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  final capacity = int.tryParse(value);
                  if (capacity == null) {
                    return 'Enter a valid number';
                  }
                  if (capacity < 1 || capacity > 50) {
                    return 'Capacity must be between 1 and 50';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: sectionController,
                decoration: const InputDecoration(
                  labelText: 'Section (optional)',
                ),
              ),
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
              if (!formKey.currentState!.validate()) {
                return;
              }

              await _tableRepo.updateTable(
                id: table.id,
                tableNumber: numberController.text,
                capacity: int.parse(capacityController.text),
                section: sectionController.text.isEmpty
                    ? null
                    : sectionController.text,
              );

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Table updated!')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showBulkAddDialog() {
    final formKey = GlobalKey<FormState>();
    final countController = TextEditingController(text: '10');
    final startController = TextEditingController(text: '1');
    final capacityController = TextEditingController(text: '4');
    final sectionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Bulk Add Tables'),
              content: Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: countController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Number of Tables',
                        hintText: 'How many tables to create',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final count = int.tryParse(value);
                        if (count == null) {
                          return 'Enter a valid number';
                        }
                        if (count <= 0 || count > 100) {
                          return 'Enter between 1 and 100';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: startController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Starting Number',
                        hintText: 'e.g., 1 for Table 1, 2, 3...',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final start = int.tryParse(value);
                        if (start == null) {
                          return 'Enter a valid number';
                        }
                        if (start < 1) {
                          return 'Must be at least 1';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: capacityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Default Capacity',
                        hintText: 'Seats per table (1-50)',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final capacity = int.tryParse(value);
                        if (capacity == null) {
                          return 'Enter a valid number';
                        }
                        if (capacity < 1 || capacity > 50) {
                          return 'Capacity must be between 1 and 50';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: sectionController,
                      decoration: const InputDecoration(
                        labelText: 'Section (optional)',
                      ),
                    ),
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
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    final count = int.parse(countController.text);
                    final start = int.parse(startController.text);
                    final capacity = int.parse(capacityController.text);

                    await _tableRepo.createMultipleTables(
                      vendorId: widget.vendorId,
                      count: count,
                      startNumber: start,
                      capacity: capacity,
                      section: sectionController.text.isEmpty
                          ? null
                          : sectionController.text,
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$count tables created!')),
                      );
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteTable(RestaurantTable table) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Table?'),
        content: Text(
          'Are you sure you want to delete Table ${table.tableNumber}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FuturisticColors.error,
            ),
            onPressed: () async {
              await _tableRepo.deleteTable(table.id);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Table deleted')));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'bulk_add':
        _showBulkAddDialog();
        break;
      case 'generate_all_qr':
        _generateAllQrCodes();
        break;
      case 'print_all_qr':
        _printAllQrCodes();
        break;
    }
  }

  Future<void> _generateAllQrCodes() async {
    final result = await _tableRepo.getTablesByVendor(widget.vendorId);
    if (!result.success || result.data == null) return;

    final tables = result.data!;
    int generated = 0;

    for (final table in tables) {
      if (table.qrCodeId == null) {
        await _qrService.generateTableQrCode(
          widget.vendorId,
          table.id,
          table.tableNumber,
        );
        generated++;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Generated $generated QR codes')));
    }
  }

  Future<void> _printAllQrCodes() async {
    final result = await _tableRepo.getTablesByVendor(widget.vendorId);
    if (!result.success || result.data == null) return;
    final tables = result.data!;

    if (tables.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No tables to print')));
      return;
    }

    // Get restaurant name
    // Get restaurant name
    final authState = ref.read(authStateProvider);
    final restaurantName = authState.session?.displayName ?? 'Restaurant';

    await BulkQrCodePrinter.printAllTableQrCodes(
      tables: tables,
      restaurantName: restaurantName,
    );
  }

  void _navigateToMenu(RestaurantTable table) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerMenuScreen(
          vendorId: widget.vendorId,
          tableId: table.id,
          tableNumber: table.tableNumber,
          customerId: 'WAITER', // Indicates staff-placed order
        ),
      ),
    );
  }
}
