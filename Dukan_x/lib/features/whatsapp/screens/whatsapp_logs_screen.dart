// ============================================================================
// WhatsApp Logs Screen — Audit logs viewer
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dukanx/features/whatsapp/providers/whatsapp_providers.dart';

class WhatsAppLogsScreen extends ConsumerStatefulWidget {
  const WhatsAppLogsScreen({super.key});

  @override
  ConsumerState<WhatsAppLogsScreen> createState() =>
      _WhatsAppLogsScreenState();
}

class _WhatsAppLogsScreenState
    extends ConsumerState<WhatsAppLogsScreen> {
  String? _filterAction;
  String? _filterSeverity;

  String get _filterString {
    return '${_filterAction ?? ''}:${_filterSeverity ?? ''}:50';
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(waConnectionProvider);
    final theme = Theme.of(context);

    if (!connectionState.isUsable) {
      return _buildNotConnected(context);
    }

    final logsAsync = ref.watch(waAuditLogsProvider(_filterString));

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          _buildFilterBar(context),
          Expanded(
            child: logsAsync.when(
              data: (data) {
                final logs = data['logs'] as List<dynamic>? ?? [];
                if (logs.isEmpty) return _buildEmptyState(context);

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(waAuditLogsProvider(_filterString)),
                  child: ListView.builder(
                    itemCount: logs.length,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemBuilder: (ctx, i) =>
                        _buildLogEntry(ctx, logs[i] as Map<String, dynamic>),
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => _buildErrorState(context),
            ),
          ),
        ],
      ),
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
            const Icon(Icons.receipt_long_outlined,
                color: Color(0xFF25D366), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Audit Logs',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () =>
                  ref.invalidate(waAuditLogsProvider(_filterString)),
              tooltip: 'Refresh',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: _filterSeverity,
              decoration: InputDecoration(
                labelText: 'Severity',
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'info', child: Text('Info')),
                DropdownMenuItem(value: 'warn', child: Text('Warning')),
                DropdownMenuItem(value: 'error', child: Text('Error')),
                DropdownMenuItem(
                    value: 'critical', child: Text('Critical')),
              ],
              onChanged: (v) => setState(() => _filterSeverity = v),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: _filterAction,
              decoration: InputDecoration(
                labelText: 'Action',
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(
                    value: 'session.start', child: Text('Session Start')),
                DropdownMenuItem(
                    value: 'session.stop', child: Text('Session Stop')),
                DropdownMenuItem(
                    value: 'message.send', child: Text('Message Send')),
                DropdownMenuItem(
                    value: 'api_key.create',
                    child: Text('Key Created')),
              ],
              onChanged: (v) => setState(() => _filterAction = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(BuildContext context, Map<String, dynamic> log) {
    final theme = Theme.of(context);
    final action = log['action'] as String? ?? '—';
    final severity = log['severity'] as String? ?? 'info';
    final message = log['message'] as String? ?? '';
    final timestamp = log['timestamp'] as String? ?? '';
    final actor = log['actor'] as String? ?? '';

    Color severityColor;
    IconData severityIcon;
    switch (severity) {
      case 'error':
        severityColor = Colors.red;
        severityIcon = Icons.error_outline_rounded;
      case 'critical':
        severityColor = Colors.red.shade900;
        severityIcon = Icons.warning_amber_rounded;
      case 'warn':
        severityColor = Colors.orange;
        severityIcon = Icons.warning_outlined;
      default:
        severityColor = Colors.blue;
        severityIcon = Icons.info_outline_rounded;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.2),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: severityColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(severityIcon, color: severityColor, size: 18),
        ),
        title: Text(action,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isNotEmpty)
              Text(message,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            Row(
              children: [
                if (actor.isNotEmpty) ...[
                  Icon(Icons.person_outline, size: 12,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text(actor,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(width: 8),
                ],
                if (timestamp.isNotEmpty)
                  Text(timestamp,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
        isThreeLine: message.isNotEmpty,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text('No audit logs found',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () =>
            ref.invalidate(waAuditLogsProvider(_filterString)),
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
          Icon(Icons.receipt_long_outlined,
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
