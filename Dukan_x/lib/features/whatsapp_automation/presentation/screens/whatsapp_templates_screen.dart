// ============================================================================
// WhatsApp Templates Screen — List + create/edit templates
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../data/models/message_template_model.dart';
import '../providers/whatsapp_templates_provider.dart';
import '../widgets/placeholder_chip.dart';

/// WhatsApp Templates Screen — list, create, and edit message templates.
class WhatsAppTemplatesScreen extends ConsumerWidget {
  const WhatsAppTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(whatsappTemplatesProvider);

    return Scaffold(
      backgroundColor: FuturisticColors.background,
      appBar: AppBar(
        title: Text(
          'Message Templates',
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
            tooltip: 'Create Template',
          ),
        ],
      ),
      body: BoundedBox(maxWidth: 800, child: _buildBody(context, ref, state)),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    WhatsAppTemplatesState state,
  ) {
    if (state.isDisabled) {
      return Center(
        child: Text(
          'Templates feature is not available.',
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
                  ref.read(whatsappTemplatesProvider.notifier).loadTemplates(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: 48,
              color: FuturisticColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'No templates yet. Create one to get started.',
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
      itemCount: state.templates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final template = state.templates[index];
        return _TemplateCard(
          template: template,
          onEdit: () => _showEditDialog(context, ref, template),
          onDelete: () => _confirmDelete(context, ref, template),
        );
      },
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final placeholderCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Template'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Template Name *',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Message Body *',
                    hintText: 'Hello {{name}}, your order is ready!',
                  ),
                  maxLines: 4,
                  maxLength: 4096,
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: placeholderCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Placeholders (comma separated)',
                    hintText: 'name, amount, date',
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 16),
                // Placeholder-aware preview
                if (bodyCtrl.text.isNotEmpty) ...[
                  Text(
                    'Preview',
                    style: TextStyle(
                      color: FuturisticColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _TemplatePlaceholderPreview(body: bodyCtrl.text),
                ],
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
                if (nameCtrl.text.isEmpty || bodyCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                final placeholders = placeholderCtrl.text
                    .split(',')
                    .map((p) => p.trim())
                    .where((p) => p.isNotEmpty)
                    .toList();
                await ref
                    .read(whatsappTemplatesProvider.notifier)
                    .createTemplate(
                      name: nameCtrl.text.trim(),
                      body: bodyCtrl.text.trim(),
                      placeholders: placeholders,
                    );
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
    MessageTemplate template,
  ) {
    final nameCtrl = TextEditingController(text: template.name);
    final bodyCtrl = TextEditingController(text: template.body);
    final placeholderCtrl = TextEditingController(
      text: template.placeholders.join(', '),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Template'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Template Name *',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Message Body *',
                  ),
                  maxLines: 4,
                  maxLength: 4096,
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: placeholderCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Placeholders (comma separated)',
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 16),
                // Placeholder-aware preview
                if (bodyCtrl.text.isNotEmpty) ...[
                  Text(
                    'Preview',
                    style: TextStyle(
                      color: FuturisticColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _TemplatePlaceholderPreview(body: bodyCtrl.text),
                ],
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
                if (nameCtrl.text.isEmpty || bodyCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                final placeholders = placeholderCtrl.text
                    .split(',')
                    .map((p) => p.trim())
                    .where((p) => p.isNotEmpty)
                    .toList();
                await ref
                    .read(whatsappTemplatesProvider.notifier)
                    .updateTemplate(
                      template.id,
                      name: nameCtrl.text.trim(),
                      body: bodyCtrl.text.trim(),
                      placeholders: placeholders,
                    );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MessageTemplate template,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Template?'),
        content: Text('Delete "${template.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(whatsappTemplatesProvider.notifier)
                  .deleteTemplate(template.id);
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

// ── Template Card ─────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final MessageTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TemplateCard({
    required this.template,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 12.0,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  template.name,
                  style: TextStyle(
                    color: FuturisticColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: template.status == TemplateStatus.active
                      ? FuturisticColors.success.withValues(alpha: 0.15)
                      : FuturisticColors.textMuted.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  template.status.value,
                  style: TextStyle(
                    color: template.status == TemplateStatus.active
                        ? FuturisticColors.success
                        : FuturisticColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  Icons.edit,
                  size: 18,
                  color: FuturisticColors.primary,
                ),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
              IconButton(
                icon: Icon(
                  Icons.delete,
                  size: 18,
                  color: FuturisticColors.error,
                ),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Template body preview
          Text(
            template.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: FuturisticColors.textMuted, fontSize: 12),
          ),
          if (template.placeholders.isNotEmpty) ...[
            const SizedBox(height: 8),
            PlaceholderChipRow(placeholders: template.placeholders),
          ],
          const SizedBox(height: 4),
          Text(
            'v${template.currentVersion} · ${template.locale}',
            style: TextStyle(color: FuturisticColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ── Placeholder-Aware Preview Widget ──────────────────────────────────────────

/// Renders the template body with {{placeholder}} tokens highlighted.
/// Shows placeholders as inline colored spans so the user can see exactly
/// where dynamic content will appear in the final message.
class _TemplatePlaceholderPreview extends StatelessWidget {
  final String body;

  const _TemplatePlaceholderPreview({required this.body});

  @override
  Widget build(BuildContext context) {
    final spans = _buildSpans(body);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FuturisticColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: FuturisticColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: RichText(text: TextSpan(children: spans)),
    );
  }

  /// Parse the body and split into normal text and {{placeholder}} spans.
  List<InlineSpan> _buildSpans(String text) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\{\{(\w+)\}\}');
    int lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      // Text before the placeholder
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: TextStyle(color: FuturisticColors.textPrimary, fontSize: 12),
          ),
        );
      }
      // The placeholder itself, highlighted
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            color: FuturisticColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            backgroundColor: FuturisticColors.primary.withValues(alpha: 0.1),
          ),
        ),
      );
      lastEnd = match.end;
    }

    // Remaining text after the last placeholder
    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: TextStyle(color: FuturisticColors.textPrimary, fontSize: 12),
        ),
      );
    }

    if (spans.isEmpty) {
      spans.add(
        TextSpan(
          text: text,
          style: TextStyle(color: FuturisticColors.textPrimary, fontSize: 12),
        ),
      );
    }

    return spans;
  }
}
