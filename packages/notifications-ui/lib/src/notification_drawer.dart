// ============================================================================
// NotificationDrawer — shared Flutter widget for the Unified Notification System.
// ----------------------------------------------------------------------------
// Renders a `created_at` DESCENDING list of notifications for the signed-in
// user with cursor-based pagination and a category filter.
//
// Validates: REQ 11.2, 11.5.
//
// Behaviour summary:
//   * Backed by `client.listNotifications(...)`. Pages of `pageSize` items
//     are appended to the list as the user scrolls within `loadMoreOffset`
//     of the bottom; `nextCursor == null` means the list is exhausted.
//   * Category filter chips on top change the active filter; selecting a
//     new chip resets the cursor and reloads the first page.
//   * Live updates: when the SDK delivers a new notification that matches
//     the active filter (or no filter), it's prepended to the list so the
//     user sees it without scrolling.
//   * On tap of an item, `client.markAsRead(id)` is invoked exactly once;
//     the local item is then mutated in place to show the read state. The
//     backend `markAsRead` is idempotent (REQ 4.6) so retries are safe.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notifications_sdk/notifications_sdk.dart';

import 'notifications_ui_client.dart';

/// Closed enum of categories rendered as filter chips. Mirrors the schema
/// `category` enum so the chip set can never drift from the registry.
const List<String> kNotificationCategories = <String>[
  'billing',
  'orders',
  'payments',
  'inventory',
  'users',
  'system',
  'delivery',
  'reports',
];

/// Optional callback invoked when an item is tapped. Host apps can use it
/// to navigate to the originating screen (`event_name` + `payload.target_id`)
/// in addition to the built-in `markAsRead` call.
typedef NotificationItemTap =
    void Function(BuildContext context, NotificationDelivery notification);

/// Optional builder for fully custom item rendering. When null the drawer
/// uses the default Material `ListTile` rendering.
typedef NotificationItemBuilder =
    Widget Function(
      BuildContext context,
      NotificationDelivery notification,
      bool isRead,
      VoidCallback onOpen,
    );

class NotificationDrawer extends StatefulWidget {
  /// HTTP client used to list notifications and call `markAsRead`.
  final NotificationsUiClient client;

  /// SDK whose `onNotification` stream prepends live items as they arrive.
  final NotificationsSdk sdk;

  /// Optional initial filter. `null` shows every category.
  final String? initialCategory;

  /// Page size passed to `listNotifications`. Defaults to 25.
  final int pageSize;

  /// Distance from the bottom (in pixels) at which the drawer pre-fetches
  /// the next page. Defaults to 240.
  final double loadMoreOffset;

  /// Optional override of the per-item rendering.
  final NotificationItemBuilder? itemBuilder;

  /// Optional secondary tap handler, called AFTER `markAsRead` succeeds.
  final NotificationItemTap? onItemTap;

  /// Locale-aware DateFormat pattern shown alongside each item. Defaults
  /// to a relative description (e.g. `2 min ago`).
  final String Function(DateTime createdAt)? timeFormatter;

  const NotificationDrawer({
    super.key,
    required this.client,
    required this.sdk,
    this.initialCategory,
    this.pageSize = 25,
    this.loadMoreOffset = 240,
    this.itemBuilder,
    this.onItemTap,
    this.timeFormatter,
  });

  @override
  State<NotificationDrawer> createState() => _NotificationDrawerState();
}

class _NotificationDrawerState extends State<NotificationDrawer> {
  /// All loaded items in display order (`created_at` DESC). Live deliveries
  /// are prepended; pagination appends at the tail.
  final List<NotificationDelivery> _items = <NotificationDelivery>[];

  /// `notification_id`s that have already been marked read by this drawer
  /// during the current session. Used to avoid double-marking.
  final Set<String> _readLocally = <String>{};

  /// `notification_id`s known to be unread (anything we haven't marked or
  /// observed as read). Drives the unread visual marker.
  final Set<String> _unread = <String>{};

  String? _activeCategory;
  String? _nextCursor;
  bool _hasMore = true;
  bool _loading = false;
  bool _initialLoaded = false;
  Object? _error;

  final ScrollController _scrollController = ScrollController();
  StreamSubscription<NotificationDelivery>? _sdkSub;

  @override
  void initState() {
    super.initState();
    _activeCategory = widget.initialCategory;
    _scrollController.addListener(_onScroll);
    _sdkSub = widget.sdk.onNotification().listen(_onLiveDelivery);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_loadFirstPage()),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _sdkSub?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loading) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels < widget.loadMoreOffset) {
      unawaited(_loadNextPage());
    }
  }

  void _onLiveDelivery(NotificationDelivery delivery) {
    if (!mounted) return;
    if (_activeCategory != null && delivery.category != _activeCategory) {
      // Outside the filter -- still track it so the unread set stays
      // accurate the moment the filter is removed.
      _unread.add(delivery.id);
      return;
    }
    setState(() {
      // Avoid duplicates if the same id was already loaded.
      _items.removeWhere((n) => n.id == delivery.id);
      _items.insert(0, delivery);
      _unread.add(delivery.id);
    });
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _items.clear();
      _readLocally.clear();
      _unread.clear();
      _nextCursor = null;
      _hasMore = true;
      _initialLoaded = false;
      _error = null;
      _loading = true;
    });
    await _fetchPage(reset: true);
    if (mounted) {
      setState(() {
        _initialLoaded = true;
        _loading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore || _loading) return;
    setState(() {
      _loading = true;
    });
    await _fetchPage(reset: false);
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _fetchPage({required bool reset}) async {
    try {
      final page = await widget.client.listNotifications(
        cursor: reset ? null : _nextCursor,
        category: _activeCategory,
        limit: widget.pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        for (final n in page.items) {
          // Treat anything coming back from the list as unread until the
          // user opens it -- the bell already represents the authoritative
          // count and filtering by status is configurable on the server.
          _unread.add(n.id);
        }
        _nextCursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _hasMore = false;
      });
    }
  }

  Future<void> _openItem(NotificationDelivery item) async {
    if (!_readLocally.contains(item.id)) {
      _readLocally.add(item.id);
      _unread.remove(item.id);
      try {
        await widget.client.markAsRead(item.id);
      } catch (_) {
        // Best-effort: re-mark as unread so the user can retry.
        if (!mounted) return;
        setState(() {
          _readLocally.remove(item.id);
          _unread.add(item.id);
        });
      }
      if (!mounted) return;
      setState(() {});
    }
    final cb = widget.onItemTap;
    if (cb != null) cb(context, item);
  }

  void _selectCategory(String? category) {
    if (_activeCategory == category) return;
    _activeCategory = category;
    unawaited(_loadFirstPage());
  }

  String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      if (widget.timeFormatter != null) return widget.timeFormatter!(dt);
      return _relativeTime(dt);
    } catch (_) {
      return iso;
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
  }

  String _two(int v) => v < 10 ? '0$v' : '$v';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Header(activeCategory: _activeCategory, onSelect: _selectCategory),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (!_initialLoaded && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return _ErrorState(
        error: _error!,
        onRetry: () => unawaited(_loadFirstPage()),
      );
    }
    if (_items.isEmpty) {
      return const _EmptyState();
    }

    final itemCount = _items.length + (_hasMore ? 1 : 0);
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = _items[index];
          final isRead = !_unread.contains(item.id);
          if (widget.itemBuilder != null) {
            return widget.itemBuilder!(
              context,
              item,
              isRead,
              () => _openItem(item),
            );
          }
          return _DefaultItem(
            item: item,
            isRead: isRead,
            timeLabel: _formatTimestamp(item.createdAt),
            onOpen: () => _openItem(item),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String? activeCategory;
  final void Function(String?) onSelect;

  const _Header({required this.activeCategory, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _chip(context, label: 'All', value: null),
      ...kNotificationCategories.map(
        (c) => _chip(context, label: _label(c), value: c),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: chips.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) => chips[i],
        ),
      ),
    );
  }

  String _label(String c) {
    if (c.isEmpty) return c;
    return c[0].toUpperCase() + c.substring(1);
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required String? value,
  }) {
    final selected = activeCategory == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelect(value),
    );
  }
}

class _DefaultItem extends StatelessWidget {
  final NotificationDelivery item;
  final bool isRead;
  final String timeLabel;
  final VoidCallback onOpen;

  const _DefaultItem({
    required this.item,
    required this.isRead,
    required this.timeLabel,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priority = item.priority.toLowerCase();
    final isHighPriority = priority == 'critical' || priority == 'high';
    final titleText =
        (item.payload['title'] as String?) ??
        (item.payload['subject'] as String?) ??
        item.eventName;
    final body =
        (item.payload['body'] as String?) ??
        (item.payload['message'] as String?) ??
        '';

    return ListTile(
      onTap: onOpen,
      leading: _LeadingIcon(
        priority: priority,
        category: item.category,
        unread: !isRead,
      ),
      title: Text(
        titleText,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: isRead ? FontWeight.w400 : FontWeight.w700,
        ),
      ),
      subtitle: body.isEmpty
          ? Text(timeLabel, style: theme.textTheme.bodySmall)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(timeLabel, style: theme.textTheme.bodySmall),
              ],
            ),
      trailing: isHighPriority
          ? Icon(Icons.priority_high, color: theme.colorScheme.error)
          : null,
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  final String priority;
  final String category;
  final bool unread;

  const _LeadingIcon({
    required this.priority,
    required this.category,
    required this.unread,
  });

  IconData _categoryIcon() {
    switch (category) {
      case 'billing':
        return Icons.receipt_long;
      case 'orders':
        return Icons.shopping_bag;
      case 'payments':
        return Icons.payments;
      case 'inventory':
        return Icons.inventory_2;
      case 'users':
        return Icons.person;
      case 'system':
        return Icons.settings;
      case 'delivery':
        return Icons.local_shipping;
      case 'reports':
        return Icons.bar_chart;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = priority == 'critical'
        ? theme.colorScheme.error
        : (priority == 'high'
              ? theme.colorScheme.tertiary
              : theme.colorScheme.primary);
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          foregroundColor: color,
          child: Icon(_categoryIcon()),
        ),
        if (unread)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 1),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.notifications_off,
              size: 48,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 12),
            Text(
              'No notifications yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'Could not load notifications',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '$error',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
