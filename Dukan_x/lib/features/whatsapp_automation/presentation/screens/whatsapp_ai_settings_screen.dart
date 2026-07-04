// ============================================================================
// WhatsApp AI Settings Screen — AI Responder configuration
// ============================================================================
// Shows explicit disabled indicator when WA_AI_RESPONDER is OFF (Req 15.2).
// Deferred/disabled capabilities render explicit unavailable state with
// no fabricated data (Req 15.5).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../providers/whatsapp_ai_responder_provider.dart';

/// WhatsApp AI Responder Settings Screen.
///
/// When WA_AI_RESPONDER feature is OFF, shows an explicit disabled indicator
/// with no fabricated data. When enabled, allows configuring auto-reply,
/// provider, timeout, and system prompt settings.
class WhatsAppAiSettingsScreen extends ConsumerWidget {
  const WhatsAppAiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(whatsappAiResponderProvider);

    return Scaffold(
      backgroundColor: FuturisticColors.background,
      appBar: AppBar(
        title: Text(
          'AI Responder',
          style: AppTypography.headlineSmall.copyWith(
            color: FuturisticColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: FuturisticColors.textPrimary),
      ),
      body: BoundedBox(maxWidth: 800, child: _buildBody(context, ref, state)),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    WhatsAppAiResponderState state,
  ) {
    // ── Disabled / Unavailable State (Req 15.2, 15.5) ─────────────────────
    if (state.isDisabled) {
      return _buildDisabledState(context);
    }

    // ── Loading ───────────────────────────────────────────────────────────
    if (state.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: FuturisticColors.primary),
      );
    }

    // ── Error ─────────────────────────────────────────────────────────────
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
                  ref.read(whatsappAiResponderProvider.notifier).loadSettings(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final settings = state.settings;
    if (settings == null) {
      return _buildDisabledState(context);
    }

    // ── Enabled State — show settings ─────────────────────────────────────
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
          // Status card
          _buildStatusCard(settings.autoReplyEnabled),
          const SizedBox(height: 16),

          // Auto-reply toggle
          GlassContainer(
            borderRadius: 12.0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'AI Auto-Reply',
                style: TextStyle(
                  color: FuturisticColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                settings.autoReplyEnabled
                    ? 'AI will auto-respond to inbound customer messages'
                    : 'AI auto-reply is paused',
                style: TextStyle(
                  color: FuturisticColors.textMuted,
                  fontSize: 12,
                ),
              ),
              value: settings.autoReplyEnabled,
              activeColor: FuturisticColors.primary,
              onChanged: (enabled) {
                ref
                    .read(whatsappAiResponderProvider.notifier)
                    .toggleAutoReply(enabled);
              },
            ),
          ),
          const SizedBox(height: 16),

          // Configuration details
          GlassContainer(
            borderRadius: 12.0,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuration',
                  style: TextStyle(
                    color: FuturisticColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSettingRow(
                  'Provider',
                  settings.provider ?? 'Not configured',
                  Icons.smart_toy,
                ),
                const SizedBox(height: 8),
                _buildSettingRow(
                  'Response Timeout',
                  '${settings.timeoutSeconds}s',
                  Icons.timer,
                ),
                const SizedBox(height: 8),
                _buildSettingRow(
                  'Max Response Length',
                  settings.maxResponseLength != null
                      ? '${settings.maxResponseLength} chars'
                      : 'Default',
                  Icons.text_fields,
                ),
                if (settings.systemPrompt != null &&
                    settings.systemPrompt!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'System Prompt',
                    style: TextStyle(
                      color: FuturisticColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: FuturisticColors.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: FuturisticColors.textMuted.withValues(
                          alpha: 0.2,
                        ),
                      ),
                    ),
                    child: Text(
                      settings.systemPrompt!,
                      style: TextStyle(
                        color: FuturisticColors.textPrimary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Edit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showEditDialog(context, ref, settings),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FuturisticColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Renders the explicit disabled/unavailable state (Req 15.2, 15.5).
  Widget _buildDisabledState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: FuturisticColors.textMuted.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(36),
              ),
              child: Icon(
                Icons.smart_toy_outlined,
                size: 36,
                color: FuturisticColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'AI Responder Unavailable',
              style: TextStyle(
                color: FuturisticColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The AI Responder feature is not enabled for your business.\n'
              'This capability requires the Enterprise tier.',
              textAlign: TextAlign.center,
              style: TextStyle(color: FuturisticColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: FuturisticColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: FuturisticColors.error.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block, size: 14, color: FuturisticColors.error),
                  const SizedBox(width: 6),
                  Text(
                    'DISABLED',
                    style: TextStyle(
                      color: FuturisticColors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
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

  Widget _buildStatusCard(bool isActive) {
    final color = isActive
        ? FuturisticColors.success
        : FuturisticColors.warning;
    final label = isActive ? 'Active' : 'Paused';
    final icon = isActive ? Icons.check_circle : Icons.pause_circle;

    return GlassContainer(
      borderRadius: 12.0,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Responder Status',
                  style: TextStyle(
                    color: FuturisticColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(label, style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: FuturisticColors.textMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: FuturisticColors.textMuted, fontSize: 12),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: FuturisticColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, dynamic settings) {
    final timeoutCtrl = TextEditingController(
      text: settings.timeoutSeconds.toString(),
    );
    final maxLenCtrl = TextEditingController(
      text: settings.maxResponseLength?.toString() ?? '',
    );
    final promptCtrl = TextEditingController(text: settings.systemPrompt ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit AI Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: timeoutCtrl,
                decoration: const InputDecoration(
                  labelText: 'Response Timeout (seconds)',
                  hintText: '30',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: maxLenCtrl,
                decoration: const InputDecoration(
                  labelText: 'Max Response Length (optional)',
                  hintText: 'Leave empty for default',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: promptCtrl,
                decoration: const InputDecoration(
                  labelText: 'System Prompt (optional)',
                  hintText: 'Custom instructions for the AI',
                ),
                maxLines: 4,
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
            onPressed: () {
              Navigator.pop(ctx);
              final updates = <String, dynamic>{
                'timeoutSeconds': int.tryParse(timeoutCtrl.text) ?? 30,
              };
              if (maxLenCtrl.text.isNotEmpty) {
                updates['maxResponseLength'] = int.tryParse(maxLenCtrl.text);
              }
              if (promptCtrl.text.isNotEmpty) {
                updates['systemPrompt'] = promptCtrl.text.trim();
              }
              ref
                  .read(whatsappAiResponderProvider.notifier)
                  .updateSettings(updates);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
