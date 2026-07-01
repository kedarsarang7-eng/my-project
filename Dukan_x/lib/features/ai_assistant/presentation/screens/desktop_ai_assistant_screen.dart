import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/ai_star_ball.dart';
import '../../services/ai_voice_service.dart';
import '../../services/voice_state.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DesktopAiAssistantScreen extends StatefulWidget {
  const DesktopAiAssistantScreen({super.key});

  @override
  State<DesktopAiAssistantScreen> createState() =>
      _DesktopAiAssistantScreenState();
}

class _DesktopAiAssistantScreenState extends State<DesktopAiAssistantScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _conversation = [];

  @override
  void initState() {
    super.initState();
    final aiService = AiVoiceService();
    // Listen to responses
    aiService.responseStream.listen((response) {
      if (mounted) {
        setState(() {
          if (response['user_text'] != null &&
              response['user_text'].isNotEmpty) {
            _conversation.add({'role': 'user', 'text': response['user_text']});
          }
          if (response['mahiru_text'] != null &&
              response['mahiru_text'].isNotEmpty) {
            _conversation.add({'role': 'ai', 'text': response['mahiru_text']});
          }
        });
        _scrollToBottom();

        // Handle Action Intents
        if (response['intent'] == 'action' && response['data'] != null) {
          final data = response['data'] as Map<String, dynamic>;
          _handleAiAction(
            data['action_type']?.toString(),
            data['action_target']?.toString(),
          );
        }
      }
    });
  }

  void _handleAiAction(String? type, String? target) {
    if (type == 'open_screen' && target != null) {
      // Small delay so user can read the "Opening..." text before navigation
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;

        // Map common targets to routing names
        String route = '';
        final t = target.toLowerCase();

        if (t.contains('inventory')) {
          route = 'stock_summary';
        } else if (t.contains('dashboard')) {
          route = 'executive_dashboard';
        } else if (t.contains('sale') || t.contains('bill')) {
          route = 'new_sale';
        } else if (t.contains('customer')) {
          route = 'customers';
        } else if (t.contains('report') || t.contains('insight')) {
          route = 'analytics_hub';
        }

        if (route.isNotEmpty) {
          // Migrated to GoRouter: interpolated runtime '/app/<route>' push.
          context.push('/app/$route');
        }
      });
    } else if (type == 'send_message' && target != null) {
      // Show a snackbar or trigger message sending service
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action: Sending message to $target...')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSubmit() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      final aiService = AiVoiceService();
      aiService.sendTextQuery(text);
      _textController.clear();
    }
  }

  void _sendSuggestion(String text) {
    final aiService = AiVoiceService();
    aiService.sendTextQuery(text);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiService = AiVoiceService();
    final isMobile = context.isMobile;

    return AnimatedBuilder(
      animation: aiService,
      builder: (context, child) {
        // Build the status text based on state
        String statusText;
        switch (aiService.state) {
          case VoiceState.listening:
            statusText = 'Listening...';
            break;
          case VoiceState.processing:
            if (aiService.lastIntent.isNotEmpty &&
                aiService.lastIntent != 'chit_chat') {
              statusText = 'Executing Activity...';
            } else {
              statusText = 'Thinking...';
            }
            break;
          case VoiceState.speaking:
            statusText = 'Speaking...';
            break;
          case VoiceState.error:
            statusText = 'Error';
            break;
          case VoiceState.idle:
            statusText = 'Ready';
        }

        final conversationColumn = Column(
          children: [
            Expanded(child: _buildConversationArea()),
            const SizedBox(height: 12),
            _buildSuggestions(),
            const SizedBox(height: 12),
            _buildInputArea(aiService),
          ],
        );

        final visualizationColumn = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: isMobile ? 120 : 200,
              width: isMobile ? 120 : 200,
              child: AiStarBall(aiState: aiService.state),
            ),
            const SizedBox(height: 16),
            if (aiService.state == VoiceState.processing)
              const Text(
                "Processing Request...",
                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
              ),
            if (aiService.state == VoiceState.error)
              Text(
                aiService.errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            // Tool Execution info
            if (aiService.lastIntent.isNotEmpty &&
                aiService.state == VoiceState.processing)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Executing: ${aiService.lastIntent}",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DukanX AI Assistant',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Status: $statusText | AI Mode: Ollama Local',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(
                responsiveValue<double>(
                  context,
                  mobile: 12,
                  tablet: 20,
                  desktop: 24,
                ),
              ),
              child: isMobile
                  ? Column(
                      children: [
                        visualizationColumn,
                        const SizedBox(height: 16),
                        Expanded(child: conversationColumn),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(flex: 1, child: conversationColumn),
                        const SizedBox(width: 32),
                        Expanded(flex: 1, child: visualizationColumn),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConversationArea() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _conversation.length,
        itemBuilder: (context, index) {
          final message = _conversation[index];
          final isUser = message['role'] == 'user';
          return Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                  bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                ),
              ),
              child: Text(
                message['text'] ?? '',
                style: TextStyle(
                  color: isUser
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = [
      "Today's profit",
      "Out of stock products",
      "Pending payments",
      "Open inventory",
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ActionChip(
            label: Text(suggestions[index]),
            onPressed: () => _sendSuggestion(suggestions[index]),
          );
        },
      ),
    );
  }

  Widget _buildInputArea(AiVoiceService aiService) {
    final isListening = aiService.state == VoiceState.listening;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isListening ? Icons.mic : Icons.mic_none,
              color: isListening
                  ? Colors.red
                  : Theme.of(context).iconTheme.color,
            ),
            onPressed: () {
              if (isListening) {
                aiService.stopListening();
              } else {
                aiService.startListening();
              }
            },
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Type a message or use voice...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (_) => _handleSubmit(),
            ),
          ),
          IconButton(icon: const Icon(Icons.send), onPressed: _handleSubmit),
        ],
      ),
    );
  }
}
