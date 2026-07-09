// ============================================================================
// WhatsApp Webhooks Screen — CRUD for webhook management
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dukanx/features/whatsapp/providers/whatsapp_providers.dart';

class WhatsAppWebhooksScreen extends ConsumerStatefulWidget {
  const WhatsAppWebhooksScreen({super.key});

  @override
  ConsumerState<WhatsAppWebhooksScreen> createState() =>
      _WhatsAppWebhooksScreenState();
}

class _WhatsAppWebhooksScreenState
    extends ConsumerState<WhatsAppWebhooksScreen> {
  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(waConnectionProvider);
    final theme = Theme.of(context);

    if (!connectionState.isUsable) {
      return _buildNotConnected(context);
    }

    final webhooksAsync = ref.watch(waWebhookListProvider);

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: webhooksAsync.when(
              data: (webhooks) {
                if (webhooks.isEmpty) return _buildEmptyState(context);
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(waWebhookListProvider),
                  child: ListView.builder(
                    itemCount: webhooks.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (ctx, i) =>
                        _buildWebhookCard(ctx, webhooks[i]),
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildErrorState(context),
            ),
          ),
        ],
      ),
      floatingActionButton: connectionState.isUsable
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateWebhookDialog(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Webhook'),
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
            const Icon(Icons.webhook_rounded,
                color: Color(0xFF25D366), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Webhooks',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => ref.invalidate(waWebhookListProvider),
              tooltip: 'Refresh',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebhookCard(
      BuildContext context, Map<String, dynamic> webhook) {
    final theme = Theme.of(context);
    final url = webhook['url'] as String? ?? '—';
    final events = (webhook['events'] as List<dynamic>?)?.join(', ') ?? '—';
    final isActive = webhook['active'] as bool? ?? true;
    final id = webhook['id'] as String? ?? '';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
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
                    color: (isActive ? Colors.green : Colors.grey)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isActive
                        ? Icons.check_circle_outline_rounded
                        : Icons.pause_circle_outline_rounded,
                    color: isActive ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        url,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Events: $events',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => _onWebhookAction(v, webhook),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                        value: 'test', child: Text('Test Webhook')),
                    const PopupMenuItem(
                        value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onWebhookAction(
      String action, Map<String, dynamic> webhook) async {
    final id = webhook['id'] as String? ?? '';
    final tenantService = ref.read(openWATenantServiceProvider);

    try {
      final config = await tenantService.getBusinessConfig();
      final client = await tenantService.getClient();

      if (action == 'test') {
        await client.testWebhook(config.sessionId!, id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Test event sent!')),
          );
        }
      } else if (action == 'delete') {
        await client.deleteWebhook(config.sessionId!, id);
        ref.invalidate(waWebhookListProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showCreateWebhookDialog(BuildContext context) {
    final urlCtrl = TextEditingController();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Webhook'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Webhook URL',
                  hintText: 'https://your-server.com/webhook',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Subscribes to all events by default.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _createWebhook(urlCtrl.text.trim());
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createWebhook(String url) async {
    if (url.isEmpty) return;
    try {
      final tenantService = ref.read(openWATenantServiceProvider);
      final config = await tenantService.getBusinessConfig();
      final client = await tenantService.getClient();
      await client.createWebhook(
        config.sessionId!,
        url: url,
        events: ['*'],
      );
      ref.invalidate(waWebhookListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.webhook_rounded,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text('No webhooks configured',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('Add a webhook to receive real-time event notifications.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () => ref.invalidate(waWebhookListProvider),
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Retry'),
      ),
    );
  }

  Widget _buildNotConnected(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.webhook_rounded,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('WhatsApp Not Connected',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
