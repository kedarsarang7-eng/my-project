import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import 'package:dukanx/core/localization/app_l10n.dart';
import '../../data/models/task_model.dart';
import '../widgets/staff_loading_skeleton.dart';

/// Task List Screen — displays staff tasks with priority and status.
///
/// Material 3, dark/light mode (Req 14.2).
/// Loading/empty/error states (Req 14.5).
/// Keyboard/mouse/touch input (Req 14.4).
/// All strings from l10n (Req 14.6).
/// Virtualized list for >200 entries (Req 10.2).
class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  List<StaffTaskModel> _tasks = [];
  bool _isLoading = true;
  String? _error;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        _tasks = [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<StaffTaskModel> get _filteredTasks {
    if (_statusFilter == 'all') return _tasks;
    return _tasks.where((t) => t.status == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return AdaptiveScaffold(
      appBar: AppBar(title: Text(l10n.staffTasks), centerTitle: false),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to create task
        },
        icon: const Icon(Icons.add_task),
        label: Text(l10n.staffCreateTask),
      ),
      body: _isLoading
          ? const StaffLoadingSkeleton(showHeader: false, itemCount: 6)
          : _error != null
          ? StaffErrorState(
              message: l10n.staffErrorLoading,
              onRetry: _loadTasks,
            )
          : Column(
              children: [
                _buildFilterChips(l10n, colorScheme),
                Expanded(child: _buildTaskList(l10n, colorScheme)),
              ],
            ),
    );
  }

  Widget _buildFilterChips(AppLocalizations l10n, ColorScheme colorScheme) {
    final filters = {
      'all': l10n.staffTotal,
      'open': l10n.staffOpen,
      'in_progress': l10n.staffInProgress,
      'done': l10n.staffCompleted,
      'blocked': l10n.staffBlocked,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.entries.map((entry) {
          final isSelected = _statusFilter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: (_) => setState(() => _statusFilter = entry.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTaskList(AppLocalizations l10n, ColorScheme colorScheme) {
    final tasks = _filteredTasks;

    if (tasks.isEmpty) {
      return StaffEmptyState(
        icon: Icons.task_alt,
        title: l10n.staffNoTasks,
        description: l10n.staffNoTasksDesc,
        actionLabel: l10n.staffCreateTask,
        onAction: () {},
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: BoundedBox(
        maxWidth: 800,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: tasks.length,
          itemBuilder: (context, index) =>
              _buildTaskCard(tasks[index], l10n, colorScheme),
        ),
      ),
    );
  }

  Widget _buildTaskCard(
    StaffTaskModel task,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildPriorityIndicator(task.priority),
        title: AdaptiveText(
          task.title,
          maxLines: 2,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: AdaptiveText(
          _statusLabel(task.status, l10n),
          maxLines: 1,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        trailing: task.checklist != null && task.checklist!.isNotEmpty
            ? Text(
                '${task.checklist!.where((c) => c.done).length}/${task.checklist!.length}',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colorScheme.primary),
              )
            : null,
      ),
    );
  }

  Widget _buildPriorityIndicator(String priority) {
    Color color;
    switch (priority) {
      case 'high':
        color = Colors.red;
        break;
      case 'medium':
        color = Colors.orange;
        break;
      default:
        color = Colors.blue;
    }

    return Container(
      width: 4,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  String _statusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'open':
        return l10n.staffOpen;
      case 'in_progress':
        return l10n.staffInProgress;
      case 'done':
        return l10n.staffCompleted;
      case 'blocked':
        return l10n.staffBlocked;
      default:
        return status;
    }
  }
}
