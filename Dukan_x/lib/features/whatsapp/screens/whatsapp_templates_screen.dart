// ============================================================================
// WhatsApp Templates Screen — CRUD for message templates
// ============================================================================
// Manage reusable message templates for invoices, reminders, campaigns, etc.
// Templates support variable substitution ({customerName}, {amount}, etc.).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dukanx/core/openwa/openwa_models.dart';
import 'package:dukanx/features/whatsapp/providers/whatsapp_providers.dart';

class WhatsAppTemplatesScreen extends ConsumerStatefulWidget {
  const WhatsAppTemplatesScreen({super.key});

  @override
  ConsumerState<WhatsAppTemplatesScreen> createState() =>
      _WhatsAppTemplatesScreenState();
}

class _WhatsAppTemplatesScreenState
    extends ConsumerState<WhatsAppTemplatesScreen> {
  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(waConnectionProvider);
    final theme = Theme.of(context);

    if (!connectionState.isUsable) {
      return _buildNotConnected(context);
    }

    final templatesAsync = ref.watch(waTemplateListProvider);

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: templatesAsync.when(
              data: (templates) {
                if (templates.isEmpty) {
                  return _buildEmptyState(context);
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(waTemplateListProvider),
                  child: ListView.builder(
                    itemCount: templates.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (ctx, i) =>
                        _buildTemplateCard(ctx, templates[i]),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text('Failed to load templates'),
                    TextButton.icon(
                      onPressed: () =>
                          ref.invalidate(waTemplateListProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: connectionState.isUsable
          ? FloatingActionButton.extended(
              onPressed: () => _showTemplateEditor(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Template'),
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Message Templates',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Create reusable templates for invoices, reminders, and campaigns.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(BuildContext context, WATemplate template) {
    final theme = Theme.of(context);

    // Detect variables in the template body
    final varRegex = RegExp(r'\{(\w+)\}');
    final variables = varRegex.allMatches(template.body).map((m) => m.group(1)!).toList();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showTemplateEditor(context, template: template),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.text_snippet_rounded,
                      size: 20,
                      color: Color(0xFF25D366),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      template.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (action) => _handleTemplateAction(
                      action,
                      template,
                    ),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded, size: 18,
                                color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Template body preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  template.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (variables.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: variables.map((v) {
                    return Chip(
                      label: Text(
                        v,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontFamily: 'monospace',
                          color: const Color(0xFF128C7E),
                        ),
                      ),
                      backgroundColor:
                          const Color(0xFF25D366).withOpacity(0.08),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.text_snippet_outlined,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Templates Yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create message templates for invoices, reminders,\nand promotional campaigns.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showTemplateEditor(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Template'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotConnected(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.text_snippet_outlined,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Connect WhatsApp First',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect your WhatsApp Business number to manage templates.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showTemplateEditor(BuildContext context, {WATemplate? template}) {
    final isEditing = template != null;
    final nameController = TextEditingController(text: template?.name ?? '');
    final bodyController = TextEditingController(text: template?.body ?? '');
    final headerController =
        TextEditingController(text: template?.header ?? '');
    final footerController =
        TextEditingController(text: template?.footer ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Text(
                      isEditing ? 'Edit Template' : 'New Template',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              // Form
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Template Name',
                        hintText: 'e.g., Invoice Delivery',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: headerController,
                      decoration: const InputDecoration(
                        labelText: 'Header (optional)',
                        hintText: 'e.g., 📋 Invoice #{invoiceNumber}',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: bodyController,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Message Body',
                        hintText:
                            'Dear {customerName},\n\nYour invoice of ₹{amount} is ready...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: footerController,
                      decoration: const InputDecoration(
                        labelText: 'Footer (optional)',
                        hintText: 'Thank you for your business!',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Variable help
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Color(0xFF128C7E),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Use {variableName} for dynamic values.\n'
                              'Available: {customerName}, {amount}, '
                              '{invoiceNumber}, {dueDate}, {businessName}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: const Color(0xFF128C7E),
                                    height: 1.4,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              // Action bar
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () async {
                          await _saveTemplate(
                            context,
                            template: template,
                            name: nameController.text.trim(),
                            body: bodyController.text.trim(),
                            header: headerController.text.trim(),
                            footer: footerController.text.trim(),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        icon: Icon(isEditing
                            ? Icons.save_rounded
                            : Icons.add_rounded),
                        label: Text(isEditing ? 'Save Changes' : 'Create'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveTemplate(
    BuildContext context, {
    WATemplate? template,
    required String name,
    required String body,
    required String header,
    required String footer,
  }) async {
    if (name.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and body are required')),
      );
      return;
    }

    try {
      final tenantService = ref.read(openWATenantServiceProvider);
      final config = await tenantService.getBusinessConfig();
      if (config.sessionId == null) return;

      final client = await tenantService.getClient();

      if (template != null) {
        await client.updateTemplate(
          config.sessionId!,
          template.id,
          name: name,
          body: body,
          header: header.isNotEmpty ? header : null,
          footer: footer.isNotEmpty ? footer : null,
        );
      } else {
        await client.createTemplate(
          config.sessionId!,
          name: name,
          body: body,
          header: header.isNotEmpty ? header : null,
          footer: footer.isNotEmpty ? footer : null,
        );
      }

      ref.invalidate(waTemplateListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(template != null
                ? 'Template updated'
                : 'Template created'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _handleTemplateAction(String action, WATemplate template) async {
    if (action == 'edit') {
      _showTemplateEditor(context, template: template);
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Template?'),
          content: Text('Delete "${template.name}"? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        try {
          final tenantService = ref.read(openWATenantServiceProvider);
          final config = await tenantService.getBusinessConfig();
          if (config.sessionId == null) return;

          final client = await tenantService.getClient();
          await client.deleteTemplate(config.sessionId!, template.id);
          ref.invalidate(waTemplateListProvider);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Template deleted')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
      }
    }
  }
}
