// ============================================================================
// WhatsApp Chat Screen — Chat list & messaging interface
// ============================================================================
// Displays active WhatsApp chats for the current business session.
// Read-only chat view with quick-send capabilities for invoices/templates.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dukanx/core/openwa/openwa_models.dart';
import 'package:dukanx/features/whatsapp/providers/whatsapp_providers.dart';

class WhatsAppChatScreen extends ConsumerStatefulWidget {
  const WhatsAppChatScreen({super.key});

  @override
  ConsumerState<WhatsAppChatScreen> createState() => _WhatsAppChatScreenState();
}

class _WhatsAppChatScreenState extends ConsumerState<WhatsAppChatScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(waConnectionProvider);
    final theme = Theme.of(context);

    if (!connectionState.isUsable) {
      return _buildNotConnected(context, connectionState);
    }

    final chatsAsync = ref.watch(waChatListProvider);

    return Scaffold(
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          _buildSearchHeader(context),
          // ── Chat List ───────────────────────────────────────────────
          Expanded(
            child: chatsAsync.when(
              data: (chats) {
                final filtered = _searchQuery.isEmpty
                    ? chats
                    : chats
                        .where((c) => c.name
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()))
                        .toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState(context);
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(waChatListProvider),
                  child: ListView.builder(
                    itemCount: filtered.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (ctx, index) =>
                        _buildChatTile(ctx, filtered[index]),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildErrorState(context, e.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chats',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, WAChat chat) {
    final theme = Theme.of(context);
    final lastMsg = chat.lastMessage ?? '';
    final time = chat.timestamp > 0
        ? _formatTimestamp(chat.timestamp)
        : '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: chat.isGroup
            ? Colors.teal.withOpacity(0.15)
            : const Color(0xFF25D366).withOpacity(0.15),
        child: Icon(
          chat.isGroup ? Icons.group_rounded : Icons.person_rounded,
          color: chat.isGroup ? Colors.teal : const Color(0xFF25D366),
          size: 22,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              chat.name,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: chat.unreadCount > 0
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (time.isNotEmpty)
            Text(
              time,
              style: theme.textTheme.bodySmall?.copyWith(
                color: chat.unreadCount > 0
                    ? const Color(0xFF25D366)
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: chat.unreadCount > 0
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              lastMsg,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (chat.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${chat.unreadCount}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        // TODO: Open chat detail / message thread
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening chat with ${chat.name}...')),
        );
      },
    );
  }

  Widget _buildNotConnected(
    BuildContext context,
    WAConnectionState state,
  ) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'WhatsApp Not Connected',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect your WhatsApp Business number to view and send messages.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
            Icons.chat_bubble_outline_rounded,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isEmpty ? 'No chats yet' : 'No matching chats',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to load chats',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => ref.invalidate(waChatListProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
