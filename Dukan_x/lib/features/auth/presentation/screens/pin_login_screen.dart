import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/pin_service.dart';
import 'dart:async';
import 'package:dukanx/core/responsive/responsive.dart';

class PinLoginScreen extends StatefulWidget {
  final VoidCallback onSuccess;

  const PinLoginScreen({super.key, required this.onSuccess});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final List<String> _pin = [];
  final int _pinLength = 4;
  bool _isLoading = false;
  bool _isError = false;
  String _errorMessage = '';

  void _onKeyPress(String key) {
    if (_isLoading) return;
    if (_isError) {
      setState(() {
        _isError = false;
        _errorMessage = '';
        _pin.clear();
      });
    }

    if (key == 'BACKSPACE') {
      if (_pin.isNotEmpty) {
        setState(() => _pin.removeLast());
      }
    } else {
      if (_pin.length < _pinLength) {
        setState(() => _pin.add(key));
        if (_pin.length == _pinLength) {
          _verifyPin();
        }
      }
    }
  }

  Future<void> _verifyPin() async {
    setState(() => _isLoading = true);
    final pinString = _pin.join();

    // Slight delay for UX
    await Future.delayed(const Duration(milliseconds: 300));

    final valid = await pinService.verifyPin(pinString);

    if (valid) {
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMessage = 'Incorrect PIN';
        });
        HapticFeedback.heavyImpact();

        // Auto clear after 1s
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() {
              _pin.clear();
              _isError = false;
              _errorMessage = '';
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: BoundedBox(
            maxWidth: 500,
            child: Column(
              children: [
                const Spacer(),
                const Icon(Icons.lock_outline, color: Colors.white, size: 48),
                const SizedBox(height: 24),
                Text(
                  'Enter PIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: responsiveValue<double>(context, mobile: 20, tablet: 22, desktop: 24),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 48),
    
                // PIN Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pinLength, (index) {
                    final isFilled = index < _pin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled
                            ? (_isError ? Colors.red : Colors.white)
                            : Colors.white.withOpacity(0.2),
                      ),
                    );
                  }),
                ),
    
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ],
    
                const Spacer(),
    
                // Keypad
                Container(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    children: [
                      _buildKeyRow(['1', '2', '3']),
                      _buildKeyRow(['4', '5', '6']),
                      _buildKeyRow(['7', '8', '9']),
                      _buildKeyRow(['', '0', 'BACKSPACE']),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: keys.map((key) {
          if (key.isEmpty) return const SizedBox(width: 80, height: 80);
          return _buildKey(key);
        }).toList(),
      ),
    );
  }

  Widget _buildKey(String key) {
    final isBackspace = key == 'BACKSPACE';
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _onKeyPress(key);
          },
          customBorder: const CircleBorder(),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
            child: isBackspace
                ? const Icon(Icons.backspace_outlined, color: Colors.white)
                : Text(
                    key,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
