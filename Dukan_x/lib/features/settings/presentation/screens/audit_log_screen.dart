// ============================================================================
// AUDIT LOG SCREEN
// ============================================================================
// Track system activities (security events, critical actions, errors).
// High-density data table with filtering.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/audit_repository.dart';
import '../../../../core/session/session_manager.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class AuditEntry {
  final String id;
  final DateTime timestamp;
  final String user;
  final String action; // 'LOGIN', 'DELETE_BILL', 'STOCK_ADJUST'
  final String details;
  final String severity; // 'INFO', 'WARNING', 'CRITICAL'

  AuditEntry({
    required this.id,
    required this.timestamp,
    required this.user,
    required this.action,
    required this.details,
    required this.severity,
  });
}

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  List<AuditEntry> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final userId = sl<SessionManager>().ownerId ?? '';
      final result = await sl<AuditRepository>().getLogsForUser(
        userId: userId,
        limit: 200,
      );

      if (result.isSuccess && result.data != null) {
        setState(() {
          _logs = result.data!
              .map(
                (log) => AuditEntry(
                  id: log.id.toString(),
                  timestamp: log.timestamp,
                  user: log.deviceId ?? 'Unknown',
                  action: log.action,
                  details: '${log.targetTableName}: ${log.recordId}',
                  severity: _mapActionToSeverity(log.action),
                ),
              )
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Failed to load audit logs: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapActionToSeverity(String action) {
    if (action.contains('DELETE')) {
      return 'CRITICAL';
    }
    if (action.contains('UPDATE') || action.contains('ADJUST')) {
      return 'WARNING';
    }
    return 'INFO';
  }

  List<AuditEntry> get _filteredLogs {
    return _logs.where((log) {
      final matchesSearch =
          log.details.toLowerCase().contains(
            _searchController.text.toLowerCase(),
          ) ||
          log.user.toLowerCase().contains(
            _searchController.text.toLowerCase(),
          ) ||
          log.action.toLowerCase().contains(
            _searchController.text.toLowerCase(),
          );

      final matchesFilter =
          _selectedFilter == 'All' || log.severity == _selectedFilter;

      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DesktopContentContainer(
      title: "System Audit Logs",
      subtitle: "Monitor security and critical actions",
      actions: [
        SizedBox(
          width: 300,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search logs...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: FuturisticColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
      child: Column(
        children: [
          Padding(padding: const EdgeInsets.all(16), child: _buildFilters()),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildLogTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        _buildFilterChip('All', Colors.blue),
        const SizedBox(width: 8),
        _buildFilterChip('INFO', FuturisticColors.success),
        const SizedBox(width: 8),
        _buildFilterChip(
          'WARNING',
          FuturisticColors.accent1,
        ), // Yellow/Orange equivalent
        const SizedBox(width: 8),
        _buildFilterChip('CRITICAL', FuturisticColors.error),
      ],
    );
  }

  Widget _buildFilterChip(String label, Color color) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : FuturisticColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.white.withOpacity(0.05),
      selectedColor: color.withOpacity(0.3),
      checkmarkColor: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? color : Colors.white.withOpacity(0.1),
        ),
      ),
      onSelected: (val) {
        setState(() => _selectedFilter = label); // Toggle behavior if needed
      },
    );
  }

  Widget _buildLogTable() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white.withOpacity(0.05),
              child: Row(
                children: [
                  _headerCell("Time", 2),
                  _headerCell("Severity", 1),
                  _headerCell("User", 2),
                  _headerCell("Action", 2),
                  _headerCell("Details", 5),
                ],
              ),
            ),
            // Table Body
            Expanded(
              child: ListView.separated(
                itemCount: _filteredLogs.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: Colors.white.withOpacity(0.05)),
                itemBuilder: (context, index) {
                  final log = _filteredLogs[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    color: index % 2 == 0
                        ? Colors.transparent
                        : Colors.white.withOpacity(0.02),
                    child: Row(
                      children: [
                        _bodyCell(
                          DateFormat('MMM dd HH:mm').format(log.timestamp),
                          2,
                          Colors.white70,
                        ),
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getSeverityColor(
                                log.severity,
                              ).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _getSeverityColor(
                                  log.severity,
                                ).withOpacity(0.5),
                              ),
                            ),
                            child: Text(
                              log.severity,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                // Removed GoogleFonts
                                color: _getSeverityColor(log.severity),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        _bodyCell(log.user, 2, Colors.white),
                        _bodyCell(log.action, 2, FuturisticColors.textPrimary),
                        _bodyCell(
                          log.details,
                          5,
                          FuturisticColors.textSecondary,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          // Removed GoogleFonts
          color: FuturisticColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _bodyCell(String text, int flex, Color color) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: Text(
          text,
          style: TextStyle(color: color, fontSize: 13), // Removed GoogleFonts
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'CRITICAL':
        return FuturisticColors.error;
      case 'WARNING':
        return FuturisticColors
            .accent1; // Use Accent1 (Cyan/Yellow equivalent) or Warning color
      default:
        return FuturisticColors.success; // Info
    }
  }
}
