// ============================================================================
// NotificationPreferencesPage — shared Flutter widget for the Unified
// Notification System.
// ----------------------------------------------------------------------------
// Single page that lets the signed-in user configure:
//
//   * per-category channels (matrix of category x channel checkboxes)
//   * per-event channels (search-and-add list, channel checkboxes per row)
//   * Quiet_Hours start/end times + IANA timezone label
//   * mute_targets (list of `target_id` (+ optional `event_name`))
//
// Validates: REQ 11.4.
//
// Behaviour:
//   * Loads via `client.getUserPreferences()` on mount; shows a loader
//     until the round-trip resolves.
//   * Save button calls `client.setUserPreferences(prefs)`. The endpoint is
//     idempotent (REQ 4.9 / REQ 7.7), so a double-tap or a retry produces
//     the same stored state.
//   * Per-event entries take the same channel set as the category matrix;
//     unsetting all channels for an event is treated as opt-out (the empty
//     list is sent verbatim, REQ 7.2).
//
// The page is intentionally stateless w.r.t. the host -- the only side
// effect on save is the HTTP call and an optional `onSaved` callback so the
// host can pop the route or refresh dependent widgets.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import 'notifications_ui_client.dart';

/// Channels rendered as columns in the category and per-event matrices.
const List<String> kPreferenceChannels = <String>[
  'in_app',
  'push',
  'email',
  'sms',
  'webhook',
];

/// Categories rendered as rows in the category matrix. Mirrors the
/// `category` enum on the schema so the matrix can never drift from the
/// registry.
const List<String> kPreferenceCategories = <String>[
  'billing',
  'orders',
  'payments',
  'inventory',
  'users',
  'system',
  'delivery',
  'reports',
];

/// Optional callback fired after a successful save. Hosts can use it to
/// pop the route, refresh a dependent screen, or show a success snackbar.
typedef PreferencesSaved = void Function(UserPreferences saved);

class NotificationPreferencesPage extends StatefulWidget {
  final NotificationsUiClient client;
  final PreferencesSaved? onSaved;

  /// Optional title shown in the AppBar. Defaults to "Notification settings".
  final String title;

  const NotificationPreferencesPage({
    super.key,
    required this.client,
    this.onSaved,
    this.title = 'Notification settings',
  });

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  /// Mutable working copy. Initialised from the server response on mount.
  UserPreferences _prefs = const UserPreferences();

  bool _loading = true;
  bool _saving = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final got = await widget.client.getUserPreferences();
      if (!mounted) return;
      setState(() {
        _prefs = got;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
    });
    try {
      final saved = await widget.client.setUserPreferences(_prefs);
      if (!mounted) return;
      setState(() {
        _prefs = saved;
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preferences saved')));
      final cb = widget.onSaved;
      if (cb != null) cb(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  // ---- Mutators ------------------------------------------------------------

  void _toggleCategoryChannel(String category, String channel, bool on) {
    final next = Map<String, List<String>>.from(_prefs.perCategoryChannels);
    final current = List<String>.from(next[category] ?? const <String>[]);
    if (on) {
      if (!current.contains(channel)) current.add(channel);
    } else {
      current.remove(channel);
    }
    next[category] = current;
    setState(() {
      _prefs = _prefs.copyWith(perCategoryChannels: next);
    });
  }

  void _toggleEventChannel(String eventName, String channel, bool on) {
    final next = Map<String, List<String>>.from(_prefs.perEventChannels);
    final current = List<String>.from(next[eventName] ?? const <String>[]);
    if (on) {
      if (!current.contains(channel)) current.add(channel);
    } else {
      current.remove(channel);
    }
    next[eventName] = current;
    setState(() {
      _prefs = _prefs.copyWith(perEventChannels: next);
    });
  }

  void _addPerEvent(String eventName) {
    final trimmed = eventName.trim();
    if (trimmed.isEmpty) return;
    if (_prefs.perEventChannels.containsKey(trimmed)) return;
    final next = Map<String, List<String>>.from(_prefs.perEventChannels);
    next[trimmed] = const <String>[];
    setState(() {
      _prefs = _prefs.copyWith(perEventChannels: next);
    });
  }

  void _removePerEvent(String eventName) {
    final next = Map<String, List<String>>.from(_prefs.perEventChannels);
    next.remove(eventName);
    setState(() {
      _prefs = _prefs.copyWith(perEventChannels: next);
    });
  }

  void _setQuietHoursStart(TimeOfDay? t) {
    setState(() {
      _prefs = _prefs.copyWith(
        quietHoursStart: t == null ? null : _formatTime(t),
      );
    });
  }

  void _setQuietHoursEnd(TimeOfDay? t) {
    setState(() {
      _prefs = _prefs.copyWith(
        quietHoursEnd: t == null ? null : _formatTime(t),
      );
    });
  }

  void _setQuietHoursTimezone(String tz) {
    final trimmed = tz.trim();
    setState(() {
      _prefs = _prefs.copyWith(
        quietHoursTimezone: trimmed.isEmpty ? null : trimmed,
      );
    });
  }

  void _addMute(String targetId, String? eventName) {
    final trimmed = targetId.trim();
    if (trimmed.isEmpty) return;
    final next = List<MuteTarget>.from(_prefs.muteTargets);
    final existing = next.indexWhere(
      (m) => m.targetId == trimmed && (m.eventName ?? '') == (eventName ?? ''),
    );
    if (existing >= 0) return;
    next.add(
      MuteTarget(
        targetId: trimmed,
        eventName: (eventName == null || eventName.trim().isEmpty)
            ? null
            : eventName.trim(),
      ),
    );
    setState(() {
      _prefs = _prefs.copyWith(muteTargets: next);
    });
  }

  void _removeMute(MuteTarget mute) {
    final next = List<MuteTarget>.from(_prefs.muteTargets);
    next.removeWhere(
      (m) => m.targetId == mute.targetId && m.eventName == mute.eventName,
    );
    setState(() {
      _prefs = _prefs.copyWith(muteTargets: next);
    });
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  // ---- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Save',
              icon: const Icon(Icons.save),
              onPressed: _loading ? null : _save,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(
                'Could not load preferences',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '$_loadError',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _CategoryMatrix(prefs: _prefs, onToggle: _toggleCategoryChannel),
        const SizedBox(height: 24),
        _PerEventList(
          prefs: _prefs,
          onAdd: _addPerEvent,
          onRemove: _removePerEvent,
          onToggle: _toggleEventChannel,
        ),
        const SizedBox(height: 24),
        _QuietHoursSection(
          startLabel: _prefs.quietHoursStart,
          endLabel: _prefs.quietHoursEnd,
          timezone: _prefs.quietHoursTimezone,
          onPickStart: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime:
                  _parseTime(_prefs.quietHoursStart) ??
                  const TimeOfDay(hour: 22, minute: 0),
            );
            _setQuietHoursStart(picked);
          },
          onPickEnd: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime:
                  _parseTime(_prefs.quietHoursEnd) ??
                  const TimeOfDay(hour: 7, minute: 0),
            );
            _setQuietHoursEnd(picked);
          },
          onClearStart: () => _setQuietHoursStart(null),
          onClearEnd: () => _setQuietHoursEnd(null),
          onTimezoneChanged: _setQuietHoursTimezone,
        ),
        const SizedBox(height: 24),
        _MuteTargetsSection(
          targets: _prefs.muteTargets,
          onAdd: _addMute,
          onRemove: _removeMute,
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------------
// Section: per-category channel matrix.
// ----------------------------------------------------------------------------

class _CategoryMatrix extends StatelessWidget {
  final UserPreferences prefs;
  final void Function(String category, String channel, bool on) onToggle;

  const _CategoryMatrix({required this.prefs, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Per-category channels',
      subtitle:
          'Choose which channels deliver each top-level category. Empty row = opt out.',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: <DataColumn>[
            const DataColumn(label: Text('Category')),
            ...kPreferenceChannels.map(
              (c) => DataColumn(label: Text(_channelLabel(c))),
            ),
          ],
          rows: kPreferenceCategories.map((category) {
            final selected =
                prefs.perCategoryChannels[category] ?? const <String>[];
            return DataRow(
              cells: <DataCell>[
                DataCell(Text(_categoryLabel(category))),
                ...kPreferenceChannels.map(
                  (channel) => DataCell(
                    Checkbox(
                      value: selected.contains(channel),
                      onChanged: (v) => onToggle(category, channel, v ?? false),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Section: per-event channels.
// ----------------------------------------------------------------------------

class _PerEventList extends StatefulWidget {
  final UserPreferences prefs;
  final void Function(String eventName) onAdd;
  final void Function(String eventName) onRemove;
  final void Function(String eventName, String channel, bool on) onToggle;

  const _PerEventList({
    required this.prefs,
    required this.onAdd,
    required this.onRemove,
    required this.onToggle,
  });

  @override
  State<_PerEventList> createState() => _PerEventListState();
}

class _PerEventListState extends State<_PerEventList> {
  final TextEditingController _addController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _addController.text.trim();
    if (value.isEmpty) return;
    widget.onAdd(value);
    _addController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.prefs.perEventChannels.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return _Section(
      title: 'Per-event channels',
      subtitle:
          'Override the category defaults for a specific event_name. Wins per REQ 7.2.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _addController,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'event_name (snake_case)',
                    hintText: 'e.g. billing.invoice.payment_received',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'No per-event overrides yet.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            for (final entry in entries)
              _PerEventRow(
                eventName: entry.key,
                channels: entry.value,
                onToggle: (channel, on) =>
                    widget.onToggle(entry.key, channel, on),
                onRemove: () => widget.onRemove(entry.key),
              ),
        ],
      ),
    );
  }
}

class _PerEventRow extends StatelessWidget {
  final String eventName;
  final List<String> channels;
  final void Function(String channel, bool on) onToggle;
  final VoidCallback onRemove;

  const _PerEventRow({
    required this.eventName,
    required this.channels,
    required this.onToggle,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    eventName,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              children: kPreferenceChannels
                  .map(
                    (c) => FilterChip(
                      label: Text(_channelLabel(c)),
                      selected: channels.contains(c),
                      onSelected: (v) => onToggle(c, v),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Section: Quiet Hours.
// ----------------------------------------------------------------------------

class _QuietHoursSection extends StatefulWidget {
  final String? startLabel;
  final String? endLabel;
  final String? timezone;
  final Future<void> Function() onPickStart;
  final Future<void> Function() onPickEnd;
  final VoidCallback onClearStart;
  final VoidCallback onClearEnd;
  final void Function(String) onTimezoneChanged;

  const _QuietHoursSection({
    required this.startLabel,
    required this.endLabel,
    required this.timezone,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onClearStart,
    required this.onClearEnd,
    required this.onTimezoneChanged,
  });

  @override
  State<_QuietHoursSection> createState() => _QuietHoursSectionState();
}

class _QuietHoursSectionState extends State<_QuietHoursSection> {
  late final TextEditingController _tzController;

  @override
  void initState() {
    super.initState();
    _tzController = TextEditingController(text: widget.timezone ?? '');
  }

  @override
  void didUpdateWidget(covariant _QuietHoursSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.timezone != _tzController.text) {
      _tzController.text = widget.timezone ?? '';
    }
  }

  @override
  void dispose() {
    _tzController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Quiet hours',
      subtitle:
          'During this window non-critical push, email, and SMS deliveries are suppressed (REQ 7.3).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start'),
                  subtitle: Text(widget.startLabel ?? 'Not set'),
                  trailing: IconButton(
                    icon: const Icon(Icons.access_time),
                    onPressed: widget.onPickStart,
                  ),
                  onTap: widget.onPickStart,
                  onLongPress: widget.startLabel == null
                      ? null
                      : widget.onClearStart,
                ),
              ),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('End'),
                  subtitle: Text(widget.endLabel ?? 'Not set'),
                  trailing: IconButton(
                    icon: const Icon(Icons.access_time),
                    onPressed: widget.onPickEnd,
                  ),
                  onTap: widget.onPickEnd,
                  onLongPress: widget.endLabel == null
                      ? null
                      : widget.onClearEnd,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tzController,
            onChanged: widget.onTimezoneChanged,
            decoration: const InputDecoration(
              labelText: 'Timezone (IANA, e.g. Asia/Kolkata)',
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Section: muted targets.
// ----------------------------------------------------------------------------

class _MuteTargetsSection extends StatefulWidget {
  final List<MuteTarget> targets;
  final void Function(String targetId, String? eventName) onAdd;
  final void Function(MuteTarget mute) onRemove;

  const _MuteTargetsSection({
    required this.targets,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<_MuteTargetsSection> createState() => _MuteTargetsSectionState();
}

class _MuteTargetsSectionState extends State<_MuteTargetsSection> {
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _eventController = TextEditingController();

  @override
  void dispose() {
    _targetController.dispose();
    _eventController.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _targetController.text.trim();
    if (t.isEmpty) return;
    widget.onAdd(
      t,
      _eventController.text.trim().isEmpty
          ? null
          : _eventController.text.trim(),
    );
    _targetController.clear();
    _eventController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Muted targets',
      subtitle:
          'Notifications referencing a muted target_id are suppressed across every channel except un-mutable critical events (REQ 7.5).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _targetController,
                  decoration: const InputDecoration(
                    labelText: 'target_id',
                    hintText: 'e.g. customer:42',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _eventController,
                  decoration: const InputDecoration(
                    labelText: 'event_name (optional)',
                    hintText: 'leave blank to mute all events',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.volume_off),
                label: const Text('Mute'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.targets.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'No muted targets yet.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            for (final mute in widget.targets)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.volume_off_outlined),
                title: Text(mute.targetId),
                subtitle: Text(mute.eventName ?? 'all events'),
                trailing: IconButton(
                  tooltip: 'Unmute',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => widget.onRemove(mute),
                ),
              ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Helpers and shared section frame.
// ----------------------------------------------------------------------------

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

String _channelLabel(String channel) {
  switch (channel) {
    case 'in_app':
      return 'In-app';
    case 'push':
      return 'Push';
    case 'email':
      return 'Email';
    case 'sms':
      return 'SMS';
    case 'webhook':
      return 'Webhook';
    default:
      return channel;
  }
}

String _categoryLabel(String category) {
  if (category.isEmpty) return category;
  return category[0].toUpperCase() + category.substring(1);
}
