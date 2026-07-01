import 'package:flutter/material.dart';

class ChatBubbleUser extends StatelessWidget {
  final String message;
  final String? time;

  const ChatBubbleUser({super.key, required this.message, this.time});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)], // Blue -> Purple
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            if (time != null) ...[
              const SizedBox(height: 4),
              Text(
                time!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ChatBubbleAI extends StatelessWidget {
  final String message;
  final bool isTyping;

  const ChatBubbleAI({super.key, required this.message, this.isTyping = false});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const CircleAvatar(
            backgroundColor: Colors.transparent,
            radius: 16,
            backgroundImage: AssetImage(
              'assets/images/mahiru_avatar.png',
            ), // Placeholder
            child: Icon(
              Icons.face_3,
              color: Colors.pinkAccent,
              size: 20,
            ), // Fallback
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[900]!.withOpacity(0.8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: Colors.white10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: isTyping
                ? const Text(
                    "Mahiru is thinking...",
                    style: TextStyle(
                      color: Colors.white54,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
