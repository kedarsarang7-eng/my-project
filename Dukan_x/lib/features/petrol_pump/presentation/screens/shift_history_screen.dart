import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../models/shift.dart';
import '../../services/shift_service.dart';
import '../../services/dispenser_service.dart';
import '../../models/nozzle.dart';
import '../../../staff/services/staff_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ShiftHistoryScreen extends StatefulWidget {
  const ShiftHistoryScreen({super.key});

  @override
  State<ShiftHistoryScreen> createState() => _ShiftHistoryScreenState();
}

class _ShiftHistoryScreenState extends State<ShiftHistoryScreen> {
  final _shiftService = sl<ShiftService>();
  final _staffService = sl<StaffService>();
  final _dispenserService = sl<DispenserService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shift Management')),
      body: Center(
        child: BoundedBox(
          maxWidth: 800,
          child: Column(
            children: [
              // Active Shift Status
              FutureBuilder<Shift?>(
                future: _shiftService.getActiveShift(),
                builder: (context, snapshot) {
                  final activeShift = snapshot.data;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    color: activeShift != null
                        ? FuturisticColors.paidBackground
                        : FuturisticColors.unpaidBackground,
                    child: Row(
                      children: [
                        Icon(
                          activeShift != null ? Icons.lock_open : Icons.lock,
                          color: activeShift != null
                              ? FuturisticColors.success
                              : FuturisticColors.error,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeShift != null
                                    ? 'Active Shift: ${activeShift.shiftName}'
                                    : 'No Active Shift',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (activeShift != null)
                                Text('Started: ${activeShift.startTime}'),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: activeShift == null
                              ? null
                              : () {
                                  _showNozzleAssignmentDialog(context, activeShift);
                                },
                          child: const Text('Assign Nozzles'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (activeShift != null) {
                              // Close shift - show confirmation with cash declaration
                              final cashController = TextEditingController();
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Close Shift'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Closing "${activeShift.shiftName}".\n\nPlease declare the physical cash amount collected during this shift.',
                                      ),
                                      const SizedBox(height: 16),
                                      TextField(
                                        controller: cashController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Declared Cash Amount (₹)',
                                          border: OutlineInputBorder(),
                                          prefixText: '₹ ',
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        if (cashController.text.isEmpty) {
                                          ScaffoldMessenger.of(ctx).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Please enter declared cash amount',
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        Navigator.pop(ctx, true);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                      ),
                                      child: const Text('Close Shift'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                try {
                                  // Use reconciliation-based shift close
                                  // Get current user from SessionManager
                                  final sessionManager = sl<SessionManager>();
                                  final currentUserId =
                                      sessionManager.userId ?? 'unknown';

                                  final declaredCash =
                                      double.tryParse(
                                        cashController.text.replaceAll(',', ''),
                                      ) ??
                                      0.0;

                                  await _shiftService.closeShift(
                                    activeShift.shiftId,
                                    closedBy: currentUserId,
                                    cashDeclared: declaredCash,
                                    notes: 'Closed from Shift History Screen',
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Shift closed successfully'),
                                      ),
                                    );
                                    setState(() {}); // Refresh
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    // Show specific error for cash declaration mismatch
                                    String errorMessage = 'Error: $e';
                                    if (e is CashDeclarationException) {
                                      errorMessage =
                                          'Cash Mismatch! Declared: ₹${e.declaredAmount}, Expected: ₹${e.expectedAmount}. Variance: ₹${e.variance.abs()}';
                                    } else if (e is ShiftReconciliationException) {
                                      errorMessage =
                                          'Reconciliation Error: ${e.message}';
                                    }

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(errorMessage),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 5),
                                        action: SnackBarAction(
                                          label: 'Details',
                                          textColor: Colors.white,
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Closure Error'),
                                                content: Text(e.toString()),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(ctx),
                                                    child: const Text('OK'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                            } else {
                              // Open new shift - show dialog
                              _showOpenShiftDialog(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: activeShift != null
                                ? Colors.orange
                                : FuturisticColors.success,
                          ),
                          child: Text(activeShift != null ? 'Close' : 'Open New'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              // History
              Expanded(
                child: StreamBuilder<List<Shift>>(
                  stream: _shiftService.getShiftHistory(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final shifts = snapshot.data ?? [];

                    return ListView.separated(
                      itemCount: shifts.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final shift = shifts[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: shift.status == ShiftStatus.open
                                ? FuturisticColors.success
                                : Colors.grey,
                            child: const Icon(Icons.history, color: Colors.white),
                          ),
                          title: Text('${shift.shiftName} (${shift.status.name})'),
                          subtitle: Text(
                            'Sales: ₹${shift.totalSaleAmount.toStringAsFixed(2)}',
                          ),
                          trailing: Text(shift.startTime.toString().split(' ')[0]),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOpenShiftDialog(BuildContext context) async {
    final nameController = TextEditingController(
      text:
          'Shift ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
    );

    // Fetch active staff
    final allStaff = await _staffService.getAllStaff(activeOnly: true);
    final selectedStaffIds = <String>{};

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Open New Shift'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Shift Name',
                      hintText: 'e.g. Morning Shift',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Assign Staff:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (allStaff.isEmpty)
                    const Text(
                      'No active staff found.',
                      style: TextStyle(color: Colors.red),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: allStaff.length,
                        itemBuilder: (ctx, i) {
                          final staff = allStaff[i];
                          final isSelected = selectedStaffIds.contains(
                            staff.id,
                          );
                          return CheckboxListTile(
                            title: Text(staff.name),
                            subtitle: Text(staff.role.name),
                            value: isSelected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  selectedStaffIds.add(staff.id);
                                } else {
                                  selectedStaffIds.remove(staff.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedStaffIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please select at least one staff member',
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  try {
                    await _shiftService.openShift(
                      nameController.text,
                      selectedStaffIds.toList(),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Shift opened successfully'),
                        ),
                      );
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ShiftHistoryScreen(),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FuturisticColors.success,
                ),
                child: const Text('Open Shift'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showNozzleAssignmentDialog(BuildContext context, Shift shift) async {
    // 1. Fetch Staff
    final staffList = <Map<String, dynamic>>[];
    for (final id in shift.assignedEmployeeIds) {
      final staff = await _staffService.getStaffById(id);
      if (staff != null) {
        staffList.add({'id': staff.id, 'name': staff.name});
      }
    }

    if (staffList.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No staff assigned to this shift.')),
        );
      }
      return;
    }

    // 2. Fetch Nozzles
    final dispensers = await _dispenserService.getDispensers().first;
    final allNozzles = <Nozzle>[];
    for (final d in dispensers) {
      final nozzles = await _dispenserService
          .getNozzlesByDispenser(d.dispenserId)
          .first;
      allNozzles.addAll(nozzles);
    }

    if (allNozzles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No nozzles found.')));
      }
      return;
    }

    if (!mounted) return;

    // 3. Show Dialog
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Assign Nozzles to Staff'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: allNozzles.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (ctx, i) {
                  final nozzle = allNozzles[i];
                  return ListTile(
                    title: Text('Nozzle: ${nozzle.fuelTypeName}'),
                    subtitle: Text(
                      'Current: ${nozzle.closingReading.toStringAsFixed(2)}',
                    ),
                    trailing: DropdownButton<String>(
                      hint: const Text('Select Staff'),
                      items: staffList
                          .map(
                            (s) => DropdownMenuItem(
                              value: s['id'] as String,
                              child: Text(s['name']),
                            ),
                          )
                          .toList(),
                      onChanged: (staffId) async {
                        if (staffId != null) {
                          await _shiftService.assignNozzleToStaff(
                            shift.shiftId,
                            staffId,
                            nozzle.nozzleId,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Assigned to ${staffList.firstWhere((e) => e['id'] == staffId)['name']}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }
}
