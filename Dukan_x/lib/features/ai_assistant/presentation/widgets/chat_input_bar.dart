import 'package:flutter/material.dart';

import 'mic_button_animated.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool isListening;
  final VoidCallback onMicTap;
  final VoidCallback onSendTap;
  final bool isEnabled;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.isListening,
    required this.onMicTap,
    required this.onSendTap,
    this.isEnabled = true,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_checkText);
  }

  void _checkText() {
    setState(() {
      _hasText = widget.controller.text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Ensure bottom padding for safe area (Chin) if not handled by scaffold
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom:
            12, // We rely on scaffold padding for viewInsets, but this adds internal breathing room
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        // Removed shadows/borders to prevent "white line" artifacts
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Mic Button
            MicButtonAnimated(
              isListening: widget.isListening,
              onTap: widget.onMicTap,
              glowColor: Colors.pinkAccent,
              isEnabled: widget.isEnabled,
            ),

            const SizedBox(width: 12),

            // Text Field
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(24),
                  // No border
                ),
                child: TextField(
                  controller: widget.controller,
                  style: const TextStyle(color: Colors.white),
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) {
                    if (_hasText) widget.onSendTap();
                  },
                  decoration: const InputDecoration(
                    hintText: "Type your message...",
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Send Button
            GestureDetector(
              onTap: _hasText ? widget.onSendTap : null,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _hasText
                      ? const LinearGradient(
                          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                        )
                      : null,
                  color: _hasText ? null : Colors.white.withOpacity(0.1),
                ),
                child: Icon(
                  Icons.send,
                  color: _hasText ? Colors.white : Colors.white24,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
