import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/bill_item.dart';
import '../providers/billing_providers.dart';

class VoiceInputWidget extends ConsumerStatefulWidget {
  final Function(List<BillItem>) onItemsDetected;

  const VoiceInputWidget({super.key, required this.onItemsDetected});

  @override
  ConsumerState<VoiceInputWidget> createState() => _VoiceInputWidgetState();
}

class _VoiceInputWidgetState extends ConsumerState<VoiceInputWidget> {
  String _recognizedText = 'Tap mic to speak...';
  bool _isListening = false;
  bool _isProcessing = false;

  void _toggleListening() async {
    final speechService = ref.read(speechServiceProvider);

    if (_isListening) {
      await speechService.stopListening();
      setState(() => _isListening = false);
      _processCommand();
    } else {
      setState(() {
        _isListening = true;
        _recognizedText = 'Listening...';
      });

      await speechService.startListening(
        onResult: (text) {
          setState(() => _recognizedText = text);
        },
      );
    }
  }

  Future<void> _processCommand() async {
    if (_recognizedText.isEmpty) return;

    setState(() => _isProcessing = true);

    final processor = ref.read(processVoiceCommandProvider);
    final result = await processor(_recognizedText);

    result.fold(
      (failure) {
        setState(() {
          _isProcessing = false;
          _recognizedText = 'Error: ${failure.message}';
        });
      },
      (items) {
        setState(() => _isProcessing = false);
        if (items.isNotEmpty) {
          widget.onItemsDetected(items);
          Navigator.pop(context); // Close the sheet
        } else {
          setState(
            () => _recognizedText = 'No items found. Try saying "2 kg Sugar"',
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: 300,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Voice to Bill',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'Speak like: "2 kg Sugar, 1 packet Oil"',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _recognizedText,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          const Spacer(),
          if (_isProcessing)
            const CircularProgressIndicator()
          else
            FloatingActionButton.large(
              onPressed: _toggleListening,
              backgroundColor: _isListening ? Colors.red : Colors.blue,
              child: Icon(_isListening ? Icons.stop : Icons.mic),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
