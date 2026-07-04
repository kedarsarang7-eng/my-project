// ============================================================================
// Computer Shop — Bulk Serial Intake Screen
// ============================================================================
// Features:
// - Accept 1-500 serials via a multi-line text input (one serial per line)
// - Reject the whole submission when the count is 0 or exceeds 500 (Req 12.4)
// - Validate each serial for format and intra-submission duplicates
//   before persisting only the valid, non-duplicate ones (Req 12.2, 12.3)
// - Report every rejected serial with its rejection reason
// - Surface persistence failures without marking anything as persisted
//   (Req 12.5)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import '../../providers/computer_job_providers.dart';
import '../../data/repositories/computer_repository.dart';
import '../../utils/computer_shop_validators.dart';

/// Minimum and maximum number of serials allowed per submission (Req 12.1,
/// 12.4).
const int _kMinSerials = 1;
const int _kMaxSerials = 500;

/// The outcome of client-side validation for a bulk serial submission.
class _ValidationOutcome {
  final List<String> validSerials;
  final List<BulkSerialRejection> rejected;

  const _ValidationOutcome({
    required this.validSerials,
    required this.rejected,
  });
}

/// Validates [rawSerials] for format and intra-submission duplicates.
///
/// The first occurrence of a value is treated as the canonical entry; any
/// later occurrence of the same value is reported as a duplicate rejection
/// (Req 12.2, 12.3).
_ValidationOutcome _validateSerials(List<String> rawSerials) {
  final seen = <String>{};
  final validSerials = <String>[];
  final rejected = <BulkSerialRejection>[];

  for (final raw in rawSerials) {
    final formatError = ComputerShopValidators.validateSerial(raw);
    if (formatError != null) {
      rejected.add(BulkSerialRejection(serial: raw, reason: formatError));
      continue;
    }
    final trimmed = raw.trim();
    if (seen.contains(trimmed)) {
      rejected.add(
        BulkSerialRejection(serial: raw, reason: 'Duplicate within submission'),
      );
      continue;
    }
    seen.add(trimmed);
    validSerials.add(trimmed);
  }

  return _ValidationOutcome(validSerials: validSerials, rejected: rejected);
}

class BulkSerialIntakeScreen extends ConsumerStatefulWidget {
  const BulkSerialIntakeScreen({super.key});

  @override
  ConsumerState<BulkSerialIntakeScreen> createState() =>
      _BulkSerialIntakeScreenState();
}

class _BulkSerialIntakeScreenState
    extends ConsumerState<BulkSerialIntakeScreen> {
  final _productIdController = TextEditingController();
  final _serialsController = TextEditingController();

  /// Set once a submission has been evaluated; null before the first
  /// submission attempt (or a range rejection, which never reaches the
  /// repository).
  List<BulkSerialRejection>? _clientRejected;

  /// Non-null only when the whole submission was rejected wholesale for
  /// being outside the 1-500 range (Req 12.4). Nothing is persisted in
  /// that case.
  String? _rangeError;

  @override
  void dispose() {
    _productIdController.dispose();
    _serialsController.dispose();
    super.dispose();
  }

  List<String> _parseLines() {
    return _serialsController.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  Future<void> _submit() async {
    final productId = _productIdController.text.trim();
    final lines = _parseLines();

    setState(() {
      _rangeError = null;
      _clientRejected = null;
    });

    // Reject the whole submission wholesale when out of range; nothing is
    // persisted (Req 12.4).
    if (lines.length < _kMinSerials || lines.length > _kMaxSerials) {
      setState(() {
        _rangeError =
            'Submit between $_kMinSerials and $_kMaxSerials serials '
            '(received ${lines.length}).';
      });
      return;
    }

    if (productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Product reference is required')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final outcome = _validateSerials(lines);
    setState(() => _clientRejected = outcome.rejected);

    if (outcome.validSerials.isEmpty) {
      // Nothing valid to persist — report the rejections without calling
      // the repository.
      return;
    }

    await ref
        .read(bulkSerialIntakeProvider.notifier)
        .submit(
          productId: productId,
          serials: outcome.validSerials,
          clientRejected: outcome.rejected,
        );
  }

  void _startNewSubmission() {
    setState(() {
      _serialsController.clear();
      _rangeError = null;
      _clientRejected = null;
    });
    ref.read(bulkSerialIntakeProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final intakeState = ref.watch(bulkSerialIntakeProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bulk Serial Intake',
              style: TextStyle(
                fontSize: responsiveValue<double>(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              'Intake 1-500 Serials at Once',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Whole-submission range rejection (Req 12.4) — nothing
              // persisted.
              if (_rangeError != null) _ErrorBanner(error: _rangeError!),

              // Persistence failure (Req 12.5) — nothing persisted.
              if (intakeState.error != null)
                _ErrorBanner(error: intakeState.error!),

              if (_rangeError != null || intakeState.error != null)
                const SizedBox(height: 24),

              // Success confirmation with persisted count (Req 12.1) plus
              // the full rejection report (Req 12.3).
              if (intakeState.result != null && intakeState.error == null)
                _ResultCard(
                  result: intakeState.result!,
                  onStartNewSubmission: _startNewSubmission,
                ),

              if (intakeState.result != null && intakeState.error == null)
                const SizedBox(height: 24),

              // Rejection report for submissions where nothing was valid
              // enough to reach the repository.
              if (_clientRejected != null &&
                  intakeState.result == null &&
                  intakeState.error == null)
                _RejectionOnlyCard(rejected: _clientRejected!),

              if (_clientRejected != null &&
                  intakeState.result == null &&
                  intakeState.error == null)
                const SizedBox(height: 24),

              _IntakeFormCard(
                productIdController: _productIdController,
                serialsController: _serialsController,
                isLoading: intakeState.isLoading,
                onSubmit: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Error Banner
// ============================================================================

class _ErrorBanner extends StatelessWidget {
  final String error;

  const _ErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: TextStyle(fontSize: 14, color: Colors.red.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Intake Form Card
// ============================================================================

class _IntakeFormCard extends StatelessWidget {
  final TextEditingController productIdController;
  final TextEditingController serialsController;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _IntakeFormCard({
    required this.productIdController,
    required this.serialsController,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.playlist_add_check,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Intake Serials',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Enter one serial per line (1-$_kMaxSerials serials).',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // Product reference (required) — links the intake batch to a
            // product record, matching the serial-record shape used
            // elsewhere in the module (Computer_Repository.getSerials).
            TextField(
              controller: productIdController,
              decoration: InputDecoration(
                labelText: 'Product Reference *',
                hintText: 'Product ID these serials belong to',
                prefixIcon: const Icon(Icons.inventory_2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 16),

            // Multi-line serial input (Req 12.1).
            TextField(
              controller: serialsController,
              maxLines: 10,
              minLines: 6,
              decoration: InputDecoration(
                labelText: 'Serials *',
                hintText: 'One serial per line\ne.g.\nSN-0001\nSN-0002',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : onSubmit,
                icon: isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(isLoading ? 'Submitting...' : 'Submit Intake'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Result Card — persisted count + rejection report
// ============================================================================

class _ResultCard extends StatelessWidget {
  final BulkSerialIntakeResult result;
  final VoidCallback onStartNewSubmission;

  const _ResultCard({required this.result, required this.onStartNewSubmission});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.shade200, width: 2),
      ),
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 32,
                  color: Colors.green.shade600,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${result.accepted.length} serial'
                    '${result.accepted.length == 1 ? '' : 's'} persisted',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onStartNewSubmission,
                  icon: const Icon(Icons.add),
                  label: const Text('New Submission'),
                ),
              ],
            ),
            if (result.rejected.isNotEmpty) ...[
              const SizedBox(height: 16),
              _RejectionList(rejected: result.rejected),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Rejection-only card — used when nothing was valid enough to persist
// ============================================================================

class _RejectionOnlyCard extends StatelessWidget {
  final List<BulkSerialRejection> rejected;

  const _RejectionOnlyCard({required this.rejected});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No serials were valid — nothing was persisted',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RejectionList(rejected: rejected),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Rejection List — serial value + rejection reason (Req 12.3)
// ============================================================================

class _RejectionList extends StatelessWidget {
  final List<BulkSerialRejection> rejected;

  const _RejectionList({required this.rejected});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rejected (${rejected.length}):',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rejected.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final r = rejected[index];
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.close, color: Colors.red, size: 20),
              title: Text(
                r.serial,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(r.reason),
            );
          },
        ),
      ],
    );
  }
}
