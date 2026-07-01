// ============================================================================
// ACADEMIC COACHING â€” BIRTHDAY REMINDERS WIDGET
// ============================================================================

import 'package:flutter/material.dart';
import '../../data/repositories/ac_repository.dart';
import '../../../../core/di/service_locator.dart';

class AcBirthdayReminders extends StatefulWidget {
  final bool showAll;
  final VoidCallback? onViewAll;

  const AcBirthdayReminders({
    super.key,
    this.showAll = false,
    this.onViewAll,
  });

  @override
  State<AcBirthdayReminders> createState() => _AcBirthdayRemindersState();
}

class _AcBirthdayRemindersState extends State<AcBirthdayReminders> {
  late AcRepository _repository;
  Map<String, dynamic> _birthdays = {};
  bool _isLoading = true;
  String? _error;
  int _daysFilter = 7;

  @override
  void initState() {
    super.initState();
    _repository = sl<AcRepository>();
    _loadBirthdays();
  }

  Future<void> _loadBirthdays() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _repository.getUpcomingBirthdays(days: _daysFilter);
      setState(() {
        _birthdays = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load birthdays: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = _birthdays['today'] as List<dynamic>? ?? [];
    final tomorrow = _birthdays['tomorrow'] as List<dynamic>? ?? [];
    final thisWeek = _birthdays['thisWeek'] as List<dynamic>? ?? [];
    final upcoming = _birthdays['upcoming'] as List<dynamic>? ?? [];
    final total = _birthdays['total'] as int? ?? 0;

    if (_isLoading) {
      return _buildSkeleton();
    }

    if (_error != null) {
      return _buildError();
    }

    if (total == 0) {
      return _buildEmpty();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(total),
          const SizedBox(height: 16),
          if (today.isNotEmpty) ...[
            _buildSection('ðŸŽ‚ Today', today, const Color(0xFFDC2626)),
            const SizedBox(height: 16),
          ],
          if (tomorrow.isNotEmpty) ...[
            _buildSection('ðŸ“… Tomorrow', tomorrow, const Color(0xFFF59E0B)),
            const SizedBox(height: 16),
          ],
          if (thisWeek.isNotEmpty && widget.showAll) ...[
            _buildSection('ðŸ“† This Week', thisWeek, const Color(0xFF4F46E5)),
            const SizedBox(height: 16),
          ],
          if (upcoming.isNotEmpty && widget.showAll) ...[
            _buildSection('ðŸ—“ï¸ Upcoming', upcoming, const Color(0xFF059669)),
          ],
          if (!widget.showAll && (today.isNotEmpty || tomorrow.isNotEmpty)) ...[
            Center(
              child: TextButton(
                onPressed: widget.onViewAll,
                child: const Text('View All Birthdays'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.cake,
                color: Color(0xFFF59E0B),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Birthday Reminders',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$total upcoming birthdays',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (widget.showAll)
          DropdownButton<int>(
            value: _daysFilter,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 7, child: Text('Next 7 days')),
              DropdownMenuItem(value: 14, child: Text('Next 14 days')),
              DropdownMenuItem(value: 30, child: Text('Next 30 days')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => _daysFilter = v);
                _loadBirthdays();
              }
            },
          ),
      ],
    );
  }

  Widget _buildSection(String title, List<dynamic> birthdays, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${birthdays.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...birthdays.map((b) => _buildBirthdayCard(b)),
      ],
    );
  }

  Widget _buildBirthdayCard(dynamic birthday) {
    final name = birthday['name'] ?? 'Unknown';
    final age = birthday['ageTurning'] ?? 0;
    final daysUntil = birthday['daysUntil'] as int? ?? 0;
    final batchNames = (birthday['batchNames'] as List<dynamic>? ?? []).join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFEF3C7),
          child: Text(
            name.isNotEmpty ? name[0] : '?',
            style: const TextStyle(
              color: Color(0xFFF59E0B),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          'Turning $age â€¢ ${batchNames.isNotEmpty ? batchNames : 'No batch'}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (daysUntil > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  daysUntil == 1 ? '1 day' : '$daysUntil days',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.message, size: 18, color: Color(0xFF059669)),
              onPressed: () => _sendWish(birthday),
              tooltip: 'Send birthday wish',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 150, height: 16, color: Colors.grey.shade200),
                    const SizedBox(height: 8),
                    Container(width: 100, height: 12, color: Colors.grey.shade200),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: 12),
          Expanded(child: Text(_error ?? 'Error loading birthdays')),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBirthdays,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.cake_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No upcoming birthdays',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  void _sendWish(dynamic birthday) {
    // Show dialog to send birthday wish
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Birthday Wish'),
        content: Text('Send birthday greeting to ${birthday['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Birthday wish sent to ${birthday['name']}!')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
