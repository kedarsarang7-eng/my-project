import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dukanx/core/compat/firebase_auth_compat.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../services/auth_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class OtpScreenFixed extends StatefulWidget {
  final String verificationId;
  final String? redirectRoute;
  final String? phone;
  final int? resendToken;

  const OtpScreenFixed({
    required this.verificationId,
    this.redirectRoute,
    this.phone,
    this.resendToken,
    super.key,
  });

  @override
  State<OtpScreenFixed> createState() => _OtpScreenFixedState();
}

class _OtpScreenFixedState extends State<OtpScreenFixed> {
  final TextEditingController otpController = TextEditingController();
  bool isLoading = false;
  int _secondsRemaining = 60;
  bool _canResend = false;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining -= 1;
        } else {
          _canResend = true;
          t.cancel();
        }
      });
    });
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;
    if (widget.phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number not available to resend OTP'),
        ),
      );
      return;
    }

    setState(() => isLoading = true);
    final auth = AuthService();
    try {
      await auth.verifyPhone(
        phone: widget.phone!,
        forceResendingToken: widget.resendToken,
        onVerified: (AuthCredential credential) async {
          await auth.signInWithCredential(credential);
          if (mounted) {
            setState(() => isLoading = false);
            context.pushReplacement('/home');
          }
        },
        onCodeSent: (verificationId, token) {
          if (mounted) {
            setState(() => isLoading = false);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('OTP resent')));
            _startResendTimer();
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() => isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Resend error: ${e.message ?? e.code}')),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resend failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> verifyOTP() async {
    if (otpController.text.isEmpty || otpController.text.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter valid 6-digit OTP")));
      return;
    }

    setState(() => isLoading = true);
    try {
      final auth = AuthService();
      if (kIsWeb) {
        await auth.confirmWebOtp(otpController.text);
      } else {
        final credential = PhoneAuthProvider.credential(
          verificationId: widget.verificationId,
          smsCode: otpController.text,
        );
        await auth.signInWithCredential(credential);
      }

      if (mounted) {
        setState(() => isLoading = false);
        context.go('/auth_wrapper');
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: SafeArea(
        child: Center(
          child: BoundedBox(
            maxWidth: 500,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Enter the 6-digit code sent to ${widget.phone ?? 'your phone'}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '000000',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: isLoading ? null : verifyOTP,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Verify OTP'),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          _canResend
                              ? "Didn't receive OTP?"
                              : 'Resend in $_secondsRemaining s',
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: (_canResend && !isLoading)
                              ? _resendOtp
                              : null,
                          child: const Text('Resend OTP'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
