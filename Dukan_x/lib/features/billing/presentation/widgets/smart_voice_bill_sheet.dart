import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/voice_bill_intent.dart';
import '../../domain/entities/bill_item.dart';
import '../providers/billing_providers.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/modern_ui_components.dart';

class SmartVoiceBillSheet extends ConsumerStatefulWidget {
  final Function(VoiceBillIntent) onConfirmed;

  const SmartVoiceBillSheet({super.key, required this.onConfirmed});

  @override
  ConsumerState<SmartVoiceBillSheet> createState() =>
      _SmartVoiceBillSheetState();
}

class _SmartVoiceBillSheetState extends ConsumerState<SmartVoiceBillSheet> {
  String _statusText = 'Tap to Speak';
  String _liveText = '';
  bool _isListening = false;
  bool _isProcessing = false;
  VoiceBillIntent? _pendingIntent;

  @override
  void initState() {
    super.initState();
    // Auto-start listening on open
    Future.delayed(const Duration(milliseconds: 500), _startListening);
  }

  void _startListening() async {
    final speechService = ref.read(speechServiceProvider);

    setState(() {
      _isListening = true;
      _statusText = 'Listening...';
      _liveText = '';
    });

    await speechService.startListening(
      onResult: (text) {
        setState(() => _liveText = text);
        if (text.isNotEmpty) {
          // Process after a brief pause (simulating final result)
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted && !_isProcessing && text == _liveText) {
              _processCommand(text);
            }
          });
        }
      },
    );
  }

  void _stopListening() async {
    final speechService = ref.read(speechServiceProvider);
    await speechService.stopListening();
    setState(() => _isListening = false);
  }

  Future<void> _processCommand(String text) async {
    if (text.trim().isEmpty) {
      setState(() {
        _statusText = "Didn't catch that";
        _isListening = false;
      });
      return;
    }

    _stopListening();
    setState(() {
      _isProcessing = true;
      _statusText = 'Thinking...';
    });

    try {
      final parser = ref.read(parseVoiceIntentProvider);
      final result = await parser(text);

      result.fold(
        (failure) {
          setState(() {
            _statusText = 'Error: ${failure.message}';
            _isProcessing = false;
          });
        },
        (intent) {
          setState(() {
            _isProcessing = false;
            _statusText = 'Confirm Details';

            // Merge with existing if we are in "Update" mode?
            // For now, just replace or append.
            // The prompt implies "Voice corrections".
            if (_pendingIntent != null) {
              // Merging logic (Simplified)
              if (intent.type == VoiceBillIntentType.confirmBill) {
                widget.onConfirmed(_pendingIntent!);
                return;
              } else if (intent.type == VoiceBillIntentType.cancelBill) {
                Navigator.pop(context);
                return;
              }

              // Append items
              final newItems = List<BillItem>.from(_pendingIntent!.items)
                ..addAll(intent.items);
              _pendingIntent = _pendingIntent!.copyWith(
                items: newItems,
                // Overwrite basics if new ones provided
                customerName:
                    intent.customerName ?? _pendingIntent!.customerName,
                paymentMode: intent.paymentMode != VoicePaymentMode.unknown
                    ? intent.paymentMode
                    : _pendingIntent!.paymentMode,
              );
            } else {
              _pendingIntent = intent;
            }
          });
        },
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusText = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingIntent != null) {
      return _buildConfirmationView();
    }
    return _buildListeningView();
  }

  Widget _buildListeningView() {
    return SizedBox(
      height: 400,
      width: double.infinity,
      child: GlassContainer(
        borderRadius: 32.0,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _statusText,
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: FuturisticColors.textPrimary,
              ),
            ),
            const SizedBox(height: 40),
            AvatarGlow(
              animate: _isListening,
              glowColor: FuturisticColors.primary,
              glowShape: BoxShape.circle,
              duration: const Duration(milliseconds: 2000),
              repeat: true,
              child: GestureDetector(
                onTap: _isListening ? _stopListening : _startListening,
                child: Material(
                  elevation: 8,
                  shape: const CircleBorder(),
                  color: Colors.transparent,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _isListening
                          ? FuturisticColors.errorGradient
                          : FuturisticColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color:
                              (_isListening
                                      ? FuturisticColors.error
                                      : FuturisticColors.primary)
                                  .withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.stop : Icons.mic,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              _liveText.isEmpty ? "Try: 'Rajesh ko 2kg Sugar cash'" : _liveText,
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge.copyWith(
                color: FuturisticColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
            if (_isProcessing) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(color: FuturisticColors.accent),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationView() {
    final intent = _pendingIntent!;
    return SizedBox(
      height: 600,
      width: double.infinity,
      child: GlassContainer(
        borderRadius: 32.0,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Confirm Bill',
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: FuturisticColors.primary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),

            // Customer & Payment - using ModernCard
            ModernCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(
                  Icons.person_outline,
                  color: FuturisticColors.accent,
                ),
                title: Text(intent.customerName ?? 'Walk-in Customer'),
                subtitle: Text(
                  'Payment: ${intent.paymentMode.name.toUpperCase()}',
                ),
                // Edit button removed - use voice commands to modify
              ),
            ),

            const SizedBox(height: 10),
            Text(
              'Items',
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Items List
            Expanded(
              child: ListView.separated(
                itemCount: intent.items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = intent.items[index];
                  final isKnown = item.productId.isNotEmpty;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: isKnown
                          ? FuturisticColors.success.withOpacity(0.1)
                          : FuturisticColors.warning.withOpacity(0.1),
                      child: Text(
                        item.name.isNotEmpty ? item.name[0] : '?',
                        style: TextStyle(
                          color: isKnown
                              ? FuturisticColors.success
                              : FuturisticColors.warning,
                        ),
                      ),
                    ),
                    title: Text(item.name, style: AppTypography.bodyMedium),
                    subtitle: Text('${item.quantity} ${item.unit}'),
                    trailing: Text(
                      '₹${item.amount.toStringAsFixed(2)}',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Actions
            Row(
              children: [
                Expanded(
                  child: EnterpriseButton(
                    onPressed: _startListening,
                    icon: Icons.mic,
                    label: 'Add / Correct',
                    backgroundColor: Colors.transparent,
                    textColor: FuturisticColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: EnterpriseButton(
                    onPressed: () => widget.onConfirmed(intent),
                    icon: Icons.check,
                    label: 'CONFIRM',
                    backgroundColor: FuturisticColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
