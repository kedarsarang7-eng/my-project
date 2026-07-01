// ============================================================================
// Migration Dashboard Screen
// ============================================================================
// Full-screen overlay that drives the 8-step Offline → Online migration.
//
// Flow:
//   1. User navigates to Settings → Switch to Online Mode
//   2. This screen launches (pushed as a full-screen route)
//   3. Engine starts automatically
//   4. At Step 2, a blocking Warning Gate dialog appears
//   5. User types "SWITCH TO ONLINE" and confirms → engine continues
//   6. Progress dashboard shows real-time 8-step status
//   7. On completion, user sees a success banner and is redirected
//   8. On failure, user sees error detail + rollback status
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/migration/migration_engine.dart';
import '../../../core/migration/migration_models.dart';
import '../../../core/service_registry/licensing/license_migration_calculator.dart';
import '../../../core/theme/futuristic_colors.dart';
import '../../../core/theme/design_tokens.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class MigrationDashboardScreen extends StatefulWidget {
  final OfflineLicense license;
  final Map<String, String> awsConfig;

  const MigrationDashboardScreen({
    super.key,
    required this.license,
    required this.awsConfig,
  });

  @override
  State<MigrationDashboardScreen> createState() =>
      _MigrationDashboardScreenState();
}

class _MigrationDashboardScreenState extends State<MigrationDashboardScreen>
    with TickerProviderStateMixin {
  late final StreamSubscription<MigrationProgress> _sub;
  final List<MigrationProgress> _history = [];
  MigrationProgress? _current;
  bool _warningGateShown = false;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _sub = MigrationEngine.instance.progressStream.listen(_onProgress);

    // Start after a short delay so the screen renders first.
    Future.delayed(const Duration(milliseconds: 300), _startMigration);
  }

  void _startMigration() {
    MigrationEngine.instance.start(
      license: widget.license,
      awsConfig: widget.awsConfig,
    );
  }

  void _onProgress(MigrationProgress p) {
    if (!mounted) return;
    setState(() {
      _current = p;
      _history.add(p);
    });

    // Show warning gate dialog once.
    if (p.step == MigrationStep.warningGate &&
        p.status == MigrationStatus.waitingForUser &&
        !_warningGateShown) {
      _warningGateShown = true;
      final credit = p.metadata['credit'] as Map<String, dynamic>? ?? {};
      _showWarningGate(credit);
    }

    // Auto-navigate on completion after 2s.
    if (p.status == MigrationStatus.completed) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Warning Gate Dialog ──────────────────────────────────────────────────

  Future<void> _showWarningGate(Map<String, dynamic> credit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WarningGateDialog(credit: credit),
    );

    if (confirmed == true) {
      MigrationEngine.instance.confirmWarningGate();
    } else {
      MigrationEngine.instance.cancel();
      if (mounted) Navigator.of(context).pop();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    FuturisticColors.sync(isDark);

    final status = _current?.status ?? MigrationStatus.idle;
    final isFailed = status == MigrationStatus.failed;
    final isCompleted = status == MigrationStatus.completed;

    return PopScope(
      canPop: isFailed || isCompleted,
      child: Scaffold(
        backgroundColor: FuturisticColors.background,
        body: BoundedBox(
          maxWidth: 800,
          child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isCompleted, isFailed),
                const SizedBox(height: DesignTokens.space8),
                _buildOverallProgress(),
                const SizedBox(height: DesignTokens.space6),
                Expanded(child: _buildStepList()),
                const SizedBox(height: DesignTokens.space6),
                _buildCurrentMessage(),
                if (isFailed) ...[
                  const SizedBox(height: DesignTokens.space4),
                  _buildRollbackBanner(),
                ],
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isCompleted, bool isFailed) {
    final color = isCompleted
        ? const Color(0xFF22C55E)
        : isFailed
            ? const Color(0xFFEF4444)
            : FuturisticColors.primary;

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          ),
          child: Icon(
            isCompleted
                ? Icons.cloud_done_rounded
                : isFailed
                    ? Icons.error_rounded
                    : Icons.cloud_sync_rounded,
            color: color,
            size: 28,
          ),
        ),
        const SizedBox(width: DesignTokens.space4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCompleted
                    ? 'Migration Complete'
                    : isFailed
                        ? 'Migration Failed'
                        : 'Switching to Online Mode',
                style: TextStyle(
                  fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 22),
                  fontWeight: FontWeight.bold,
                  color: FuturisticColors.textPrimary,
                ),
              ),
              Text(
                isCompleted
                    ? 'You are now on the cloud. Welcome to online mode!'
                    : isFailed
                        ? 'Your offline data is intact. See details below.'
                        : 'Please keep the app open. Do not close the window.',
                style: TextStyle(
                  fontSize: 13,
                  color: FuturisticColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverallProgress() {
    final progress = _current?.overallProgress ?? 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Overall Progress',
              style: TextStyle(
                fontSize: 13,
                color: FuturisticColors.textSecondary,
              ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: FuturisticColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.space2),
        ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: FuturisticColors.surfaceHigh,
            valueColor: AlwaysStoppedAnimation<Color>(
              FuturisticColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepList() {
    return ListView.separated(
      itemCount: MigrationStep.values.length,
      separatorBuilder: (_, r) => const SizedBox(height: DesignTokens.space2),
      itemBuilder: (ctx, i) {
        final step = MigrationStep.values[i];
        final currentStep = _current?.step;
        final currentStatus = _current?.status;

        _StepState state;
        if (currentStep == null) {
          state = _StepState.waiting;
        } else if (step.index < currentStep.index) {
          state = _StepState.done;
        } else if (step.index == currentStep.index) {
          state = currentStatus == MigrationStatus.failed
              ? _StepState.failed
              : currentStatus == MigrationStatus.completed
                  ? _StepState.done
                  : currentStatus == MigrationStatus.waitingForUser
                      ? _StepState.waiting
                      : _StepState.running;
        } else {
          state = _StepState.waiting;
        }

        return _StepTile(
          step: step,
          state: state,
          pulseController: _pulseController,
          stepProgress: step == currentStep ? (_current?.stepProgress ?? 0) : 0,
        );
      },
    );
  }

  Widget _buildCurrentMessage() {
    final msg = _current?.message ?? 'Initialising…';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DesignTokens.space4),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(color: FuturisticColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: DesignTokens.space3),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                fontSize: 13,
                color: FuturisticColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRollbackBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DesignTokens.space4),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.undo_rounded, color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: DesignTokens.space3),
          Expanded(
            child: Text(
              'Migration rolled back. All your offline data is intact. '
              'You can try again after fixing the issue.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ── Step tile ──────────────────────────────────────────────────────────────

enum _StepState { waiting, running, done, failed }

class _StepTile extends StatelessWidget {
  final MigrationStep step;
  final _StepState state;
  final AnimationController pulseController;
  final double stepProgress;

  const _StepTile({
    required this.step,
    required this.state,
    required this.pulseController,
    required this.stepProgress,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _StepState.done => const Color(0xFF22C55E),
      _StepState.running => FuturisticColors.primary,
      _StepState.failed => const Color(0xFFEF4444),
      _StepState.waiting => FuturisticColors.textSecondary,
    };

    final icon = switch (state) {
      _StepState.done => Icons.check_circle_rounded,
      _StepState.running => Icons.radio_button_checked_rounded,
      _StepState.failed => Icons.cancel_rounded,
      _StepState.waiting => Icons.radio_button_unchecked_rounded,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space4,
        vertical: DesignTokens.space3,
      ),
      decoration: BoxDecoration(
        color: state == _StepState.running
            ? FuturisticColors.primary.withValues(alpha: 0.06)
            : FuturisticColors.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(
          color: state == _StepState.running
              ? FuturisticColors.primary.withValues(alpha: 0.3)
              : FuturisticColors.border,
        ),
      ),
      child: Row(
        children: [
          // Step number badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: state == _StepState.running
                  ? AnimatedBuilder(
                      animation: pulseController,
                      builder: (_, r) => Icon(
                        icon,
                        size: 16,
                        color: Color.lerp(
                          color,
                          color.withValues(alpha: 0.4),
                          pulseController.value,
                        ),
                      ),
                    )
                  : Icon(icon, size: 16, color: color),
            ),
          ),
          const SizedBox(width: DesignTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step ${step.index + 1}: ${step.label}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: state == _StepState.running
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: state == _StepState.waiting
                        ? FuturisticColors.textSecondary
                        : FuturisticColors.textPrimary,
                  ),
                ),
                if (state == _StepState.running && stepProgress > 0) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
                    child: LinearProgressIndicator(
                      value: stepProgress,
                      minHeight: 3,
                      backgroundColor: FuturisticColors.surfaceHigh,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (state == _StepState.done)
            Text(
              '✓',
              style: TextStyle(
                color: const Color(0xFF22C55E),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Warning Gate Dialog ────────────────────────────────────────────────────

class _WarningGateDialog extends StatefulWidget {
  final Map<String, dynamic> credit;
  const _WarningGateDialog({required this.credit});

  @override
  State<_WarningGateDialog> createState() => _WarningGateDialogState();
}

class _WarningGateDialogState extends State<_WarningGateDialog> {
  final _controller = TextEditingController();
  bool _valid = false;
  static const _required = 'SWITCH TO ONLINE';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _valid = _controller.text == _required);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    FuturisticColors.sync(isDark);

    final c = widget.credit;
    final months = c['creditsInMonths'] as int? ?? 0;
    final plan = c['onlinePlan'] as String? ?? '';
    final remaining = c['remainingCredit'] as int? ?? 0;
    final summary = c['summary'] as String? ?? '';

    return Dialog(
      backgroundColor: FuturisticColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(DesignTokens.space2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFF59E0B),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.space3),
                  Expanded(
                    child: Text(
                      'IMPORTANT — READ BEFORE CONTINUING',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: FuturisticColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space6),

              // Summary card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(DesignTokens.space4),
                decoration: BoxDecoration(
                  color: FuturisticColors.background,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  border: Border.all(color: FuturisticColors.border),
                ),
                child: Text(
                  summary,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: FuturisticColors.textSecondary,
                    height: 1.7,
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.space5),

              // Consequences
              _bulletRow(Icons.cancel_outlined, const Color(0xFFEF4444),
                  'Your Offline Lifetime Access will PERMANENTLY end'),
              const SizedBox(height: DesignTokens.space2),
              _bulletRow(Icons.cancel_outlined, const Color(0xFFEF4444),
                  'This action is IRREVERSIBLE'),
              const SizedBox(height: DesignTokens.space2),
              _bulletRow(Icons.check_circle_outline, const Color(0xFF22C55E),
                  'All your data will be migrated safely to the cloud'),
              const SizedBox(height: DesignTokens.space2),
              _bulletRow(Icons.check_circle_outline, const Color(0xFF22C55E),
                  'You get ~$months months of $plan plan free (₹$remaining credit)'),
              const SizedBox(height: DesignTokens.space6),

              // Confirmation text field
              Text(
                'To confirm, type exactly:',
                style: TextStyle(
                  fontSize: 13,
                  color: FuturisticColors.textSecondary,
                ),
              ),
              const SizedBox(height: DesignTokens.space2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.space3,
                  vertical: DesignTokens.space1,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
                child: SelectableText(
                  _required,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF59E0B),
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.space3),
              TextField(
                controller: _controller,
                autofocus: true,
                style: TextStyle(
                  color: FuturisticColors.textPrimary,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: 'Type here…',
                  hintStyle: TextStyle(color: FuturisticColors.textSecondary),
                  filled: true,
                  fillColor: FuturisticColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    borderSide: BorderSide(color: FuturisticColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    borderSide: BorderSide(
                      color: _valid
                          ? const Color(0xFF22C55E)
                          : FuturisticColors.primary,
                    ),
                  ),
                  suffixIcon: _valid
                      ? const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF22C55E))
                      : null,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[A-Z TOWINCHE]'),
                  ),
                ],
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) {
                  if (_valid) Navigator.of(context).pop(true);
                },
              ),
              const SizedBox(height: DesignTokens.space6),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: FuturisticColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.space3),
                  FilledButton(
                    onPressed: _valid
                        ? () => Navigator.of(context).pop(true)
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _valid
                          ? const Color(0xFF22C55E)
                          : FuturisticColors.surfaceHigh,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.space6,
                        vertical: DesignTokens.space3,
                      ),
                    ),
                    child: const Text('Confirm Switch →'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bulletRow(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: DesignTokens.space2),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: FuturisticColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
