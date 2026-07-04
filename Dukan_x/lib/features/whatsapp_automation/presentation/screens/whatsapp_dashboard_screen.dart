// ============================================================================
// WhatsApp Dashboard Screen — Overview of automation status
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../providers/whatsapp_config_provider.dart';
import '../providers/whatsapp_templates_provider.dart';
import '../providers/whatsapp_rules_provider.dart';
import '../providers/whatsapp_delivery_log_provider.dart';
import '../widgets/delivery_status_chip.dart';
import 'whatsapp_templates_screen.dart';
import 'whatsapp_rules_screen.dart';
import 'whatsapp_customers_screen.dart';
import 'whatsapp_delivery_log_screen.dart';
import 'whatsapp_ai_settings_screen.dart';

/// WhatsApp Automation Dashboard — shows config status, template count,
/// active rules, recent delivery stats.
class WhatsAppDashboardScreen extends ConsumerWidget {
  const WhatsAppDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configState = ref.watch(whatsappConfigProvider);
    final templatesState = ref.watch(whatsappTemplatesProvider);
    final rulesState = ref.watch(whatsappRulesProvider);
    final logsState = ref.watch(whatsappDeliveryLogProvider);

    return Scaffold(
      backgroundColor: FuturisticColors.background,
      appBar: AppBar(
        title: Text(
          'WhatsApp Automation',
          style: AppTypography.headlineSmall.copyWith(
            color: FuturisticColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: FuturisticColors.textPrimary),
      ),
      body: BoundedBox(
        maxWidth: 900,
        child: _buildBody(
          context,
          configState: configState,
          templatesState: templatesState,
          rulesState: rulesState,
          logsState: logsState,
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required WhatsAppConfigState configState,
    required WhatsAppTemplatesState templatesState,
    required WhatsAppRulesState rulesState,
    required WhatsAppDeliveryLogState logsState,
  }) {
    // Disabled state (feature not available)
    if (configState.isDisabled) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 48, color: FuturisticColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'WhatsApp Automation is not available on your current plan.',
              style: TextStyle(color: FuturisticColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Loading state
    if (configState.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: FuturisticColors.primary),
      );
    }

    // Error state
    if (configState.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: FuturisticColors.error),
            const SizedBox(height: 12),
            Text(
              configState.error!,
              style: TextStyle(color: FuturisticColors.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final padding = responsiveValue<double>(
      context,
      mobile: 16,
      tablet: 20,
      desktop: 24,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stats Grid ──────────────────────────────────────────────────────
          _buildStatsGrid(
            context,
            configState: configState,
            templatesState: templatesState,
            rulesState: rulesState,
            logsState: logsState,
          ),
          const SizedBox(height: 24),

          // ── Quick Actions ───────────────────────────────────────────────────
          Text(
            'Quick Actions',
            style: AppTypography.headlineSmall.copyWith(
              color: FuturisticColors.textPrimary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickActions(context),
          const SizedBox(height: 24),

          // ── Recent Delivery Activity ────────────────────────────────────────
          Text(
            'Recent Delivery Activity',
            style: AppTypography.headlineSmall.copyWith(
              color: FuturisticColors.textPrimary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _buildRecentActivity(logsState),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(
    BuildContext context, {
    required WhatsAppConfigState configState,
    required WhatsAppTemplatesState templatesState,
    required WhatsAppRulesState rulesState,
    required WhatsAppDeliveryLogState logsState,
  }) {
    final activeRules = rulesState.rules.where((r) => r.enabled).length;
    final templateCount = templatesState.templates.length;
    final deliveredCount = logsState.entries
        .where((e) => e.state.value == 'delivered')
        .length;
    final failedCount = logsState.entries
        .where((e) => e.state.value == 'failed')
        .length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard(
          icon: Icons.settings,
          label: 'Config Status',
          value: configState.config != null ? 'Active' : 'Not Set',
          color: configState.config != null
              ? FuturisticColors.success
              : FuturisticColors.warning,
        ),
        _StatCard(
          icon: Icons.description,
          label: 'Templates',
          value: templateCount.toString(),
          color: FuturisticColors.primary,
        ),
        _StatCard(
          icon: Icons.rule,
          label: 'Active Rules',
          value: activeRules.toString(),
          color: Colors.teal,
        ),
        _StatCard(
          icon: Icons.done_all,
          label: 'Delivered',
          value: deliveredCount.toString(),
          color: FuturisticColors.success,
        ),
        _StatCard(
          icon: Icons.error_outline,
          label: 'Failed',
          value: failedCount.toString(),
          color: FuturisticColors.error,
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionChip(
          label: 'Templates',
          icon: Icons.description,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WhatsAppTemplatesScreen()),
          ),
        ),
        _ActionChip(
          label: 'Rules',
          icon: Icons.rule,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WhatsAppRulesScreen()),
          ),
        ),
        _ActionChip(
          label: 'Customers',
          icon: Icons.people,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WhatsAppCustomersScreen()),
          ),
        ),
        _ActionChip(
          label: 'Delivery Logs',
          icon: Icons.history,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WhatsAppDeliveryLogScreen(),
            ),
          ),
        ),
        _ActionChip(
          label: 'AI Responder',
          icon: Icons.smart_toy,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WhatsAppAiSettingsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(WhatsAppDeliveryLogState logsState) {
    if (logsState.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: FuturisticColors.primary),
      );
    }

    if (logsState.entries.isEmpty) {
      return GlassContainer(
        borderRadius: 12.0,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No delivery activity yet.',
            style: TextStyle(color: FuturisticColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    final recent = logsState.entries.take(10).toList();
    return GlassContainer(
      borderRadius: 12.0,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: recent.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                DeliveryLogStateChip(state: entry.state),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.outboundMessageId,
                    style: TextStyle(
                      color: FuturisticColors.textPrimary,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatTime(entry.timestamp),
                  style: TextStyle(
                    color: FuturisticColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: GlassContainer(
        borderRadius: 12.0,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: FuturisticColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: FuturisticColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: FuturisticColors.primary),
      label: Text(
        label,
        style: TextStyle(color: FuturisticColors.textPrimary, fontSize: 12),
      ),
      backgroundColor: FuturisticColors.primary.withValues(alpha: 0.08),
      side: BorderSide(color: FuturisticColors.primary.withValues(alpha: 0.3)),
      onPressed: onTap,
    );
  }
}
