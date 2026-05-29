import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/customer_auth_service.dart';
import '../../../../core/auth/customer_session_manager.dart';
import '../../../../core/navigation/app_router.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;

  const OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isSendingOtp = true;
  int _secondsRemaining = 60;
  bool _canResend = false;
  Timer? _timer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
    });
    try {
      await ref.read(customerAuthServiceProvider).sendOtp(widget.phone);
      _startTimer();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to send OTP. Tap to retry.');
      }
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _canResend = true;
          t.cancel();
        }
      });
    });
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Enter the 6-digit OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(customerSessionProvider.notifier)
          .signIn(widget.phone, otp);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(customerSessionProvider, (_, next) {
      next.whenData((state) {
        if (state.isAuthenticated) context.go(AppRoutes.home);
      });
    });

    final authState = ref.watch(customerSessionProvider).valueOrNull;
    final sessionError = authState?.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter verification code',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit OTP to +91 ${widget.phone}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 40),
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(letterSpacing: 12),
                decoration: const InputDecoration(hintText: '• • • • • •'),
                onChanged: (v) {
                  if (v.length == 6) _verifyOtp();
                },
              ),
              const SizedBox(height: 12),
              if (sessionError != null || _errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    sessionError ?? _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: (_isLoading || _isSendingOtp) ? null : _verifyOtp,
                child: (_isLoading || _isSendingOtp)
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify'),
              ),
              const SizedBox(height: 20),
              Center(
                child: _canResend
                    ? TextButton(
                        onPressed: _sendOtp,
                        child: const Text('Resend OTP'),
                      )
                    : Text(
                        'Resend OTP in $_secondsRemaining s',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
