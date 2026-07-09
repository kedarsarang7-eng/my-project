// ============================================================================
// WhatsApp Message Tester — Send test messages from the dashboard
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dukanx/core/openwa/openwa_models.dart';
import 'package:dukanx/features/whatsapp/providers/whatsapp_providers.dart';

class WhatsAppTesterScreen extends ConsumerStatefulWidget {
  const WhatsAppTesterScreen({super.key});

  @override
  ConsumerState<WhatsAppTesterScreen> createState() =>
      _WhatsAppTesterScreenState();
}

class _WhatsAppTesterScreenState
    extends ConsumerState<WhatsAppTesterScreen> {
  final _phoneCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _selectedType = 'text';
  bool _sending = false;
  WAMessageResponse? _lastResult;
  String? _lastError;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(waConnectionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: !connectionState.isUsable
                ? _buildNotConnected(context)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPhoneField(context),
                        const SizedBox(height: 16),
                        _buildTypeSelector(context),
                        const SizedBox(height: 16),
                        _buildMessageField(context),
                        const SizedBox(height: 20),
                        _buildSendButton(context),
                        if (_lastResult != null || _lastError != null)
                          ...[
                            const SizedBox(height: 24),
                            _buildResult(context),
                          ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.science_outlined,
                color: Color(0xFF25D366), size: 28),
            const SizedBox(width: 12),
            Text(
              'Message Tester',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneField(BuildContext context) {
    return TextField(
      controller: _phoneCtrl,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: 'Phone Number',
        hintText: '+91 98765 43210',
        prefixIcon: const Icon(Icons.phone_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        helperText: 'Include country code (e.g., 919876543210)',
      ),
    );
  }

  Widget _buildTypeSelector(BuildContext context) {
    final theme = Theme.of(context);
    final types = ['text', 'image', 'document', 'location'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Message Type',
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: types.map((type) {
            final selected = _selectedType == type;
            return ChoiceChip(
              label: Text(type[0].toUpperCase() + type.substring(1)),
              selected: selected,
              onSelected: (v) => setState(() => _selectedType = type),
              selectedColor: const Color(0xFF25D366).withOpacity(0.2),
              labelStyle: TextStyle(
                color: selected ? const Color(0xFF25D366) : null,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMessageField(BuildContext context) {
    String label;
    String hint;
    switch (_selectedType) {
      case 'image':
        label = 'Image URL';
        hint = 'https://example.com/image.jpg';
      case 'document':
        label = 'Document URL';
        hint = 'https://example.com/invoice.pdf';
      case 'location':
        label = 'Coordinates (lat,lng)';
        hint = '19.0760,72.8777';
      default:
        label = 'Message Text';
        hint = 'Hello from DukanX!';
    }

    return TextField(
      controller: _messageCtrl,
      maxLines: _selectedType == 'text' ? 5 : 2,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSendButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: _sending ? null : _send,
        icon: _sending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.send_rounded),
        label: Text(_sending ? 'Sending...' : 'Send Test Message'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF25D366),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final phone = _phoneCtrl.text.trim();
    final content = _messageCtrl.text.trim();
    if (phone.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone and message are required')),
      );
      return;
    }

    setState(() {
      _sending = true;
      _lastResult = null;
      _lastError = null;
    });

    try {
      final tenantService = ref.read(openWATenantServiceProvider);
      final config = await tenantService.getBusinessConfig();
      final client = await tenantService.getClient();
      final chatId = _formatChatId(phone);

      WAMessageResponse result;
      switch (_selectedType) {
        case 'image':
          result = await client.sendImage(
              config.sessionId!, chatId, url: content);
        case 'document':
          result = await client.sendDocument(
              config.sessionId!, chatId, url: content);
        case 'location':
          final parts = content.split(',');
          final lat = double.tryParse(parts[0].trim()) ?? 0;
          final lng = parts.length > 1
              ? (double.tryParse(parts[1].trim()) ?? 0)
              : 0.0;
          result = await client.sendLocation(
              config.sessionId!, chatId,
              latitude: lat, longitude: lng);
        default:
          result = await client.sendText(
              config.sessionId!, chatId, content);
      }

      setState(() => _lastResult = result);
    } catch (e) {
      setState(() => _lastError = e.toString());
    } finally {
      setState(() => _sending = false);
    }
  }

  Widget _buildResult(BuildContext context) {
    final theme = Theme.of(context);
    final isSuccess = _lastResult != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.3),
        ),
      ),
      color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSuccess
                      ? Icons.check_circle_rounded
                      : Icons.error_rounded,
                  color: isSuccess ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isSuccess ? 'Message Sent!' : 'Send Failed',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isSuccess ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isSuccess)
              Text('Message ID: ${_lastResult!.messageId}',
                  style: theme.textTheme.bodySmall),
            if (!isSuccess)
              Text(_lastError ?? 'Unknown error',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  String _formatChatId(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final withCountry = digits.length == 10 ? '91$digits' : digits;
    return '$withCountry@s.whatsapp.net';
  }

  Widget _buildNotConnected(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.science_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('WhatsApp Not Connected',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
