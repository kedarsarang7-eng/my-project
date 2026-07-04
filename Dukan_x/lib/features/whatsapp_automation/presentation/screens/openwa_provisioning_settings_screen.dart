import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/api_error_state_widget.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../services/openwa_provisioning_api_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// OpenWA Provisioning Settings Screen
///
/// Allows Owners/Admins to:
///   - Save OpenWA gateway credentials (base URL, API key, session ID, webhook secret)
///   - Verify the session is reachable and register the delivery webhook
///   - View connection status
///   - Remove the configuration
///
/// Credentials are sent to the backend for storage in AWS Secrets Manager.
/// No secrets are stored locally on the desktop.
class OpenwaProvisioningSettingsScreen extends StatefulWidget {
  const OpenwaProvisioningSettingsScreen({super.key});

  @override
  State<OpenwaProvisioningSettingsScreen> createState() =>
      _OpenwaProvisioningSettingsScreenState();
}

class _OpenwaProvisioningSettingsScreenState
    extends State<OpenwaProvisioningSettingsScreen> {
  final _provisioningApi = sl<OpenwaProvisioningApiService>();

  OpenWaProvisioningConfig? _config;
  bool _isLoading = true;
  String? _error;
  bool _isActionLoading = false;

  /// Detects authentication errors (401/403) for showing re-login option.
  bool get _isAuthError =>
      _error?.contains('401') == true || _error?.contains('403') == true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<bool> _attemptTokenRefresh() async {
    try {
      final sessionManager = sl<SessionManager>();
      final token = await sessionManager.getAccessToken();
      return token != null;
    } catch (_) {
      return false;
    }
  }

  void _triggerReAuth(BuildContext context) {
    sl<SessionManager>().signOut();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _config = await _provisioningApi.getConfig();
      _error = null;
    } catch (e) {
      final errorType = classifyError(e);
      if (errorType == ApiErrorType.auth) {
        final refreshed = await _attemptTokenRefresh();
        if (refreshed) {
          try {
            _config = await _provisioningApi.getConfig();
            _error = null;
            if (mounted) setState(() => _isLoading = false);
            return;
          } catch (retryError) {
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
          'WhatsApp Gateway Settings',
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
                              'Your OpenWA API key and webhook secret are encrypted in AWS Secrets Manager and never stored on this device.',
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

                    _buildGatewaySection(),

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      ApiErrorStateWidget(
                        userMessage:
                            'Unable to load WhatsApp gateway settings. Please try again.',
                        onRetry: _loadConfig,
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

  Widget _buildGatewaySection() {
    final config = _config;
    const color = Color(0xFF25D366); // WhatsApp green

    return GlassContainer(
      borderRadius: 16.0,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.chat, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OpenWA Gateway',
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
            Text(
              'Not configured',
              style: TextStyle(color: FuturisticColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: EnterpriseButton(
                onPressed: () => _showConfigDialog(),
                label: 'Set Up WhatsApp Gateway',
                icon: Icons.add,
                backgroundColor: color,
              ),
            ),
          ] else ...[
            if (config.verifiedAt != null)
              Text(
                'Verified: ${_formatDate(config.verifiedAt!)}',
                style: TextStyle(
                  color: FuturisticColors.textMuted,
                  fontSize: 12,
                ),
              ),
            if (config.status == OpenWaProvisioningStatus.failed &&
                config.lastError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  config.lastError!,
                  style: TextStyle(color: FuturisticColors.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (config.status != OpenWaProvisioningStatus.active)
                  Expanded(
                    child: EnterpriseButton(
                      onPressed: _isActionLoading
                          ? null
                          : () => _verifyConfig(),
                      label: 'Verify',
                      icon: Icons.verified_user,
                      backgroundColor: FuturisticColors.success,
                    ),
                  ),
                if (config.status != OpenWaProvisioningStatus.active)
                  const SizedBox(width: 8),
                Expanded(
                  child: EnterpriseButton(
                    onPressed: () => _showConfigDialog(),
                    label: 'Update',
                    icon: Icons.edit,
                    backgroundColor: FuturisticColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  child: IconButton(
                    onPressed: () => _deleteConfig(),
                    icon: Icon(Icons.delete, color: FuturisticColors.error),
                    tooltip: 'Remove WhatsApp Gateway',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(OpenWaProvisioningStatus status) {
    final color = switch (status) {
      OpenWaProvisioningStatus.active => FuturisticColors.success,
      OpenWaProvisioningStatus.pendingVerification => FuturisticColors.warning,
      OpenWaProvisioningStatus.failed => FuturisticColors.error,
      OpenWaProvisioningStatus.inactive => FuturisticColors.textMuted,
    };
    final label = switch (status) {
      OpenWaProvisioningStatus.active => 'Active',
      OpenWaProvisioningStatus.pendingVerification => 'Pending',
      OpenWaProvisioningStatus.failed => 'Failed',
      OpenWaProvisioningStatus.inactive => 'Inactive',
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

  Future<void> _verifyConfig() async {
    setState(() => _isActionLoading = true);
    try {
      await _provisioningApi.verifyConfig();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('WhatsApp gateway verified and activated!'),
            backgroundColor: FuturisticColors.success,
          ),
        );
      }
      await _loadConfig();
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
      // Reload so a failed verification still shows the updated status/error.
      await _loadConfig();
    }
    if (mounted) setState(() => _isActionLoading = false);
  }

  Future<void> _deleteConfig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove WhatsApp Gateway?'),
        content: const Text(
          'This will remove the OpenWA configuration and stop all WhatsApp automation. You can reconfigure it later.',
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
      await _provisioningApi.deleteConfig();
      await _loadConfig();
    } catch (e) {
      if (mounted) {
        final errorType = classifyError(e);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userMessageFor(errorType))));
      }
    }
  }

  void _showConfigDialog() {
    final baseUrlCtrl = TextEditingController(text: _config?.baseUrl ?? '');
    final apiKeyCtrl = TextEditingController();
    final sessionIdCtrl = TextEditingController(text: _config?.sessionId ?? '');
    final webhookSecretCtrl = TextEditingController();
    final displayNameCtrl = TextEditingController(
      text: _config?.displayName ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('OpenWA Gateway Configuration'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: baseUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Base URL *',
                  hintText: 'https://openwa.example.com',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: apiKeyCtrl,
                decoration: const InputDecoration(
                  labelText: 'API Key *',
                  hintText: 'Your OpenWA API key',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sessionIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Session ID *',
                  hintText: 'OpenWA session ID for this WhatsApp number',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: webhookSecretCtrl,
                decoration: const InputDecoration(
                  labelText: 'Webhook Secret *',
                  hintText: 'Secret used to sign delivery webhooks',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: displayNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Display Name (optional)',
                  hintText: 'e.g. Main Store WhatsApp',
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
              if (baseUrlCtrl.text.isEmpty ||
                  apiKeyCtrl.text.isEmpty ||
                  sessionIdCtrl.text.isEmpty ||
                  webhookSecretCtrl.text.isEmpty) {
                return;
              }
              Navigator.pop(ctx);
              setState(() => _isActionLoading = true);
              try {
                await _provisioningApi.saveConfig(
                  baseUrl: baseUrlCtrl.text.trim(),
                  apiKey: apiKeyCtrl.text.trim(),
                  sessionId: sessionIdCtrl.text.trim(),
                  webhookSecret: webhookSecretCtrl.text.trim(),
                  displayName: displayNameCtrl.text.trim().isNotEmpty
                      ? displayNameCtrl.text.trim()
                      : null,
                );
                await _loadConfig();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'WhatsApp gateway configured! Click "Verify" to activate.',
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
