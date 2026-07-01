import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/api_error_state_widget.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../services/payment_gateway_api_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Payment Gateway Settings Screen
///
/// Allows Owners/Admins to:
///   - Save PhonePe or Razorpay merchant credentials
///   - Verify and activate credentials
///   - View gateway status
///   - Remove gateway configuration
///
/// All credentials are sent to the backend for KMS encryption.
/// No secrets are stored locally on the desktop.
class PaymentGatewaySettingsScreen extends StatefulWidget {
  const PaymentGatewaySettingsScreen({super.key});

  @override
  State<PaymentGatewaySettingsScreen> createState() =>
      _PaymentGatewaySettingsScreenState();
}

class _PaymentGatewaySettingsScreenState
    extends State<PaymentGatewaySettingsScreen> {
  final _paymentApi = sl<PaymentGatewayApiService>();

  List<GatewayConfig> _configs = [];
  bool _isLoading = true;
  String? _error;
  bool _isActionLoading = false;

  /// Detects authentication errors (401/403) for showing re-login option.
  bool get _isAuthError =>
      _error?.contains('401') == true || _error?.contains('403') == true;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  /// Attempts a token refresh via Cognito session.
  /// Returns true if refresh succeeded, false otherwise.
  Future<bool> _attemptTokenRefresh() async {
    try {
      final sessionManager = sl<SessionManager>();
      // getAccessToken() internally calls CognitoUser.getSession() which
      // handles token refresh via the Cognito SDK's refresh token flow.
      final token = await sessionManager.getAccessToken();
      return token != null;
    } catch (_) {
      return false;
    }
  }

  /// Triggers re-authentication by signing out and letting AuthGate redirect.
  void _triggerReAuth(BuildContext context) {
    sl<SessionManager>().signOut();
  }

  Future<void> _loadConfigs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _configs = await _paymentApi.getGatewayConfigs();
      _error = null;
    } catch (e) {
      // Attempt token refresh for auth errors before showing error
      final errorType = classifyError(e);
      if (errorType == ApiErrorType.auth) {
        final refreshed = await _attemptTokenRefresh();
        if (refreshed) {
          // Retry after successful refresh
          try {
            _configs = await _paymentApi.getGatewayConfigs();
            _error = null;
            if (mounted) setState(() => _isLoading = false);
            return;
          } catch (retryError) {
            // Store error internally — never shown raw to user
            _error = retryError.toString();
          }
        } else {
          _error = e.toString();
        }
      } else {
        _error = e.toString();
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FuturisticColors.background,
      appBar: AppBar(
        title: Text(
          'Payment Gateway Settings',
          style: AppTypography.headlineSmall.copyWith(
            color: FuturisticColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: FuturisticColors.textPrimary),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: FuturisticColors.primary,
                ),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.all(
                  responsiveValue<double>(
                    context,
                    mobile: 16,
                    tablet: 20,
                    desktop: 24,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info banner
                    GlassContainer(
                      borderRadius: 12.0,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.security,
                            color: FuturisticColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your payment credentials are encrypted with AWS KMS and never stored on this device.',
                              style: TextStyle(
                                color: FuturisticColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // PhonePe Section
                    _buildGatewaySection(GatewayType.phonepe),
                    const SizedBox(height: 24),

                    // Razorpay Section
                    _buildGatewaySection(GatewayType.razorpay),

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      ApiErrorStateWidget(
                        userMessage:
                            'Unable to load payment settings. Please try again.',
                        onRetry: _loadConfigs,
                        showReLogin: _isAuthError,
                        onReLogin: () => _triggerReAuth(context),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildGatewaySection(GatewayType type) {
    final config = _configs.where((c) => c.gatewayType == type).firstOrNull;
    final isPhonePe = type == GatewayType.phonepe;
    final name = isPhonePe ? 'PhonePe' : 'Razorpay';
    final icon = isPhonePe ? Icons.phone_android : Icons.credit_card;
    final color = isPhonePe ? const Color(0xFF5F259F) : const Color(0xFF072654);

    return GlassContainer(
      borderRadius: 16.0,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.headlineSmall.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: FuturisticColors.textPrimary,
                      ),
                    ),
                    if (config != null)
                      Text(
                        config.displayName ?? 'Default',
                        style: TextStyle(
                          color: FuturisticColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (config != null) _buildStatusBadge(config.status),
            ],
          ),
          const SizedBox(height: 16),

          if (config == null) ...[
            // Not configured yet
            Text(
              'Not configured',
              style: TextStyle(color: FuturisticColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: EnterpriseButton(
                onPressed: () => _showConfigDialog(type),
                label: 'Set Up $name',
                icon: Icons.add,
                backgroundColor: color,
              ),
            ),
          ] else ...[
            // Configured — show status and actions
            if (config.verifiedAt != null)
              Text(
                'Verified: ${_formatDate(config.verifiedAt!)}',
                style: TextStyle(
                  color: FuturisticColors.textMuted,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (config.status != GatewayConfigStatus.active)
                  Expanded(
                    child: EnterpriseButton(
                      onPressed: _isActionLoading
                          ? null
                          : () => _verifyConfig(type),
                      label: 'Verify',
                      icon: Icons.verified_user,
                      backgroundColor: FuturisticColors.success,
                    ),
                  ),
                if (config.status != GatewayConfigStatus.active)
                  const SizedBox(width: 8),
                Expanded(
                  child: EnterpriseButton(
                    onPressed: () => _showConfigDialog(type),
                    label: 'Update',
                    icon: Icons.edit,
                    backgroundColor: FuturisticColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  child: IconButton(
                    onPressed: () => _deleteConfig(type),
                    icon: Icon(Icons.delete, color: FuturisticColors.error),
                    tooltip: 'Remove $name',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(GatewayConfigStatus status) {
    final color = switch (status) {
      GatewayConfigStatus.active => FuturisticColors.success,
      GatewayConfigStatus.pendingVerification => FuturisticColors.warning,
      GatewayConfigStatus.failed => FuturisticColors.error,
      GatewayConfigStatus.inactive => FuturisticColors.textMuted,
    };
    final label = switch (status) {
      GatewayConfigStatus.active => 'Active',
      GatewayConfigStatus.pendingVerification => 'Pending',
      GatewayConfigStatus.failed => 'Failed',
      GatewayConfigStatus.inactive => 'Inactive',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Future<void> _verifyConfig(GatewayType type) async {
    setState(() => _isActionLoading = true);
    try {
      await _paymentApi.verifyGatewayConfig(type);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gateway verified and activated!'),
            backgroundColor: FuturisticColors.success,
          ),
        );
      }
      await _loadConfigs();
    } catch (e) {
      if (mounted) {
        final errorType = classifyError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessageFor(errorType)),
            backgroundColor: FuturisticColors.error,
          ),
        );
      }
    }
    if (mounted) setState(() => _isActionLoading = false);
  }

  Future<void> _deleteConfig(GatewayType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Gateway?'),
        content: const Text(
          'This will remove the payment gateway configuration. You can reconfigure it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Remove',
              style: TextStyle(color: FuturisticColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _paymentApi.deleteGatewayConfig(type);
      await _loadConfigs();
    } catch (e) {
      if (mounted) {
        final errorType = classifyError(e);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userMessageFor(errorType))));
      }
    }
  }

  void _showConfigDialog(GatewayType type) {
    if (type == GatewayType.phonepe) {
      _showPhonePeConfigDialog();
    } else {
      _showRazorpayConfigDialog();
    }
  }

  void _showPhonePeConfigDialog() {
    final merchantIdCtrl = TextEditingController();
    final saltKeyCtrl = TextEditingController();
    final saltIndexCtrl = TextEditingController(text: '1');
    final displayNameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PhonePe Configuration'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: merchantIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Merchant ID *',
                  hintText: 'Your PhonePe Merchant ID',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: saltKeyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Salt Key *',
                  hintText: 'Your PhonePe Salt Key',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: saltIndexCtrl,
                decoration: const InputDecoration(
                  labelText: 'Salt Index *',
                  hintText: '1',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: displayNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Display Name (optional)',
                  hintText: 'e.g. Main Store',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (merchantIdCtrl.text.isEmpty || saltKeyCtrl.text.isEmpty) {
                return;
              }
              Navigator.pop(ctx);
              setState(() => _isActionLoading = true);
              try {
                await _paymentApi.savePhonePeConfig(
                  merchantId: merchantIdCtrl.text.trim(),
                  saltKey: saltKeyCtrl.text.trim(),
                  saltIndex: saltIndexCtrl.text.trim(),
                  displayName: displayNameCtrl.text.trim().isNotEmpty
                      ? displayNameCtrl.text.trim()
                      : null,
                );
                await _loadConfigs();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'PhonePe configured! Click "Verify" to activate.',
                      ),
                      backgroundColor: FuturisticColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  final errorType = classifyError(e);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(userMessageFor(errorType)),
                      backgroundColor: FuturisticColors.error,
                    ),
                  );
                }
              }
              if (mounted) setState(() => _isActionLoading = false);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRazorpayConfigDialog() {
    final keyIdCtrl = TextEditingController();
    final keySecretCtrl = TextEditingController();
    final webhookSecretCtrl = TextEditingController();
    final displayNameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Razorpay Configuration'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Key ID *',
                  hintText: 'rzp_live_...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keySecretCtrl,
                decoration: const InputDecoration(
                  labelText: 'Key Secret *',
                  hintText: 'Your Razorpay Key Secret',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: webhookSecretCtrl,
                decoration: const InputDecoration(
                  labelText: 'Webhook Secret *',
                  hintText: 'Your Razorpay Webhook Secret',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: displayNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Display Name (optional)',
                  hintText: 'e.g. Main Store',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (keyIdCtrl.text.isEmpty ||
                  keySecretCtrl.text.isEmpty ||
                  webhookSecretCtrl.text.isEmpty) {
                return;
              }
              Navigator.pop(ctx);
              setState(() => _isActionLoading = true);
              try {
                await _paymentApi.saveRazorpayConfig(
                  keyId: keyIdCtrl.text.trim(),
                  keySecret: keySecretCtrl.text.trim(),
                  webhookSecret: webhookSecretCtrl.text.trim(),
                  displayName: displayNameCtrl.text.trim().isNotEmpty
                      ? displayNameCtrl.text.trim()
                      : null,
                );
                await _loadConfigs();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Razorpay configured! Click "Verify" to activate.',
                      ),
                      backgroundColor: FuturisticColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  final errorType = classifyError(e);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(userMessageFor(errorType)),
                      backgroundColor: FuturisticColors.error,
                    ),
                  );
                }
              }
              if (mounted) setState(() => _isActionLoading = false);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
