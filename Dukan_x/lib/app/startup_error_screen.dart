import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';

/// Shown when AppConfig.validate() fails in production.
/// Prevents the app from starting in a misconfigured state.
class StartupErrorScreen extends StatelessWidget {
  final String message;

  const StartupErrorScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: ResponsiveContainer(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFE57373), size: 56),
                  const SizedBox(height: 24),
                  const Text(
                    'Configuration Error',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'The application cannot start because required environment '
                    'variables are missing or invalid. Please contact your system '
                    'administrator.',
                    style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D1A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE57373).withValues(alpha: 0.4)),
                    ),
                    child: SelectableText(
                      message,
                      style: const TextStyle(
                        color: Color(0xFFEF9A9A),
                        fontSize: 12,
                        fontFamily: 'monospace',
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Clipboard.setData(ClipboardData(text: message)),
                        icon: const Icon(Icons.copy, size: 16, color: Color(0xFFB0BEC5)),
                        label: const Text(
                          'Copy Details',
                          style: TextStyle(color: Color(0xFFB0BEC5)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF37474F)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
