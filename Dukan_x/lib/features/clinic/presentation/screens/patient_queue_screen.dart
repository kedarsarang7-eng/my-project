import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/clinic_repository.dart';

import '../widgets/clinic_breadcrumbs.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class PatientQueueScreen extends ConsumerStatefulWidget {
  const PatientQueueScreen({super.key});

  @override
  ConsumerState<PatientQueueScreen> createState() => _PatientQueueScreenState();
}

class _PatientQueueScreenState extends ConsumerState<PatientQueueScreen> {
  List<PatientQueueItem> _queue = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchQueue();
  }

  Future<void> _fetchQueue() async {
    setState(() => _isLoading = true);
    final result = await ref.read(clinicRepositoryProvider).getLiveQueue();
    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load queue: ${failure.message}')),
          );
        }
      },
      (queue) {
        if (mounted) {
          setState(() {
            _queue = queue;
          });
        }
      },
    );
    if (mounted) setState(() => _isLoading = false);
  }

  void _updateStatus(PatientQueueItem item, String status) async {
    final result = await ref.read(clinicRepositoryProvider).updateQueueStatus(item.id, status);
    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update: ${failure.message}')),
          );
        }
      },
      (success) {
        _fetchQueue(); // Refresh
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Patient Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchQueue,
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
        children: [
          ClinicBreadcrumbs(items: [
            BreadcrumbItem('Dashboard', onTap: () => Navigator.pop(context)),
            const BreadcrumbItem('Live Queue'),
          ]),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _queue.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No patients in queue', style: TextStyle(fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ), color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text('Patients will appear here when they check in', style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _fetchQueue,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchQueue,
                  child: ListView.builder(
                    itemCount: _queue.length,
                    itemBuilder: (context, index) {
                      final item = _queue[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(item.tokenNumber.toString()),
                          ),
                          title: Text(item.patientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Status: ${item.status}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.status == 'waiting')
                                IconButton(
                                  icon: const Icon(Icons.play_circle_fill, color: Colors.green),
                                  onPressed: () => _updateStatus(item, 'in-consultation'),
                                  tooltip: 'Start Consultation',
                                ),
                              if (item.status == 'in-consultation')
                                IconButton(
                                  icon: const Icon(Icons.check_circle, color: Colors.blue),
                                  onPressed: () => _updateStatus(item, 'completed'),
                                  tooltip: 'Mark Completed',
                                ),
                              IconButton(
                                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Cancel Appointment?'),
                                      content: Text('Remove ${item.patientName} from queue?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) _updateStatus(item, 'cancelled');
                                },
                                tooltip: 'Cancel',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
          ),
        ],
      ),
      ),
    );
  }
}
