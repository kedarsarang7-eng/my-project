import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import 'package:dukanx/core/localization/app_l10n.dart';
import '../../data/models/employee_model.dart';
import '../../data/repositories/staff_management_repository.dart';
import '../widgets/staff_loading_skeleton.dart';
import 'employee_detail_screen.dart';

/// Employee List Screen — virtualized for lists > 200 (Req 10.2).
///
/// Material 3, dark/light mode (Req 14.2).
/// Loading skeleton, empty, success, error states (Req 14.5).
/// Keyboard/mouse/touch input (Req 14.4).
/// All strings from l10n (Req 14.6).
/// No text overflow (Req 14.3).
class EmployeeListScreen extends ConsumerStatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  ConsumerState<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends ConsumerState<EmployeeListScreen> {
  List<EmployeeModel> _employees = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // In a real app this comes from the provider/repository
      // Placeholder: simulate loading from API
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        _employees = [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<EmployeeModel> get _filteredEmployees {
    if (_searchQuery.isEmpty) return _employees;
    final q = _searchQuery.toLowerCase();
    return _employees.where((e) {
      return e.fullName.toLowerCase().contains(q) ||
          (e.phone?.contains(q) ?? false) ||
          (e.email?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return AdaptiveScaffold(
      appBar: AppBar(
        title: Text(l10n.staffEmployees),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _searchFocus.requestFocus(),
            tooltip: l10n.staffSearchEmployees,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to add employee
        },
        icon: const Icon(Icons.person_add),
        label: Text(l10n.staffAddEmployee),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              controller: _searchController,
              focusNode: _searchFocus,
              hintText: l10n.staffSearchEmployees,
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
              ],
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Content
          Expanded(child: _buildBody(l10n, colorScheme)),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, ColorScheme colorScheme) {
    if (_isLoading) {
      return const StaffLoadingSkeleton(showHeader: false, itemCount: 8);
    }

    if (_error != null) {
      return StaffErrorState(
        message: l10n.staffErrorLoading,
        onRetry: _loadEmployees,
      );
    }

    final filtered = _filteredEmployees;
    if (filtered.isEmpty) {
      return StaffEmptyState(
        icon: Icons.people_outline,
        title: l10n.staffNoEmployees,
        description: l10n.staffNoEmployeesDesc,
        actionLabel: l10n.staffAddEmployee,
        onAction: () {
          // Navigate to add
        },
      );
    }

    // Virtualize lists beyond 200 entries (Req 10.2)
    return RefreshIndicator(
      onRefresh: _loadEmployees,
      child: BoundedBox(
        maxWidth: 900,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          // ListView.builder is already virtualized — only builds visible items
          itemCount: filtered.length,
          itemBuilder: (context, index) =>
              _buildEmployeeCard(filtered[index], colorScheme),
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(EmployeeModel employee, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Text(
            employee.fullName.isNotEmpty
                ? employee.fullName[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: AdaptiveText(
          employee.fullName,
          maxLines: 1,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: AdaptiveText(
          employee.phone ?? employee.email ?? '',
          maxLines: 1,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        trailing: _buildStatusChip(employee.status, colorScheme),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EmployeeDetailScreen(employee: employee),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status, ColorScheme colorScheme) {
    final l10n = context.l10n;
    final isActive = status == 'active';
    return Chip(
      label: Text(
        isActive ? l10n.staffActive : l10n.staffInactive,
        style: TextStyle(
          fontSize: 11,
          color: isActive ? Colors.green.shade700 : colorScheme.error,
        ),
      ),
      backgroundColor: isActive
          ? Colors.green.withOpacity(0.1)
          : colorScheme.errorContainer.withOpacity(0.3),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
