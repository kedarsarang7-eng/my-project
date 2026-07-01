import 'package:flutter/material.dart';
import '../../services/biometric_service.dart';
import '../../services/pin_service.dart';
import '../screens/pin_login_screen.dart';

class FastLoginOptions extends StatefulWidget {
  final VoidCallback onBiometricSuccess;
  final VoidCallback onPinSuccess;

  const FastLoginOptions({
    super.key,
    required this.onBiometricSuccess,
    required this.onPinSuccess,
  });

  @override
  State<FastLoginOptions> createState() => _FastLoginOptionsState();
}

class _FastLoginOptionsState extends State<FastLoginOptions> {
  bool _canUseBiometrics = false;
  bool _isPinSet = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final bioEnabled = await biometricService.isBiometricsEnabled();
    final deviceSupported = await biometricService.isDeviceSupported();
    final pinSet = await pinService.isPinSet();

    if (mounted) {
      setState(() {
        _canUseBiometrics = bioEnabled && deviceSupported;
        _isPinSet = pinSet;
      });

      // Auto-trigger biometric if enabled
      if (_canUseBiometrics) {
        _handleBiometricLogin();
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    setState(() => _isLoading = true);
    final success = await biometricService.authenticate();
    setState(() => _isLoading = false);

    if (success) {
      widget.onBiometricSuccess();
    }
  }

  void _handlePinLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PinLoginScreen(onSuccess: widget.onPinSuccess),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_canUseBiometrics && !_isPinSet) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(child: Divider(color: Colors.white24)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR LOGIN WITH',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Expanded(child: Divider(color: Colors.white24)),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_canUseBiometrics)
              _buildOptionBtn(
                icon: Icons.fingerprint,
                label: 'Biometric',
                onTap: _handleBiometricLogin,
                isLoading: _isLoading,
              ),
            if (_canUseBiometrics && _isPinSet) const SizedBox(width: 16),
            if (_isPinSet)
              _buildOptionBtn(
                icon: Icons.lock_outline,
                label: 'PIN',
                onTap: _handlePinLogin,
                isLoading: false,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildOptionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isLoading,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
