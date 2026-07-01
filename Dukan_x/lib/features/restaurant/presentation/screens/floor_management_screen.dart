// ============================================================================
// RESTAURANT FLOOR MANAGEMENT SCREEN
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../data/models/restaurant_floor_model.dart';
import '../../data/repositories/restaurant_floor_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class FloorManagementScreen extends StatefulWidget {
  final String vendorId;
  const FloorManagementScreen({super.key, this.vendorId = 'SYSTEM'});
  @override
  State<FloorManagementScreen> createState() => _FloorManagementScreenState();
}

class _FloorManagementScreenState extends State<FloorManagementScreen> {
  final RestaurantFloorRepository _repo = RestaurantFloorRepository();
  final _orange = const Color(0xFFEA580C);
  String get _vendorId => widget.vendorId;

  Color _floorTypeColor(FloorType t) {
    switch (t) {
      case FloorType.ac:
        return const Color(0xFF0EA5E9);
      case FloorType.nonAc:
        return const Color(0xFFF59E0B);
      case FloorType.rooftop:
        return const Color(0xFF8B5CF6);
      case FloorType.outdoor:
        return const Color(0xFF10B981);
      case FloorType.custom:
        return const Color(0xFF6B7280);
    }
  }

  IconData _floorTypeIcon(FloorType t) {
    switch (t) {
      case FloorType.ac:
        return Icons.ac_unit;
      case FloorType.nonAc:
        return Icons.wb_sunny_outlined;
      case FloorType.rooftop:
        return Icons.roofing;
      case FloorType.outdoor:
        return Icons.park_outlined;
      case FloorType.custom:
        return Icons.grid_view_outlined;
    }
  }

  void _showAddEditDialog({RestaurantFloor? floor}) {
    final nameCtrl = TextEditingController(text: floor?.name ?? '');
    final descCtrl = TextEditingController(text: floor?.description ?? '');
    FloorType selectedType = floor?.floorType ?? FloorType.custom;
    int sortOrder = floor?.sortOrder ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) => AlertDialog(
          backgroundColor: FuturisticColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            floor == null ? 'Add Floor / Zone' : 'Edit Floor',
            style: AppTypography.headlineMedium.copyWith(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zone Type',
                  style: AppTypography.labelMedium.copyWith(
                    color: FuturisticColors.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: FloorType.values.map((t) {
                    final selected = selectedType == t;
                    final color = _floorTypeColor(t);
                    return GestureDetector(
                      onTap: () => setDS(() => selectedType = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? color.withValues(alpha: 0.2)
                              : FuturisticColors.darkSurfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? color : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _floorTypeIcon(t),
                              size: 14,
                              color: selected ? color : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              t.displayName,
                              style: TextStyle(
                                fontSize: 12,
                                color: selected ? color : Colors.grey,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _field(nameCtrl, 'Floor Name *'),
                const SizedBox(height: 12),
                _field(descCtrl, 'Description (optional)', maxLines: 2),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Sort Order: $sortOrder',
                      style: TextStyle(
                        color: FuturisticColors.darkTextSecondary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove, color: Colors.white),
                      onPressed: () =>
                          setDS(() => sortOrder = (sortOrder - 1).clamp(0, 99)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: () => setDS(() => sortOrder++),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: FuturisticColors.darkTextSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _orange),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Floor name is required')),
                  );
                  return;
                }
                if (floor == null) {
                  await _repo.createFloor(
                    vendorId: _vendorId,
                    name: nameCtrl.text.trim(),
                    floorType: selectedType,
                    description: descCtrl.text.isEmpty ? null : descCtrl.text,
                    sortOrder: sortOrder,
                  );
                } else {
                  await _repo.updateFloor(
                    id: floor.id,
                    name: nameCtrl.text.trim(),
                    floorType: selectedType,
                    description: descCtrl.text.isEmpty ? null : descCtrl.text,
                    sortOrder: sortOrder,
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(floor == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: FuturisticColors.darkTextSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _orange),
        ),
      ),
    );
  }

  void _confirmDelete(RestaurantFloor floor) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FuturisticColors.darkSurface,
        title: const Text(
          'Delete Floor?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Remove "${floor.name}"? Tables assigned to this floor won\'t be deleted.',
          style: TextStyle(color: FuturisticColors.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _repo.deleteFloor(floor.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? FuturisticColors.darkBackground
          : FuturisticColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark
            ? FuturisticColors.darkSurface
            : FuturisticColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _orange.withValues(alpha: 0.4)),
              ),
              child: Icon(Icons.layers_outlined, color: _orange, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Floor & Zone Management',
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
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Floor'),
              onPressed: () => _showAddEditDialog(),
            ),
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: StreamBuilder<List<RestaurantFloor>>(
        stream: _repo.watchFloors(_vendorId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _orange));
          }
          final floors = snapshot.data ?? [];
          if (floors.isEmpty) return _buildEmptyState(isDark);
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: floors.length,
            itemBuilder: (context, i) => _buildFloorCard(floors[i], isDark),
          );
        },
      ),
      ),
    );
  }

  Widget _buildFloorCard(RestaurantFloor floor, bool isDark) {
    final typeColor = _floorTypeColor(floor.floorType);
    final typeIcon = _floorTypeIcon(floor.floorType);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ModernCard(
        backgroundColor: isDark
            ? FuturisticColors.darkSurface
            : FuturisticColors.surface,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: typeColor.withValues(alpha: 0.3)),
              ),
              child: Icon(typeIcon, color: typeColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        floor.name,
                        style: AppTypography.labelLarge.copyWith(
                          color: isDark
                              ? FuturisticColors.darkTextPrimary
                              : FuturisticColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          floor.floorType.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            color: typeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (floor.description != null &&
                      floor.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        floor.description!,
                        style: AppTypography.bodySmall.copyWith(
                          color: isDark
                              ? FuturisticColors.darkTextSecondary
                              : FuturisticColors.textSecondary,
                        ),
                      ),
                    ),
                  Text(
                    'Sort: ${floor.sortOrder}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: _orange, size: 20),
                  onPressed: () => _showAddEditDialog(floor: floor),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  onPressed: () => _confirmDelete(floor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _orange.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.layers_outlined, size: 48, color: _orange),
          ),
          const SizedBox(height: 20),
          Text(
            'No floors yet',
            style: AppTypography.headlineMedium.copyWith(
              color: isDark
                  ? FuturisticColors.darkTextPrimary
                  : FuturisticColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first zone (AC, Non-AC, Rooftop…)\nto organise your tables.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: isDark
                  ? FuturisticColors.darkTextSecondary
                  : FuturisticColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add First Floor'),
            onPressed: () => _showAddEditDialog(),
          ),
        ],
      ),
    );
  }
}
