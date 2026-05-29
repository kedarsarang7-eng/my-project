import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  late AnimationController _anim;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() { _anim.dispose(); _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    ref.listen<AuthState>(authStateProvider, (_, next) {
      if (next.isAuthenticated) context.go('/dashboard');
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!), backgroundColor: AppTheme.error));
        ref.read(authStateProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: FadeTransition(
        opacity: _fade,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(height: 40),
                  _buildLogo(),
                  const SizedBox(height: 40),
                  _buildForm(auth),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() => Column(children: [
    Container(
      width: 72, height: 72,
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20)),
      child: const Icon(Icons.school_rounded, size: 36, color: Colors.white),
    ),
    const SizedBox(height: 16),
    Text('EduConnect', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppTheme.primary)),
    const SizedBox(height: 4),
    const Text('Teacher & Staff Portal', style: TextStyle(color: AppTheme.textSecondary)),
  ]);

  Widget _buildForm(AuthState auth) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: AppTheme.cardBg, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.divider),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))],
    ),
    child: Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sign In', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Access your teaching dashboard', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 24),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Staff Email', prefixIcon: Icon(Icons.email_outlined)),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _passCtrl,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _obscure = !_obscure)),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: auth.isLoading ? null : () async {
              if (!_formKey.currentState!.validate()) return;
              await ref.read(authStateProvider.notifier).signIn(_emailCtrl.text.trim(), _passCtrl.text);
            },
            child: auth.isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Sign In'),
          ),
        ),
      ]),
    ),
  );
}
