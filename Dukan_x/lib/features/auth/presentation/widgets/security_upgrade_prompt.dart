import 'package:flutter/material.dart';

import '../../services/biometric_service.dart';
import '../screens/pin_setup_screen.dart';

class SecurityUpgradePrompt extends StatefulWidget {
  final VoidCallback onDismiss;

  const SecurityUpgradePrompt({super.key, required this.onDismiss});

  @override
  State<SecurityUpgradePrompt> createState() => _SecurityUpgradePromptState();
}

class _SecurityUpgradePromptState extends State<SecurityUpgradePrompt>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  bool _canUseBiometric = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
    _checkBiometrics();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final supported = await biometricService.isDeviceSupported();
    if (mounted) setState(() => _canUseBiometric = supported);
  }

  Future<void> _enableBiometrics() async {
    final success = await biometricService.enableBiometrics();
    if (success && mounted) {
      widget.onDismiss();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Biometric Login Enabled!')));
    }
  }

  void _enablePin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PinSetupScreen(
          onSuccess: () {
            widget.onDismiss();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('PIN Login Enabled!')));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.5),
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    size: 40,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Login Faster next time?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enable secure access to get into your account instantly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                if (_canUseBiometric)
                  _buildButton(
                    icon: Icons.fingerprint,
                    label: 'Use Fingerprint / Face ID',
                    color: Colors.blue,
                    onTap: _enableBiometrics,
                  ),
                const SizedBox(height: 12),
                _buildButton(
                  icon: Icons.lock_outline,
                  label: 'Use 4-Digit PIN',
                  color: Colors.orange,
                  onTap: _enablePin,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: widget.onDismiss,
                  child: const Text(
                    'Maybe Later',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
