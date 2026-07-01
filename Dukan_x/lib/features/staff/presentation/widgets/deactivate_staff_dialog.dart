import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/staff_management_provider.dart';

/// Deactivate Staff Dialog
class DeactivateStaffDialog extends ConsumerStatefulWidget {
  final String staffId;
  final String staffName;

  const DeactivateStaffDialog({
    super.key,
    required this.staffId,
    required this.staffName,
  });

  @override
  ConsumerState<DeactivateStaffDialog> createState() => _DeactivateStaffDialogState();
}

class _DeactivateStaffDialogState extends ConsumerState<DeactivateStaffDialog> {
  final _reasonController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning, color: Color(0xFFDC2626)),
          const SizedBox(width: 12),
          const Text('Deactivate Staff'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to deactivate ${widget.staffName}?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Deactivating this account will immediately revoke their mobile app access.',
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (Optional)',
                hintText: 'Enter reason for deactivation',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isProcessing ? null : _deactivate,
          icon: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.block),
          label: Text(_isProcessing ? 'Deactivating...' : 'Deactivate'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _deactivate() async {
    setState(() => _isProcessing = true);
    
    final success = await ref.read(staffManagementProvider.notifier).deactivateStaff(
      widget.staffId,
    );
    
    if (mounted) {
      Navigator.pop(context);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.staffName} has been deactivated'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }
}
