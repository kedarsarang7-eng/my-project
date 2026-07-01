// ============================================================================
// Scan Bill Processing Screen
// ============================================================================
// Second screen in the scan bill flow:
// - Shows animated progress indicators
// - Step labels: Uploading, Reading, Identifying, Matching
// - Cancel option
// - Error handling with retry
// - Auto-advance to review screen on success
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/logger_service.dart';
import '../../providers/scan_bill_session_provider.dart';
import 'scan_bill_review_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

enum ProcessingStep {
  uploading,
  extracting,
  matching,
  complete,
  error,
}

class ScanBillProcessingScreen extends ConsumerStatefulWidget {
  final String verticalType;
  final bool skipToMatching;
  final bool isMultiPage;

  const ScanBillProcessingScreen({
    super.key,
    required this.verticalType,
    this.skipToMatching = false,
    this.isMultiPage = false,
  });

  @override
  ConsumerState<ScanBillProcessingScreen> createState() => 
      _ScanBillProcessingScreenState();
}

class _ScanBillProcessingScreenState 
    extends ConsumerState<ScanBillProcessingScreen> {
  final LoggerService _logger = sl<LoggerService>();
  ProcessingStep _currentStep = ProcessingStep.uploading;
  String? _errorMessage;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startProcessing();
    });
  }

  Future<void> _startProcessing() async {
    final notifier = ref.read(
      scanBillSessionProvider(widget.verticalType).notifier
    );

    try {
      if (widget.skipToMatching) {
        // Skip to matching if we already have extraction result
        setState(() => _currentStep = ProcessingStep.matching);
        await _runMatching(notifier);
      } else {
        // Full flow: extract then match
        setState(() => _currentStep = ProcessingStep.uploading);
        _simulateProgress(0.0, 0.25, const Duration(milliseconds: 500));
        
        await _runExtraction(notifier);
        
        if (mounted) {
          setState(() => _currentStep = ProcessingStep.matching);
          _simulateProgress(0.6, 0.9, const Duration(milliseconds: 800));
          await _runMatching(notifier);
        }
      }

      if (mounted) {
        setState(() {
          _currentStep = ProcessingStep.complete;
          _progress = 1.0;
        });

        // Auto-advance to review screen after brief delay
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ScanBillReviewScreen(
                verticalType: widget.verticalType,
              ),
            ),
          );
        }
      }
    } catch (e) {
      _logger.error('Processing failed', {'error': e.toString()});
      if (mounted) {
        setState(() {
          _currentStep = ProcessingStep.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _runExtraction(dynamic notifier) async {
    _logger.info('Starting extraction');
    await notifier.extractBill();

    final state = ref.read(scanBillSessionProvider(widget.verticalType));
    if (state.error != null) {
      throw Exception(state.error);
    }

    _logger.info('Extraction complete', {
      'lines': state.extractionResult?.parsedLines.length,
    });
  }

  Future<void> _runMatching(dynamic notifier) async {
    _logger.info('Starting matching');
    await notifier.matchProducts();

    final state = ref.read(scanBillSessionProvider(widget.verticalType));
    if (state.error != null) {
      throw Exception(state.error);
    }

    _logger.info('Matching complete', {
      'items': state.reviewLineItems?.length,
    });
  }

  void _simulateProgress(double start, double end, Duration duration) {
    final stopwatch = Stopwatch()..start();
    
    void update() {
      if (!mounted) return;
      
      final elapsed = stopwatch.elapsedMilliseconds;
      final total = duration.inMilliseconds;
      
      if (elapsed >= total) {
        setState(() => _progress = end);
        return;
      }

      final t = elapsed / total;
      final current = start + (end - start) * t;
      
      setState(() => _progress = current);
      
      Future.delayed(const Duration(milliseconds: 50), update);
    }
    
    update();
  }

  Future<void> _retry() async {
    setState(() {
      _currentStep = ProcessingStep.uploading;
      _errorMessage = null;
      _progress = 0.0;
    });
    await _startProcessing();
  }

  Future<void> _cancel() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Processing?'),
        content: const Text(
          'Are you sure you want to cancel? Your progress will be lost.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continue'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (shouldCancel == true && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return WillPopScope(
      onWillPop: () async {
        if (_currentStep == ProcessingStep.uploading ||
            _currentStep == ProcessingStep.extracting ||
            _currentStep == ProcessingStep.matching) {
          await _cancel();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Processing Bill'),
          leading: _currentStep == ProcessingStep.complete ||
                   _currentStep == ProcessingStep.error
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _cancel,
                ),
        ),
        body: Center(
          child: BoundedBox(
            maxWidth: 600,
            child: Padding(
              padding: EdgeInsets.all(responsiveValue<double>(context,
                mobile: 16,
                tablet: 20,
                desktop: 32,  // PRESERVED: Desktop uses exactly 32 as before
              )),
              child: _buildContent(colorScheme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    switch (_currentStep) {
      case ProcessingStep.complete:
        return _buildCompleteView(colorScheme);
      case ProcessingStep.error:
        return _buildErrorView(colorScheme);
      default:
        return _buildProcessingView(colorScheme);
    }
  }

  Widget _buildProcessingView(ColorScheme colorScheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated circular progress
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: _progress,
                strokeWidth: 8,
                backgroundColor: colorScheme.primaryContainer,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
              Center(
                child: _buildStepIcon(colorScheme),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Step title
        Text(
          _getStepTitle(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Step description
        Text(
          _getStepDescription(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),

        // Step indicators
        _buildStepIndicators(colorScheme),
        const SizedBox(height: 32),

        // Estimated time
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Usually takes 3-8 seconds',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepIcon(ColorScheme colorScheme) {
    IconData iconData;
    switch (_currentStep) {
      case ProcessingStep.uploading:
        iconData = Icons.cloud_upload_outlined;
        break;
      case ProcessingStep.extracting:
        iconData = Icons.document_scanner_outlined;
        break;
      case ProcessingStep.matching:
        iconData = Icons.fact_check_outlined;
        break;
      default:
        iconData = Icons.check_circle_outline;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Icon(
        iconData,
        key: ValueKey(_currentStep),
        size: 48,
        color: colorScheme.primary,
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case ProcessingStep.uploading:
        return 'Uploading Bill...';
      case ProcessingStep.extracting:
        return 'Reading Bill Text...';
      case ProcessingStep.matching:
        return 'Matching Products...';
      default:
        return '';
    }
  }

  String _getStepDescription() {
    switch (_currentStep) {
      case ProcessingStep.uploading:
        return 'Uploading image to cloud for processing';
      case ProcessingStep.extracting:
        return 'Running OCR to identify products and prices';
      case ProcessingStep.matching:
        return 'Finding matching products in your catalog';
      default:
        return '';
    }
  }

  Widget _buildStepIndicators(ColorScheme colorScheme) {
    final steps = [
      ('Upload', ProcessingStep.uploading),
      ('Extract', ProcessingStep.extracting),
      ('Match', ProcessingStep.matching),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final (label, step) = entry.value;
        
        final isActive = _currentStep == step;
        final isComplete = _currentStep.index > step.index;

        return Row(
          children: [
            if (index > 0)
              Container(
                width: 32,
                height: 2,
                color: isComplete ? colorScheme.primary : Colors.grey[300],
              ),
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive || isComplete
                        ? colorScheme.primary
                        : Colors.grey[300],
                  ),
                  child: isComplete
                      ? const Icon(Icons.check, size: 8, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isActive || isComplete
                        ? colorScheme.primary
                        : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCompleteView(ColorScheme colorScheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 80,
          color: Colors.green[600],
        ),
        const SizedBox(height: 24),
        Text(
          'Processing Complete!',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Taking you to review screen...',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 32),
        const CircularProgressIndicator(),
      ],
    );
  }

  Widget _buildErrorView(ColorScheme colorScheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline,
          size: 80,
          color: Colors.red[600],
        ),
        const SizedBox(height: 24),
        Text(
          'Processing Failed',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _errorMessage ?? 'An unexpected error occurred',
            style: TextStyle(color: Colors.red[800]),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ],
    );
  }
}
