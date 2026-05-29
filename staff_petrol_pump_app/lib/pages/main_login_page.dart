import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../context/permission_context.dart';
import '../core/auth/auth_provider.dart';

class MainLoginPage extends ConsumerStatefulWidget {
  const MainLoginPage({super.key});

  @override
  ConsumerState<MainLoginPage> createState() => _MainLoginPageState();
}

class _MainLoginPageState extends ConsumerState<MainLoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _message;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final m = GoRouterState.of(context).uri.queryParameters['message'];
    if (m != null && m.isNotEmpty && _message == null) {
      _message = m;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authStateProvider.notifier).signIn(_email.text.trim(), _password.text);
      await ref.read(permissionProvider.notifier).loadFromCookieMirror();
      if (mounted) context.go('/dashboard');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 460,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Welcome Back', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                    if (_message != null) ...[
                      const SizedBox(height: 8),
                      Text(_message!, style: const TextStyle(color: Colors.blueAccent)),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return 'Email required';
                        if (!v.contains('@')) return 'Valid email required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? 'Password required' : null,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        child: _loading ? const CircularProgressIndicator() : const Text('Sign In'),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/license'),
                      child: const Text('Enter License Key'),
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
