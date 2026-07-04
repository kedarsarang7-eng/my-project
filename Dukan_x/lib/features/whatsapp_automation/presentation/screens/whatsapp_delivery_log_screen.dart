// ============================================================================
// WhatsApp Delivery Log Screen — Read-only log viewer
// ============================================================================
// Shows ONLY real statuses (queued/sent/delivered/read/failed/expired/suppressed).
// Never fabricates synthetic states.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../providers/whatsapp_delivery_log_provider.dart';
import '../widgets/delivery_status_chip.dart';

/// WhatsApp Delivery Log Screen — read-only log viewer.
class WhatsAppDeliveryLogScreen extends ConsumerWidget {
  const WhatsAppDeliveryLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(whatsappDeliveryLogProvider);

    return Scaffold(
      backgroundColor: FuturisticColors.background,
      appBar: AppBar(
        title: Text(
          'Delivery Logs',
          style: AppTypography.headlineSmall.copyWith(
            color: FuturisticColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: FuturisticColors.textPrimary),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(whatsappDeliveryLogProvider.notifier).refresh(),
            icon: Icon(Icons.refresh, color: FuturisticColors.primary),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BoundedBox(maxWidth: 900, child: _buildBody(context, ref, state)),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    WhatsAppDeliveryLogState state,
  ) {
    if (state.isDisabled) {
      return Center(
        child: Text(
          'Delivery logs are not available.',
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
                  ref.read(whatsappDeliveryLogProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 48, color: FuturisticColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'No delivery logs yet.',
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
      itemCount: state.entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final entry = state.entries[index];
        return GlassContainer(
          borderRadius: 10.0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              DeliveryLogStateChip(state: entry.state),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Message: ${entry.outboundMessageId}',
                      style: TextStyle(
                        color: FuturisticColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.reason != null)
                      Text(
                        entry.reason!,
                        style: TextStyle(
                          color: FuturisticColors.textMuted,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTimestamp(entry.timestamp),
                style: TextStyle(
                  color: FuturisticColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
