import 'package:flutter/material.dart';

/// A futuristic dialog replacement for [AlertDialog].
/// Features:
/// - Glass background
/// - Neon borders
/// - Desktop width constraints
/// - Consistent header/footer layout
class EnterpriseDialog extends StatelessWidget {
  final String title;
  final Widget? content;
  final String? description;
  final List<Widget>? actions;
  final double width;
  final bool isDanger;

  const EnterpriseDialog({
    super.key,
    required this.title,
    this.content,
    this.description,
    this.actions,
    this.width = 500,
    this.isDanger = false,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    Widget? content,
    String? description,
    List<Widget>? actions,
    double width = 500,
    bool isDanger = false,
  }) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7), // Darker overlay for focus
      builder: (context) => EnterpriseDialog(
        title: title,
        content: content,
        description: description,
        actions: actions,
        width: width,
        isDanger: isDanger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent, // We handle background
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          width: width,
          constraints: const BoxConstraints(maxHeight: 700),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDanger
                  ? theme.colorScheme.error.withOpacity(0.5)
                  : theme.dividerColor,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 40,
                spreadRadius: 0,
              ),
              if (!isDanger)
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // HEADER
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDanger
                            ? theme.colorScheme.error.withOpacity(0.1)
                            : theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDanger
                            ? Icons.warning_amber_rounded
                            : Icons.info_outline,
                        color: isDanger
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              description!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: theme.hintColor),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: theme.dividerColor),

              // CONTENT
              if (content != null)
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: content,
                  ),
                ),

              // FOOTER (ACTIONS)
              if (actions != null && actions!.isNotEmpty) ...[
                Divider(height: 1, color: theme.dividerColor),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions!.map((a) {
                      // Add spacing between actions if multiple
                      if (a != actions!.last) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: a,
                        );
                      }
                      return a;
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
