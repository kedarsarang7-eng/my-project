import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../config/api_config.dart';
import '../../../../core/services/logger_service.dart';

enum _ConnState { idle, testing, connected, disconnected }

/// Server Settings — lets the user point the app at a custom backend URL,
/// validate it, test reachability, and save it. Saved URLs apply immediately
/// (no app restart) because [ApiConfig.baseUrl] reads the cached override.
class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();

  _ConnState _state = _ConnState.idle;
  String? _statusDetail;

  @override
  void initState() {
    super.initState();
    _urlController.text =
        ApiConfig.runtimeBaseUrlOverride ?? ApiConfig.baseUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  String? _validateUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Server URL is required';
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Enter a valid URL (e.g. https://api.example.com)';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'URL must start with http:// or https://';
    }
    return null;
  }

  Future<void> _testConnection() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final base = _urlController.text.trim().replaceAll(RegExp(r'/+$'), '');
    setState(() {
      _state = _ConnState.testing;
      _statusDetail = null;
    });

    try {
      final res = await http
          .get(Uri.parse('$base/health'))
          .timeout(const Duration(seconds: 10));
      final ok = res.statusCode >= 200 && res.statusCode < 500;
      setState(() {
        _state = ok ? _ConnState.connected : _ConnState.disconnected;
        _statusDetail = 'HTTP ${res.statusCode}';
      });
    } catch (e) {
      LoggerService.d('ServerSettings', 'Test connection failed: $e');
      setState(() {
        _state = _ConnState.disconnected;
        _statusDetail = e.toString();
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final base = _urlController.text.trim().replaceAll(RegExp(r'/+$'), '');
    await ApiConfig.setRuntimeBaseUrl(base);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Server settings saved — applied immediately.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _resetToDefault() async {
    await ApiConfig.setRuntimeBaseUrl(null);
    if (!mounted) return;
    setState(() {
      _urlController.text = ApiConfig.baseUrl;
      _state = _ConnState.idle;
      _statusDetail = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reverted to default server.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusIndicator(state: _state, detail: _statusDetail),
              const SizedBox(height: 20),
              TextFormField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Server URL *',
                  hintText: 'https://api.dukanx.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.dns_outlined),
                ),
                validator: _validateUrl,
                onChanged: (_) {
                  if (_state != _ConnState.idle) {
                    setState(() {
                      _state = _ConnState.idle;
                      _statusDetail = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Default: ${ApiConfig.environmentName} environment',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed:
                    _state == _ConnState.testing ? null : _testConnection,
                icon: _state == _ConnState.testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering),
                label: const Text('Test Connection'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _state == _ConnState.testing ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _resetToDefault,
                child: const Text('Reset to Default'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final _ConnState state;
  final String? detail;

  const _StatusIndicator({required this.state, this.detail});

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (state) {
      _ConnState.idle => (Colors.grey, Icons.help_outline, 'Not tested'),
      _ConnState.testing => (Colors.orange, Icons.sync, 'Testing…'),
      _ConnState.connected => (Colors.green, Icons.check_circle, 'Connected'),
      _ConnState.disconnected =>
        (Colors.red, Icons.error_outline, 'Disconnected'),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
