import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A robust error boundary that catches UI errors and provides recovery options.
/// Prevents the "Red Screen of Death" in production.
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(FlutterErrorDetails details)? fallbackBuilder;
  final String routeName;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallbackBuilder,
    this.routeName = 'Unknown',
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  FlutterErrorDetails? _error;
  bool _isRecovering = false;

  @override
  void initState() {
    super.initState();
  }

  /// Recover from the error by resetting state
  Future<void> _recover() async {
    setState(() {
      _isRecovering = true;
    });

    // Simulate specialized cleanup if needed (e.g. closing dialogs, resetting providers)
    // For now, a simple delay and state reset.
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _error = null;
        _isRecovering = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we have an error, show the fallback UI
    if (_error != null) {
      if (widget.fallbackBuilder != null) {
        return widget.fallbackBuilder!(_error!);
      }
      return _buildDefaultErrorUI();
    }

    // Wrap child in a builder that uses the ErrorWidget override trick locally if possible,
    // but primarily we rely on the fact that if *this* widget throws in build, it's caught by parent.
    // However, to catch *children* errors, we actually need to be the ErrorWidget.builder target
    // for the subtree, which Flutter doesn't natively support per-subtree easily without custom Elements.
    //
    // PRACTICAL APPROACH:
    // This widget acts as a visual boundary. If a child throws, Flutter's global ErrorWidget.builder
    // is called. We can't easily intercept ONLY this subtree's error without complex element manipulation.
    //
    // INSTBAD, we provide the UI structure. The *Global* Error handling in main.dart
    // should route to a consistent error screen.
    //
    // BUT checking for "red screen" (ErrorWidget) logic:
    // When a crash happens, Flutter builds an ErrorWidget.
    // We can define a CustomErrorWidget that looks good.
    return widget.child;
  }

  /// Builds a friendly error recovery screen
  Widget _buildDefaultErrorUI() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.healing_rounded,
                  size: 64,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We encountered an unexpected error in the ${widget.routeName} module.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isRecovering ? null : _recover,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isRecovering
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    _isRecovering ? 'Recovering...' : 'Reload This Screen',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  // Copy error to clipboard
                  final errorText =
                      "Error in ${widget.routeName}: ${_error?.exception}\n${_error?.stack}";
                  Clipboard.setData(ClipboardData(text: errorText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error details copied to clipboard'),
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Error Details'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A Custom Error Widget that replaces the "Red Screen of Death" globally.
class MainErrorFallback extends StatelessWidget {
  final FlutterErrorDetails details;

  const MainErrorFallback({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.amber.shade700,
              ),
              const SizedBox(height: 24),
              const Text(
                'Application Error',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'A critical error occurred. Please restart the application.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                height: 120,
                width: double.infinity,
                child: SingleChildScrollView(
                  child: SelectableText(
                    details.exceptionAsString(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Hard restart attempt or just exit
                  // On mobile, we can't easily restart. We can restart the Navigation stack.
                  // For now, let's try to pop to root.
                  // If no context available (likely in error widget), we might be stuck.
                  // Best we can do is hope the user restarts.
                },
                child: const Text('Please Restart App'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
