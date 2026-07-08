// ============================================================================
// WhatsApp Connection Screen — QR Code scanning & session management
// ============================================================================
// Entry point for WhatsApp setup. Shows connection status, QR code for
// scanning, session health, and reconnection controls.
// Uses the DukanX responsive layout system for cross-platform support.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dukanx/core/openwa/openwa_config.dart';
import 'package:dukanx/core/openwa/openwa_models.dart';
import 'package:dukanx/core/openwa/openwa_tenant_service.dart';
import 'package:dukanx/features/whatsapp/providers/whatsapp_providers.dart';

class WhatsAppConnectionScreen extends ConsumerStatefulWidget {
  const WhatsAppConnectionScreen({super.key});

  @override
  ConsumerState<WhatsAppConnectionScreen> createState() =>
      _WhatsAppConnectionScreenState();
}

class _WhatsAppConnectionScreenState
    extends ConsumerState<WhatsAppConnectionScreen> {
  bool _isProvisioning = false;

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(waConnectionProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(waConnectionProvider.notifier).refresh();
        },
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildHeader(context, connectionState),
            ),

            // ── Main Content ────────────────────────────────────────────
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: _buildContent(context, connectionState),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WAConnectionState state) {
    final theme = Theme.of(context);
    final isConnected = state == WAConnectionState.connected;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isConnected
              ? [
                  const Color(0xFF25D366).withOpacity(0.15),
                  const Color(0xFF128C7E).withOpacity(0.08),
                ]
              : [
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  theme.colorScheme.surface,
                ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? const Color(0xFF25D366).withOpacity(0.15)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.chat_rounded,
                    size: 28,
                    color: isConnected
                        ? const Color(0xFF25D366)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WhatsApp',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildStatusChip(context, state),
                    ],
                  ),
                ),
                if (isConnected)
                  IconButton(
                    onPressed: () => _showDisconnectDialog(context),
                    icon: const Icon(Icons.link_off_rounded),
                    tooltip: 'Disconnect',
                    style: IconButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, WAConnectionState state) {
    final theme = Theme.of(context);
    Color bgColor;
    Color fgColor;
    String label;
    IconData icon;

    switch (state) {
      case WAConnectionState.connected:
        bgColor = const Color(0xFF25D366).withOpacity(0.15);
        fgColor = const Color(0xFF25D366);
        label = 'Connected';
        icon = Icons.check_circle_outline_rounded;
      case WAConnectionState.connecting:
        bgColor = Colors.amber.withOpacity(0.15);
        fgColor = Colors.amber.shade700;
        label = 'Connecting...';
        icon = Icons.sync_rounded;
      case WAConnectionState.qrReady:
        bgColor = Colors.blue.withOpacity(0.15);
        fgColor = Colors.blue;
        label = 'Scan QR Code';
        icon = Icons.qr_code_scanner_rounded;
      case WAConnectionState.disconnected:
        bgColor = theme.colorScheme.error.withOpacity(0.1);
        fgColor = theme.colorScheme.error;
        label = 'Disconnected';
        icon = Icons.cloud_off_rounded;
      case WAConnectionState.notProvisioned:
        bgColor = theme.colorScheme.surfaceContainerHighest;
        fgColor = theme.colorScheme.onSurfaceVariant;
        label = 'Not Connected';
        icon = Icons.link_off_rounded;
      case WAConnectionState.loading:
        bgColor = theme.colorScheme.surfaceContainerHighest;
        fgColor = theme.colorScheme.onSurfaceVariant;
        label = 'Checking...';
        icon = Icons.hourglass_top_rounded;
      case WAConnectionState.error:
        bgColor = theme.colorScheme.error.withOpacity(0.1);
        fgColor = theme.colorScheme.error;
        label = 'Error';
        icon = Icons.error_outline_rounded;
      case WAConnectionState.unavailable:
        bgColor = theme.colorScheme.surfaceContainerHighest;
        fgColor = theme.colorScheme.onSurfaceVariant;
        label = 'Unavailable';
        icon = Icons.block_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fgColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WAConnectionState state) {
    switch (state) {
      case WAConnectionState.unavailable:
        return _buildUnavailableState(context);
      case WAConnectionState.notProvisioned:
        return _buildSetupState(context);
      case WAConnectionState.loading:
        return const Center(child: CircularProgressIndicator());
      case WAConnectionState.connecting:
        return _buildConnectingState(context);
      case WAConnectionState.qrReady:
        return _buildQRState(context);
      case WAConnectionState.connected:
        return _buildConnectedState(context);
      case WAConnectionState.disconnected:
        return _buildDisconnectedState(context);
      case WAConnectionState.error:
        return _buildErrorState(context);
    }
  }

  Widget _buildUnavailableState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'WhatsApp Gateway Not Configured',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contact your administrator to set up the WhatsApp gateway.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSetupState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.chat_rounded,
                size: 56,
                color: Color(0xFF25D366),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Connect WhatsApp',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Link your WhatsApp Business number to send invoices, '
              'payment reminders, and order confirmations directly '
              'from DukanX.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Feature highlights
            ..._buildFeatureList(theme),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _isProvisioning ? null : _handleSetup,
              icon: _isProvisioning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.qr_code_scanner_rounded),
              label: Text(_isProvisioning ? 'Setting up...' : 'Get Started'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFeatureList(ThemeData theme) {
    const features = [
      (Icons.receipt_long_rounded, 'Send invoices & receipts'),
      (Icons.notifications_active_rounded, 'Payment reminders'),
      (Icons.campaign_rounded, 'Marketing campaigns'),
      (Icons.schedule_rounded, 'Appointment reminders'),
    ];

    return features.map((f) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(f.$1, size: 20, color: const Color(0xFF25D366)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                f.$2,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: const Color(0xFF25D366).withOpacity(0.6),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildConnectingState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: Color(0xFF25D366),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Connecting to WhatsApp...',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we establish the connection.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRState(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = ref.read(waConnectionProvider.notifier);
    final qrCode = notifier.qrCode;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scan QR Code',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Open WhatsApp on your phone → Settings → Linked Devices → Link a Device',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // QR Code display
            Container(
              width: 280,
              height: 280,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: qrCode != null && qrCode.qrCode.isNotEmpty
                  ? Center(
                      child: Text(
                        'QR Code Ready\n\n${qrCode.qrCode.substring(0, 20)}...',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code_2_rounded,
                            size: 80,
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Loading QR Code...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => notifier.fetchQRCode(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh QR Code'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedState(BuildContext context) {
    final theme = Theme.of(context);
    final sessionAsync = ref.watch(waSessionProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 48,
                color: Color(0xFF25D366),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'WhatsApp Connected',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF25D366),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your business WhatsApp is linked and ready to use.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Session details card
            sessionAsync.when(
              data: (session) {
                if (session == null) return const SizedBox.shrink();
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _infoRow(
                          theme,
                          Icons.phone_android_rounded,
                          'Phone',
                          session.phone ?? 'N/A',
                        ),
                        const Divider(height: 20),
                        _infoRow(
                          theme,
                          Icons.person_rounded,
                          'Name',
                          session.pushName ?? session.name,
                        ),
                        const Divider(height: 20),
                        _infoRow(
                          theme,
                          Icons.access_time_rounded,
                          'Status',
                          session.status.label,
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDisconnectedState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 56,
            color: theme.colorScheme.error.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'WhatsApp Disconnected',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your WhatsApp session was disconnected. Tap reconnect to restore.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              ref.read(waConnectionProvider.notifier).startSession();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reconnect'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = ref.read(waConnectionProvider.notifier);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 56,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Connection Error',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            notifier.errorMessage ?? 'An unexpected error occurred.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => notifier.refresh(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSetup() async {
    setState(() => _isProvisioning = true);
    try {
      // For now, we use a placeholder admin key.
      // In production, the admin API key is fetched from backend config
      // or injected via the DukanX backend proxy.
      final tenantService = ref.read(openWATenantServiceProvider);

      // Prompt user — in production this would come from backend
      if (!mounted) return;
      final adminKey = await _showApiKeyDialog(context);
      if (adminKey == null || adminKey.isEmpty) {
        setState(() => _isProvisioning = false);
        return;
      }

      await tenantService.provisionSession(adminApiKey: adminKey);
      ref.read(waConnectionProvider.notifier).startSession();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProvisioning = false);
    }
  }

  Future<String?> _showApiKeyDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('OpenWA API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the admin API key from your OpenWA gateway '
              'to connect this business.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'owk_...',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _showDisconnectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect WhatsApp?'),
        content: const Text(
          'This will unlink your WhatsApp Business number from DukanX. '
          'You can reconnect later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(waConnectionProvider.notifier).disconnect();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}
