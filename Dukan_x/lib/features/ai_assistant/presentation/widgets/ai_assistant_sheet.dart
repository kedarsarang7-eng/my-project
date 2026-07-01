import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../services/voice_intent_service.dart';
import '../../../billing/presentation/screens/bill_creation_screen_v2.dart';
import '../../../billing/presentation/providers/billing_providers.dart';
import '../../../../screens/billing_reports_screen.dart';

class AiAssistantSheet extends ConsumerStatefulWidget {
  const AiAssistantSheet({super.key});

  @override
  ConsumerState<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends ConsumerState<AiAssistantSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final VoiceIntentService _intentService = sl<VoiceIntentService>();

  bool _isListening = false;
  String _transcript = "Tap the mic to start speaking...";
  String _aiResponse = "";
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startListening() async {
    final speechService = ref.read(speechServiceProvider);

    setState(() {
      _isListening = true;
      _transcript = "Listening...";
      _aiResponse = "";
    });

    try {
      await speechService.startListening(
        onResult: (text) {
          if (mounted) {
            setState(() {
              _transcript = text;
            });
            // Auto-process if silence? (SpeechService handles timeout usually)
            // But we need a trigger to stop and process.
            // For now, let user stop or rely on silence detection if available.
            // Or simple silence timeout here.

            // If we want auto-process like SmartBill:
            /*
            Future.delayed(const Duration(seconds: 2), () {
               if (mounted && _isListening && _transcript == text) {
                 _stopListening();
                 _processCommand(text);
               }
            });
            */
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _transcript = "Error: $e");
      }
    }
  }

  void _stopListening() async {
    final speechService = ref.read(speechServiceProvider);
    await speechService.stopListening();
    if (mounted) {
      setState(() => _isListening = false);
      if (_transcript.isNotEmpty && _transcript != "Listening...") {
        _processCommand(_transcript);
      }
    }
  }

  Future<void> _processCommand(String text) async {
    final intent = await _intentService.parseCommand(text);

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _aiResponse = intent.responseText ?? "Done.";
      });

      // Handle Navigation properly
      if (intent.type == VoiceIntentType.navigateToBill) {
        // Close sheet first then navigate
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BillCreationScreenV2()),
        );
      } else if (intent.type == VoiceIntentType.navigateToReports) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BillingReportsScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle Bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 20),
              const SizedBox(width: 8),
              const Text(
                "Ask Dukan",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Transcript Area
          if (_isProcessing)
            const SizedBox(
              height: 30,
              width: 30,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Text(
              _transcript,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: _isListening ? FontWeight.w300 : FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),

          if (_aiResponse.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Text(
                _aiResponse,
                style: const TextStyle(color: Colors.blue, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const SizedBox(height: 40),

          // Mic Button
          GestureDetector(
            onTap: _isListening ? _stopListening : _startListening,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? Colors.redAccent : Colors.blueAccent,
                    boxShadow: [
                      if (_isListening)
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(
                            0.5 * _pulseController.value,
                          ),
                          blurRadius: 20 + (10 * _pulseController.value),
                          spreadRadius: 5 * _pulseController.value,
                        )
                      else
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 30),

          // Suggestions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSuggestionChip("Create a bill"),
                const SizedBox(width: 8),
                _buildSuggestionChip("Show me reports"),
                const SizedBox(width: 8),
                _buildSuggestionChip("How are sales today?"),
              ],
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String label) {
    return ActionChip(
      label: Text(label),
      backgroundColor: Colors.transparent,
      side: BorderSide(color: Colors.grey.withOpacity(0.3)),
      onPressed: () {
        setState(() {
          _transcript = label;
          _isProcessing = true;
        });
        _processCommand(label);
      },
    );
  }
}
