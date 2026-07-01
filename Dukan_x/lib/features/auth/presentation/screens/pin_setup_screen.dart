import 'package:flutter/material.dart';
import '../../services/pin_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class PinSetupScreen extends StatefulWidget {
  final VoidCallback onSuccess;

  const PinSetupScreen({super.key, required this.onSuccess});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final List<String> _pin = [];
  final int _pinLength = 4;

  bool _isConfirming = false;
  List<String> _firstPin = [];

  String _message = 'Create a 4-digit PIN';
  bool _isError = false;

  void _onKeyPress(String key) {
    if (_isError) {
      // Clear error state on next tap
      setState(() {
        _isError = false;
        _pin.clear();
        _message = _isConfirming ? 'Confirm your PIN' : 'Create a 4-digit PIN';
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
          _handleCompletion();
        }
      }
    }
  }

  void _handleCompletion() {
    if (!_isConfirming) {
      // First step done
      setState(() {
        _firstPin = List.from(_pin);
        _pin.clear();
        _isConfirming = true;
        _message = 'Confirm your PIN';
      });
    } else {
      // Confirming
      if (_pin.join() == _firstPin.join()) {
        _savePin();
      } else {
        setState(() {
          _isError = true;
          _message = 'PINs do not match. Try again.';
          _firstPin.clear();
          _isConfirming = false;
        });

        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _pin.clear();
              _isError = false;
              _message = 'Create a 4-digit PIN';
            });
          }
        });
      }
    }
  }

  Future<void> _savePin() async {
    await pinService.createPin(_pin.join());
    if (mounted) {
      widget.onSuccess();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Setup PIN', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Center(
          child: BoundedBox(
            maxWidth: 500,
            child: Column(
              children: [
                const SizedBox(height: 48),
                Text(
                  _message,
                  style: TextStyle(
                    fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 22),
                    fontWeight: FontWeight.bold,
                    color: _isError ? Colors.red : Colors.black,
                  ),
                ),
                const SizedBox(height: 32),
    
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
                            ? Colors.blue
                            : Colors.grey.withOpacity(0.3),
                        border: isFilled ? null : Border.all(color: Colors.grey),
                      ),
                    );
                  }),
                ),
    
                const Spacer(),
    
                // Keypad
                Container(
                  padding: const EdgeInsets.only(bottom: 40),
                  color: Colors.grey.withOpacity(0.05),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
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
          onTap: () => _onKeyPress(key),
          borderRadius: BorderRadius.circular(40),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isBackspace
                ? const Icon(Icons.backspace_outlined, color: Colors.black54)
                : Text(
                    key,
                    style: const TextStyle(
                      color: Colors.black,
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
