// ============================================================================
// ACTIVE SHIFT DASHBOARD - Staff Mobile App
// ============================================================================
// Purpose: Staff's active shift screen with live timer and quick actions
// Features:
//   - Live shift timer (HH:MM:SS)
//   - Quick stats: Today's sales, transactions, litres dispensed
//   - Record Transaction FAB
//   - Recent transactions list
//   - End Shift button with confirmation
//   - Overtime alert banner
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../services/attendance_service.dart';
import '../bloc/active_shift_bloc.dart';
import '../bloc/active_shift_event.dart';
import '../bloc/active_shift_state.dart';

/// Active Shift Dashboard
/// 
/// Main screen for staff members during their active shift.
/// Shows live timer, sales stats, and provides quick actions.
class ActiveShiftDashboard extends StatelessWidget {
  final String shiftId;
  final DateTime checkInTime;

  const ActiveShiftDashboard({
    super.key,
    required this.shiftId,
    required this.checkInTime,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ActiveShiftBloc(
        attendanceService: context.read<AttendanceService>(),
      )..add(LoadActiveShift(shiftId: shiftId)),
      child: _ActiveShiftView(
        shiftId: shiftId,
        checkInTime: checkInTime,
      ),
    );
  }
}

class _ActiveShiftView extends StatefulWidget {
  final String shiftId;
  final DateTime checkInTime;

  const _ActiveShiftView({
    required this.shiftId,
    required this.checkInTime,
  });

  @override
  State<_ActiveShiftView> createState() => _ActiveShiftViewState();
}

class _ActiveShiftViewState extends State<_ActiveShiftView>
    with TickerProviderStateMixin {
  late Timer _timer;
  Duration _elapsed = Duration.zero;
  late DateTime _checkInTime;

  @override
  void initState() {
    super.initState();
    _checkInTime = widget.checkInTime;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsed = DateTime.now().difference(_checkInTime);
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final hours = _elapsed.inHours.toString().padLeft(2, '0');
    final minutes = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  bool get _isOvertime => _elapsed.inHours >= 9;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<ActiveShiftBloc, ActiveShiftState>(
        listener: (context, state) {
          if (state is ShiftEnded) {
            Navigator.pushReplacementNamed(
              context,
              '/shift-summary',
              arguments: {
                'shiftId': widget.shiftId,
                'totalHours': _elapsed.inHours + (_elapsed.inMinutes % 60) / 60,
                'checkInTime': _checkInTime,
                'checkOutTime': DateTime.now(),
              },
            );
          }
          
          if (state is ActiveShiftError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          final stats = state is ActiveShiftLoaded ? state.stats : null;
          
          return CustomScrollView(
            slivers: [
              // Gradient Header with Timer
              SliverToBoxAdapter(
                child: _ShiftHeader(
                  formattedTime: _formattedTime,
                  isOvertime: _isOvertime,
                  checkInTime: _checkInTime,
                  elapsed: _elapsed,
                ),
              ),

              // Overtime Alert (if applicable)
              if (_isOvertime)
                SliverToBoxAdapter(
                  child: _OvertimeAlert(elapsed: _elapsed),
                ),

              // Quick Stats Cards
              SliverToBoxAdapter(
                child: _QuickStatsCards(stats: stats),
              ),

              // Recent Transactions Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Transactions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/transactions');
                        },
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                ),
              ),

              // Transactions List
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (state is ActiveShiftLoaded && 
                        state.recentTransactions != null &&
                        index < state.recentTransactions!.length) {
                      return _TransactionCard(
                        transaction: state.recentTransactions![index],
                      );
                    }
                    return const _EmptyTransactions();
                  },
                  childCount: (state is ActiveShiftLoaded && 
                          state.recentTransactions != null)
                      ? state.recentTransactions!.length.clamp(1, 5)
                      : 1,
                ),
              ),

              // Bottom padding for FAB
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          );
        },
      ),
      floatingActionButton: _RecordTransactionFab(shiftId: widget.shiftId),
      bottomNavigationBar: _EndShiftButton(
        onEndShift: () => _showEndShiftConfirmation(context),
      ),
    );
  }

  void _showEndShiftConfirmation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EndShiftConfirmationSheet(
        onConfirm: () {
          Navigator.pop(context);
          context.read<ActiveShiftBloc>().add(
            EndShift(shiftId: widget.shiftId),
          );
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }
}

// ============================================================================
// SHIFT HEADER
// ============================================================================

class _ShiftHeader extends StatelessWidget {
  final String formattedTime;
  final bool isOvertime;
  final DateTime checkInTime;
  final Duration elapsed;

  const _ShiftHeader({
    required this.formattedTime,
    required this.isOvertime,
    required this.checkInTime,
    required this.elapsed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOvertime
              ? [const Color(0xFF8B0000), const Color(0xFFFF4500)]
              : [const Color(0xFF1E3A5F), const Color(0xFF2D5A87)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'SHIFT ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Timer
              Text(
                formattedTime,
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Started at ${DateFormat('h:mm a').format(checkInTime)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              if (elapsed.inHours >= 8)
                Text(
                  '${elapsed.inHours - 8}h ${(elapsed.inMinutes % 60)}m overtime',
                  style: TextStyle(
                    color: Colors.yellow.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// OVERTIME ALERT
// ============================================================================

class _OvertimeAlert extends StatelessWidget {
  final Duration elapsed;

  const _OvertimeAlert({required this.elapsed});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.access_time, color: Colors.orange),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overtime Alert',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You have exceeded your scheduled shift time. Manager has been notified.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// QUICK STATS CARDS
// ============================================================================

class _QuickStatsCards extends StatelessWidget {
  final Map<String, dynamic>? stats;

  const _QuickStatsCards({this.stats});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    
    final totalSales = stats?['totalSales'] ?? 0.0;
    final transactions = stats?['transactionCount'] ?? 0;
    final fuelLitres = stats?['totalFuelLitres'] ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _StatCard(
            label: 'Sales',
            value: currencyFormatter.format(totalSales),
            icon: Icons.currency_rupee,
            color: Colors.green,
          ),
          const SizedBox(width: 12),
          _StatCard(
            label: 'Transactions',
            value: transactions.toString(),
            icon: Icons.receipt_long,
            color: Colors.blue,
          ),
          const SizedBox(width: 12),
          _StatCard(
            label: 'Fuel (L)',
            value: fuelLitres.toStringAsFixed(1),
            icon: Icons.local_gas_station,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TRANSACTION CARD
// ============================================================================

class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isPetrol = (transaction['fuelType'] ?? '').toString().toLowerCase() == 'petrol';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isPetrol ? Colors.orange : Colors.amber).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.local_gas_station,
              color: isPetrol ? Colors.orange : Colors.amber[700],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPetrol ? 'Petrol' : 'Diesel',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${transaction['litres']?.toStringAsFixed(1) ?? '0.0'} L',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFormatter.format(transaction['amount'] ?? 0),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('h:mm a').format(
                  DateTime.parse(transaction['timestamp'] ?? DateTime.now().toIso8601String()),
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No transactions yet',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap the + button to record your first sale',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// RECORD TRANSACTION FAB
// ============================================================================

class _RecordTransactionFab extends StatelessWidget {
  final String shiftId;

  const _RecordTransactionFab({required this.shiftId});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.pushNamed(
          context,
          '/record-transaction',
          arguments: {'shiftId': shiftId},
        );
      },
      icon: const Icon(Icons.add),
      label: const Text('Record Sale'),
      backgroundColor: const Color(0xFF1E3A5F),
    );
  }
}

// ============================================================================
// END SHIFT BUTTON
// ============================================================================

class _EndShiftButton extends StatelessWidget {
  final VoidCallback onEndShift;

  const _EndShiftButton({required this.onEndShift});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: onEndShift,
            icon: const Icon(Icons.logout),
            label: const Text(
              'End Shift',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// END SHIFT CONFIRMATION SHEET
// ============================================================================

class _EndShiftConfirmationSheet extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _EndShiftConfirmationSheet({
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.logout, color: Colors.red, size: 32),
          ),
          const SizedBox(height: 24),
          const Text(
            'End Your Shift?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Are you sure you want to end your current shift? This action cannot be undone.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('End Shift'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
