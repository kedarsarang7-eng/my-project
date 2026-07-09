// ============================================================================
// WhatsApp Settings Screen — API Keys + Infrastructure management
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dukanx/features/whatsapp/providers/whatsapp_providers.dart';

class WhatsAppSettingsScreen extends ConsumerStatefulWidget {
  const WhatsAppSettingsScreen({super.key});

  @override
  ConsumerState<WhatsAppSettingsScreen> createState() =>
      _WhatsAppSettingsScreenState();
}

class _WhatsAppSettingsScreenState
    extends ConsumerState<WhatsAppSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(waConnectionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          if (!connectionState.isUsable)
            Expanded(child: _buildNotConnected(context))
          else ...[
            TabBar(
              controller: _tabCtrl,
              labelColor: const Color(0xFF25D366),
              indicatorColor: const Color(0xFF25D366),
              tabs: const [
                Tab(text: 'API Keys', icon: Icon(Icons.key_rounded)),
                Tab(text: 'Infrastructure',
                    icon: Icon(Icons.dns_outlined)),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _ApiKeysTab(),
                  _InfraTab(),
                ],
              ),
            ),
          ],
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
            const Icon(Icons.settings_outlined,
                color: Color(0xFF25D366), size: 28),
            const SizedBox(width: 12),
            Text(
              'Settings',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotConnected(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.settings_outlined,
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

// ── API Keys Tab ────────────────────────────────────────────────────────────

class _ApiKeysTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keysAsync = ref.watch(waApiKeyListProvider);
    final theme = Theme.of(context);

    return keysAsync.when(
      data: (keys) {
        if (keys.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.key_off_rounded,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant
                        .withOpacity(0.3)),
                const SizedBox(height: 12),
                Text('No API keys configured',
                    style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(waApiKeyListProvider),
          child: ListView.builder(
            itemCount: keys.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (ctx, i) =>
                _buildKeyCard(ctx, ref, keys[i]),
          ),
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: TextButton.icon(
          onPressed: () => ref.invalidate(waApiKeyListProvider),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ),
    );
  }

  Widget _buildKeyCard(BuildContext context, WidgetRef ref,
      Map<String, dynamic> key) {
    final theme = Theme.of(context);
    final name = key['name'] as String? ?? 'Unnamed';
    final role = key['role'] as String? ?? '—';
    final id = key['id'] as String? ?? '';
    final isRevoked = key['revoked'] as bool? ?? false;
    final maskedKey = key['maskedKey'] as String? ?? '••••••••';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isRevoked ? Colors.red : const Color(0xFF25D366))
                .withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isRevoked ? Icons.key_off_rounded : Icons.key_rounded,
            color:
                isRevoked ? Colors.red : const Color(0xFF25D366),
            size: 20,
          ),
        ),
        title: Text(name,
            style: theme.textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Role: $role • $maskedKey',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
            if (isRevoked)
              Text('REVOKED',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.w700)),
          ],
        ),
        trailing: !isRevoked
            ? IconButton(
                icon: const Icon(Icons.block_rounded, size: 20),
                tooltip: 'Revoke Key',
                onPressed: () async {
                  try {
                    final tenant =
                        ref.read(openWATenantServiceProvider);
                    final client = await tenant.getClient();
                    await client.revokeApiKey(id);
                    ref.invalidate(waApiKeyListProvider);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Revoke failed: $e')),
                      );
                    }
                  }
                },
              )
            : null,
        onTap: () {
          Clipboard.setData(ClipboardData(text: maskedKey));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied to clipboard')),
          );
        },
      ),
    );
  }
}

// ── Infrastructure Tab ──────────────────────────────────────────────────────

class _InfraTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infraAsync = ref.watch(waInfraStatusProvider);
    final theme = Theme.of(context);

    return infraAsync.when(
      data: (data) {
        if (data == null) {
          return Center(
            child: Text('Infrastructure status unavailable',
                style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          );
        }

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(waInfraStatusProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusCards(context, data),
                const SizedBox(height: 20),
                _buildDetailSection(context, data),
                const SizedBox(height: 20),
                _buildRestartButton(context, ref),
              ],
            ),
          ),
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: TextButton.icon(
          onPressed: () =>
              ref.invalidate(waInfraStatusProvider),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ),
    );
  }

  Widget _buildStatusCards(
      BuildContext context, Map<String, dynamic> data) {
    final uptime = data['uptime'] as String? ?? '—';
    final version = data['version'] as String? ?? '—';
    final memory = data['memoryUsage'] as String? ?? '—';
    final cpu = data['cpuUsage'] as String? ?? '—';

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final crossCount =
            constraints.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: [
            _InfraMetric(
                icon: Icons.timer_outlined,
                label: 'Uptime',
                value: uptime),
            _InfraMetric(
                icon: Icons.info_outline_rounded,
                label: 'Version',
                value: version),
            _InfraMetric(
                icon: Icons.memory_rounded,
                label: 'Memory',
                value: memory),
            _InfraMetric(
                icon: Icons.speed_rounded,
                label: 'CPU',
                value: cpu),
          ],
        );
      },
    );
  }

  Widget _buildDetailSection(
      BuildContext context, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final ignoredKeys = {
      'uptime',
      'version',
      'memoryUsage',
      'cpuUsage',
    };
    final extra = data.entries
        .where((e) => !ignoredKeys.contains(e.key))
        .toList();

    if (extra.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant
              .withOpacity(0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Details',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...extra.map((e) => Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(e.key,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(
                                    color: theme.colorScheme
                                        .onSurfaceVariant)),
                      ),
                      Expanded(
                        child: Text('${e.value}',
                            style: theme.textTheme.bodyMedium),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildRestartButton(
      BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Restart Server?'),
              content: const Text(
                  'This will restart the OpenWA gateway. '
                  'Active sessions may disconnect briefly.'),
              actions: [
                TextButton(
                    onPressed: () =>
                        Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange),
                    child: const Text('Restart')),
              ],
            ),
          );
          if (confirm == true) {
            try {
              final tenant =
                  ref.read(openWATenantServiceProvider);
              final client = await tenant.getClient();
              await client.requestRestart();
              ref.invalidate(waInfraStatusProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Restart initiated')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Restart failed: $e')),
                );
              }
            }
          }
        },
        icon: const Icon(Icons.restart_alt_rounded,
            color: Colors.orange),
        label: const Text('Restart Server'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.orange,
          side: const BorderSide(color: Colors.orange),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _InfraMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfraMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant
              .withOpacity(0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF25D366)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(label,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color:
                              theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
