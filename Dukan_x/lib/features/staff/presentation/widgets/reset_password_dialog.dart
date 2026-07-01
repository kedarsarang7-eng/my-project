import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/staff_profile_model.dart';
import '../providers/staff_management_provider.dart';

/// Reset Password Dialog
class ResetPasswordDialog extends ConsumerStatefulWidget {
  final String staffId;
  final String staffName;

  const ResetPasswordDialog({
    super.key,
    required this.staffId,
    required this.staffName,
  });

  @override
  ConsumerState<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<ResetPasswordDialog> {
  bool _isProcessing = false;
  ResetPasswordResponse? _result;

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return _buildResultView();
    }

    return AlertDialog(
      title: const Text('Reset Password'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reset the password for ${widget.staffName}?',
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
                      'A new temporary password will be generated. The staff member will be required to change it on next login.',
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
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
          onPressed: _isProcessing ? null : _resetPassword,
          icon: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.key),
          label: Text(_isProcessing ? 'Resetting...' : 'Reset Password'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF059669)),
          const SizedBox(width: 12),
          const Text('Password Reset'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'New temporary password for ${widget.staffName}:',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _result!.temporaryPassword,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _result!.temporaryPassword));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy password',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Share this password securely with the staff member. They will be required to set a new password on next login.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Future<void> _resetPassword() async {
    setState(() => _isProcessing = true);
    
    final result = await ref.read(staffManagementProvider.notifier).resetPassword(widget.staffId);
    
    if (mounted && result != null) {
      setState(() {
        _result = result;
        _isProcessing = false;
      });
    }
  }
}
