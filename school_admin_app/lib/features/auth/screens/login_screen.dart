import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _State();
}

class _State extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  late AnimationController _anim;
  late Animation<double> _fade;

  @override
  void initState() { super.initState(); _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800)); _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut); _anim.forward(); }
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
      backgroundColor: AppTheme.navBg,
      body: FadeTransition(
        opacity: _fade,
        child: Row(children: [
          // Left panel — branding (shown on wide screens)
          if (MediaQuery.of(context).size.width >= 900)
            Expanded(
              child: Container(
                color: AppTheme.navBg,
                padding: const EdgeInsets.all(48),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 56, height: 56, decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.secondary]), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.school_rounded, size: 30, color: Colors.white)),
                  const SizedBox(height: 24),
                  const Text('EduConnect Admin', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  const Text('Complete school management\nat your fingertips.', style: TextStyle(color: Colors.white54, fontSize: 16, height: 1.6)),
                  const SizedBox(height: 40),
                  ...[('Students & Admissions', Icons.people_rounded), ('Fee Management', Icons.account_balance_wallet_rounded), ('Staff & Payroll', Icons.badge_rounded), ('Reports & Analytics', Icons.bar_chart_rounded)].map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(children: [
                      Icon(f.$2, color: AppTheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Text(f.$1, style: const TextStyle(color: Colors.white70, fontSize: 15)),
                    ]),
                  )),
                ]),
              ),
            ),

          // Right panel — login form
          Expanded(
            child: Container(
              color: AppTheme.surface,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(children: [
                      const SizedBox(height: 40),
                      if (MediaQuery.of(context).size.width < 900) ...[
                        Container(width: 60, height: 60, decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.secondary]), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.school_rounded, size: 30, color: Colors.white)),
                        const SizedBox(height: 16),
                        Text('EduConnect', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppTheme.primary)),
                        const SizedBox(height: 4),
                        const Text('Admin Portal', style: TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 32),
                      ],
                      _buildForm(auth),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildForm(AuthState auth) => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.divider), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 32, offset: const Offset(0, 8))]),
    child: Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Admin Sign In', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Access your administration panel', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 28),
        TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Admin Email', prefixIcon: Icon(Icons.admin_panel_settings_outlined)), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
        const SizedBox(height: 14),
        TextFormField(
          controller: _passCtrl, obscureText: _obscure,
          decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _obscure = !_obscure))),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: auth.isLoading ? null : () async { if (!_formKey.currentState!.validate()) return; await ref.read(authStateProvider.notifier).signIn(_emailCtrl.text.trim(), _passCtrl.text); },
            child: auth.isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Sign In to Admin Panel'),
          ),
        ),
      ]),
    ),
  );
}
