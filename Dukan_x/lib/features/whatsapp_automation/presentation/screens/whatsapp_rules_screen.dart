// ============================================================================
// WhatsApp Rules Screen — List + create/edit automation rules
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../data/models/automation_rule_model.dart';
import '../providers/whatsapp_rules_provider.dart';
import '../widgets/automation_toggle_tile.dart';

/// WhatsApp Rules Screen — list rules with enable/disable toggle, create/edit.
class WhatsAppRulesScreen extends ConsumerWidget {
  const WhatsAppRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(whatsappRulesProvider);

    return Scaffold(
      backgroundColor: FuturisticColors.background,
      appBar: AppBar(
        title: Text(
          'Automation Rules',
          style: AppTypography.headlineSmall.copyWith(
            color: FuturisticColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: FuturisticColors.textPrimary),
        actions: [
          IconButton(
            onPressed: () => _showCreateDialog(context, ref),
            icon: Icon(Icons.add, color: FuturisticColors.primary),
            tooltip: 'Create Rule',
          ),
        ],
      ),
      body: BoundedBox(maxWidth: 800, child: _buildBody(context, ref, state)),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    WhatsAppRulesState state,
  ) {
    if (state.isDisabled) {
      return Center(
        child: Text(
          'Rules feature is not available.',
          style: TextStyle(color: FuturisticColors.textMuted),
        ),
      );
    }

    if (state.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: FuturisticColors.primary),
      );
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: FuturisticColors.error),
            const SizedBox(height: 8),
            Text(state.error!, style: TextStyle(color: FuturisticColors.error)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  ref.read(whatsappRulesProvider.notifier).loadRules(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.rules.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.rule_outlined,
              size: 48,
              color: FuturisticColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'No automation rules yet. Create one to get started.',
              style: TextStyle(color: FuturisticColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 12, tablet: 16, desktop: 20),
      ),
      itemCount: state.rules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final rule = state.rules[index];
        return _RuleCard(
          rule: rule,
          onToggle: (enabled) {
            ref
                .read(whatsappRulesProvider.notifier)
                .toggleRule(rule.id, enabled);
          },
          onEdit: () => _showEditDialog(context, ref, rule),
          onDelete: () => _confirmDelete(context, ref, rule),
        );
      },
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final eventTypeCtrl = TextEditingController();
    final templateIdCtrl = TextEditingController();
    MessageCategory selectedCategory = MessageCategory.transactional;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Automation Rule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: eventTypeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Event Type *',
                    hintText: 'e.g. order_created, payment_received',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: templateIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Template ID *',
                    hintText: 'ID of the message template to use',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MessageCategory>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: MessageCategory.values
                      .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c.value)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedCategory = v);
                    }
                  },
                ),
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
                if (eventTypeCtrl.text.isEmpty || templateIdCtrl.text.isEmpty) {
                  return;
                }
                Navigator.pop(ctx);
                await ref.read(whatsappRulesProvider.notifier).createRule({
                  'eventType': eventTypeCtrl.text.trim(),
                  'templateId': templateIdCtrl.text.trim(),
                  'category': selectedCategory.value,
                  'recipients': {'type': 'customer'},
                  'conditions': <Map<String, dynamic>>[],
                  'enabled': true,
                });
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    AutomationRule rule,
  ) {
    final eventTypeCtrl = TextEditingController(text: rule.eventType);
    final templateIdCtrl = TextEditingController(text: rule.templateId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Rule'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: eventTypeCtrl,
                decoration: const InputDecoration(labelText: 'Event Type *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: templateIdCtrl,
                decoration: const InputDecoration(labelText: 'Template ID *'),
              ),
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
              if (eventTypeCtrl.text.isEmpty || templateIdCtrl.text.isEmpty) {
                return;
              }
              Navigator.pop(ctx);
              await ref
                  .read(whatsappRulesProvider.notifier)
                  .updateRule(rule.id, {
                    'eventType': eventTypeCtrl.text.trim(),
                    'templateId': templateIdCtrl.text.trim(),
                  });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AutomationRule rule,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Rule?'),
        content: Text(
          'Delete rule for "${rule.eventType}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(whatsappRulesProvider.notifier).deleteRule(rule.id);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: FuturisticColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rule Card ─────────────────────────────────────────────────────────────────

class _RuleCard extends StatelessWidget {
  final AutomationRule rule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RuleCard({
    required this.rule,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 12.0,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Column(
        children: [
          AutomationToggleTile(
            title: rule.eventType,
            subtitle:
                '${rule.category.value} · Template: ${rule.templateId.substring(0, 8)}…',
            enabled: rule.enabled,
            onToggle: onToggle,
            onTap: onEdit,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Row(
              children: [
                Text(
                  '${rule.conditions.length} conditions',
                  style: TextStyle(
                    color: FuturisticColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.edit,
                    size: 16,
                    color: FuturisticColors.primary,
                  ),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete,
                    size: 16,
                    color: FuturisticColors.error,
                  ),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
