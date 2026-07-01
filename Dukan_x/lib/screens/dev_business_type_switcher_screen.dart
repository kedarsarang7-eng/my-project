// ============================================================================
// DEV BUSINESS TYPE SWITCHER - DEVELOPER/TEST ONLY
// ============================================================================
// This screen allows developers to instantly switch between all available
// business types for testing purposes. It displays the full configuration
// details for each type (modules, fields, GST rates, labels).
//
// ⚠️  WARNING: This screen is for DEVELOPMENT and TESTING only.
//     It MUST be removed or disabled before production release.
//     Access is restricted to debug builds via kDebugMode.
//
// Author: DukanX Engineering
// Created: 2026-06-04
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';

import '../core/billing/business_type_config.dart';
import '../providers/app_state_providers.dart';
import '../core/navigation/app_screens.dart';
import '../core/navigation/navigation_controller.dart';

/// ⚠️ DEV/TEST ONLY — Remove before production release.
///
/// Allows developers to switch the active business type at runtime
/// without modifying the database or application configuration.
class DevBusinessTypeSwitcherScreen extends ConsumerStatefulWidget {
  const DevBusinessTypeSwitcherScreen({super.key});

  @override
  ConsumerState<DevBusinessTypeSwitcherScreen> createState() =>
      _DevBusinessTypeSwitcherScreenState();
}

class _DevBusinessTypeSwitcherScreenState
    extends ConsumerState<DevBusinessTypeSwitcherScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bannerController;
  late Animation<double> _bannerAnimation;

  @override
  void initState() {
    super.initState();
    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _bannerAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _bannerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ── SECURITY GATE: Only allow in debug builds ──
    if (!kDebugMode) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'This screen is available only in debug builds.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final theme = ref.watch(themeStateProvider);
    final businessState = ref.watch(businessTypeProvider);
    final isDark = theme.isDark;
    final palette = theme.palette;
    final currentType = businessState.type;

    return Scaffold(
      // FIXED: use theme-aware scaffold background
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          '🛠️ Business Type Switcher',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Info button to show current config
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Current Config Details',
            onPressed: () => _showConfigSheet(context, currentType, isDark),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── DEV WARNING BANNER ──
          _buildWarningBanner(isDark),

          // ── CURRENT TYPE INDICATOR ──
          _buildCurrentTypeIndicator(currentType, isDark, palette),

          const SizedBox(height: 8),

          // ── BUSINESS TYPE GRID ──
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _getColumnCount(context),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: BusinessType.values.length,
              itemBuilder: (context, index) {
                final type = BusinessType.values[index];
                final isActive = type == currentType;
                return _buildTypeCard(
                  type: type,
                  isActive: isActive,
                  isDark: isDark,
                  palette: palette,
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.pushReplacement(RoutePaths.authGate);
          }
        },
        backgroundColor: currentType.primaryColor,
        icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
        label: Text(
          Navigator.of(context).canPop()
              ? 'Return to Settings'
              : 'Proceed to App',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  int _getColumnCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 5;
    if (width > 900) return 4;
    if (width > 600) return 3;
    return 2;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // WARNING BANNER
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildWarningBanner(bool isDark) {
    return AnimatedBuilder(
      animation: _bannerAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.withOpacity(0.15 * _bannerAnimation.value),
                Colors.red.withOpacity(0.10 * _bannerAnimation.value),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orange.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade400,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'DEV/TEST ONLY — Changes are instant but temporary. '
                  'Remove this screen before production release.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.orange.shade200
                        : Colors.orange.shade800,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CURRENT TYPE INDICATOR
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildCurrentTypeIndicator(
    BusinessType currentType,
    bool isDark,
    AppColorPalette palette,
  ) {
    final config = BusinessTypeRegistry.getConfig(currentType);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  currentType.primaryColor.withOpacity(0.2),
                  currentType.primaryColor.withOpacity(0.08),
                ]
              : [
                  currentType.primaryColor.withOpacity(0.08),
                  currentType.primaryColor.withOpacity(0.03),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: currentType.primaryColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Icon with color badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: currentType.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                currentType.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active: ${currentType.displayName}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${config.modules.length} modules • '
                  'GST ${config.defaultGstRate}% • '
                  '${config.requiredFields.length} required fields',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // View config
          IconButton(
            icon: Icon(
              Icons.visibility_rounded,
              color: currentType.primaryColor,
              size: 22,
            ),
            tooltip: 'View full config',
            onPressed: () => _showConfigSheet(context, currentType, isDark),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TYPE CARD
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildTypeCard({
    required BusinessType type,
    required bool isActive,
    required bool isDark,
    required AppColorPalette palette,
  }) {
    final color = type.primaryColor;
    final config = BusinessTypeRegistry.getConfig(type);

    return GestureDetector(
      onTap: () => _switchType(type),
      onLongPress: () => _showConfigSheet(context, type, isDark),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [color.withOpacity(0.25), color.withOpacity(0.10)]
                      : [Colors.white, color.withOpacity(0.12)],
                )
              : null,
          color: isActive
              ? null
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(isActive ? 20 : 16),
          border: Border.all(
            color: isActive
                ? color
                : (isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.grey.shade200),
            width: isActive ? 2.5 : 1,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: color.withOpacity(isDark ? 0.3 : 0.2),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              )
            else if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Stack(
          children: [
            // Card content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Emoji icon
                  Text(
                    type.emoji,
                    style: TextStyle(fontSize: isActive ? 30 : 26),
                  ),
                  const SizedBox(height: 8),

                  // Name
                  Text(
                    type.displayName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isActive ? 13 : 12.5,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                      color: isActive
                          ? (isDark ? Colors.white : color)
                          : (isDark ? Colors.white70 : const Color(0xFF334155)),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Module count chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (isActive ? color : Colors.grey).withOpacity(
                        isDark ? 0.2 : 0.1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${config.modules.length} modules',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isActive
                            ? (isDark ? Colors.white70 : color)
                            : (isDark ? Colors.white38 : Colors.grey.shade500),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Active badge
            if (isActive)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              ),

            // Long-press hint for non-active
            if (!isActive)
              Positioned(
                bottom: 6,
                right: 8,
                child: Icon(
                  Icons.touch_app_rounded,
                  size: 14,
                  color: isDark
                      ? Colors.white.withOpacity(0.15)
                      : Colors.grey.shade300,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SWITCH BUSINESS TYPE
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> _switchType(BusinessType type) async {
    final currentType = ref.read(businessTypeProvider).type;
    if (type == currentType) {
      // Already active — show config instead
      _showConfigSheet(context, type, ref.read(themeStateProvider).isDark);
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Text(type.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Switch Business Type?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(ctx).textTheme.bodyMedium?.color,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'Switch from '),
              TextSpan(
                text: currentType.displayName,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: currentType.primaryColor,
                ),
              ),
              const TextSpan(text: ' to '),
              TextSpan(
                text: type.displayName,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: type.primaryColor,
                ),
              ),
              const TextSpan(
                text:
                    '?\n\nThis will change the UI, available '
                    'features, and billing fields immediately.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: type.primaryColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Perform the switch
    await ref.read(businessTypeProvider.notifier).setBusinessType(type);

    // Reset the navigation to the default dashboard for the new business type
    final newDefaultScreen = type == BusinessType.clinic
        ? AppScreen.clinicDashboard
        : (type == BusinessType.petrolPump
              ? AppScreen.petrolDashboard
              : AppScreen.executiveDashboard);
    ref
        .read(navigationControllerProvider.notifier)
        .navigateTo(newDefaultScreen);

    if (!mounted) return;

    // Show success feedback
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: type.primaryColor,
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Text(type.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Switched to ${type.displayName}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'VIEW CONFIG',
          textColor: Colors.white70,
          onPressed: () {
            _showConfigSheet(
              context,
              type,
              ref.read(themeStateProvider).isDark,
            );
          },
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CONFIG DETAILS BOTTOM SHEET
  // ════════════════════════════════════════════════════════════════════════════

  void _showConfigSheet(BuildContext context, BusinessType type, bool isDark) {
    final config = BusinessTypeRegistry.getConfig(type);
    final color = type.primaryColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Row(
                    children: [
                      Text(type.emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type.displayName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'enum: BusinessType.${type.name}',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: isDark
                                    ? Colors.white38
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Color badge
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── LABELS ──
                  _buildConfigSection(
                    'Labels',
                    Icons.label_outline_rounded,
                    isDark,
                    children: [
                      _buildConfigRow('Item Label', config.itemLabel, isDark),
                      _buildConfigRow(
                        'Add Item Label',
                        config.addItemLabel,
                        isDark,
                      ),
                      _buildConfigRow('Price Label', config.priceLabel, isDark),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── GST ──
                  _buildConfigSection(
                    'GST Configuration',
                    Icons.receipt_long_rounded,
                    isDark,
                    children: [
                      _buildConfigRow(
                        'Default Rate',
                        '${config.defaultGstRate}%',
                        isDark,
                      ),
                      _buildConfigRow(
                        'Editable',
                        config.gstEditable ? 'Yes' : 'No',
                        isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── MODULES ──
                  _buildConfigSection(
                    'Modules (${config.modules.length})',
                    Icons.extension_rounded,
                    isDark,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: config.modules.map((m) {
                          return Chip(
                            label: Text(
                              m,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : color,
                              ),
                            ),
                            backgroundColor: color.withOpacity(
                              isDark ? 0.2 : 0.1,
                            ),
                            side: BorderSide(color: color.withOpacity(0.3)),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── REQUIRED FIELDS ──
                  _buildConfigSection(
                    'Required Fields (${config.requiredFields.length})',
                    Icons.check_circle_outline_rounded,
                    isDark,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: config.requiredFields.map((f) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(
                                isDark ? 0.15 : 0.08,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              f.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                                color: isDark
                                    ? Colors.green.shade300
                                    : Colors.green.shade700,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── OPTIONAL FIELDS ──
                  _buildConfigSection(
                    'Optional Fields (${config.optionalFields.length})',
                    Icons.add_circle_outline_rounded,
                    isDark,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: config.optionalFields.map((f) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(
                                isDark ? 0.15 : 0.08,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              f.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                                color: isDark
                                    ? Colors.blue.shade300
                                    : Colors.blue.shade700,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── UNIT OPTIONS ──
                  _buildConfigSection(
                    'Unit Options (${config.unitOptions.length})',
                    Icons.straighten_rounded,
                    isDark,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: config.unitOptions.map((u) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              u.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Config Section Header ──
  Widget _buildConfigSection(
    String title,
    IconData icon,
    bool isDark, {
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: isDark ? Colors.white54 : Colors.grey),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  // ── Config Row (label: value) ──
  Widget _buildConfigRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
