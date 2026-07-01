// ignore_for_file: unused_local_variable
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/api/api_client.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Payment Reminders Settings Screen
/// Allows vendors to configure automated payment reminders for customers
class PaymentRemindersScreen extends ConsumerStatefulWidget {
  const PaymentRemindersScreen({super.key});

  @override
  ConsumerState<PaymentRemindersScreen> createState() =>
      _PaymentRemindersScreenState();
}

class _PaymentRemindersScreenState
    extends ConsumerState<PaymentRemindersScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Reminder settings
  bool _remindersEnabled = false;
  int _reminderDaysBefore = 3;
  int _reminderFrequency = 7; // days between repeats
  bool _sendSMS = true;
  bool _sendWhatsApp = false;
  bool _sendPush = true;
  String _defaultReminderMessage =
      'Dear Customer, this is a friendly reminder that your payment of ₹{amount} is due on {due_date}. Please make the payment to avoid late fees. Thank you!';

  final _daysController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _daysController.dispose();
    _frequencyController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final userId = sl<SessionManager>().ownerId;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Fetch reminder settings from API
      final api = sl<ApiClient>();
      final response = await api.get('/api/v1/reminder-settings');

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        setState(() {
          _remindersEnabled = data['enabled'] ?? false;
          _reminderDaysBefore = data['daysBefore'] ?? 3;
          _reminderFrequency = data['frequency'] ?? 7;
          _sendSMS = data['sendSMS'] ?? true;
          _sendWhatsApp = data['sendWhatsApp'] ?? false;
          _sendPush = data['sendPush'] ?? true;
          _defaultReminderMessage = data['message'] ?? _defaultReminderMessage;

          _daysController.text = _reminderDaysBefore.toString();
          _frequencyController.text = _reminderFrequency.toString();
          _messageController.text = _defaultReminderMessage;
        });
      }
    } catch (e) {
      LoggerService.d(
        'PaymentReminders',
        'Error loading reminder settings: $e',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final userId = sl<SessionManager>().ownerId;
      if (userId == null) return;

      final api = sl<ApiClient>();
      final response = await api.put(
        '/api/v1/reminder-settings',
        body: {
          'enabled': _remindersEnabled,
          'daysBefore': int.tryParse(_daysController.text) ?? 3,
          'frequency': int.tryParse(_frequencyController.text) ?? 7,
          'sendSMS': _sendSMS,
          'sendWhatsApp': _sendWhatsApp,
          'sendPush': _sendPush,
          'message': _messageController.text,
        },
      );

      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Reminder settings saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to save: ${response.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _sendTestReminder() async {
    try {
      final api = sl<ApiClient>();
      final response = await api.post(
        '/api/v1/reminders/test',
        body: {
          'message': _messageController.text,
          'channel': _sendSMS
              ? 'sms'
              : _sendWhatsApp
              ? 'whatsapp'
              : 'push',
        },
      );

      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Test reminder sent successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to send test: ${response.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DesktopContentContainer(
      title: 'Payment Reminders',
      subtitle: 'Configure automated reminders for pending payments',
      actions: [
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save Settings',
          ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                  // Enable/Disable Switch
                  Card(
                    child: SwitchListTile(
                      title: const Text(
                        'Enable Payment Reminders',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Automatically send reminders to customers with pending dues',
                      ),
                      value: _remindersEnabled,
                      onChanged: (v) => setState(() => _remindersEnabled = v),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Reminder Timing Settings
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reminder Schedule',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Days before due date
                          TextField(
                            controller: _daysController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Days before due date',
                              hintText: '3',
                              helperText:
                                  'Send first reminder this many days before due date',
                              border: OutlineInputBorder(),
                            ),
                            enabled: _remindersEnabled,
                          ),

                          const SizedBox(height: 16),

                          // Repeat frequency
                          TextField(
                            controller: _frequencyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Repeat every (days)',
                              hintText: '7',
                              helperText:
                                  'Send follow-up reminders at this interval',
                              border: OutlineInputBorder(),
                            ),
                            enabled: _remindersEnabled,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Channel Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notification Channels',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),

                          CheckboxListTile(
                            title: const Text('SMS'),
                            subtitle: const Text(
                              'Send reminders via text message',
                            ),
                            value: _sendSMS,
                            onChanged: _remindersEnabled
                                ? (v) => setState(() => _sendSMS = v ?? false)
                                : null,
                          ),

                          CheckboxListTile(
                            title: const Text('WhatsApp'),
                            subtitle: const Text(
                              'Send reminders via WhatsApp (if available)',
                            ),
                            value: _sendWhatsApp,
                            onChanged: _remindersEnabled
                                ? (v) =>
                                      setState(() => _sendWhatsApp = v ?? false)
                                : null,
                          ),

                          CheckboxListTile(
                            title: const Text('Push Notifications'),
                            subtitle: const Text(
                              'Send push notifications to customer app',
                            ),
                            value: _sendPush,
                            onChanged: _remindersEnabled
                                ? (v) => setState(() => _sendPush = v ?? false)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Message Template
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reminder Message Template',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Available variables: {customer_name}, {amount}, {due_date}, {shop_name}',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),

                          TextField(
                            controller: _messageController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Message Template',
                              hintText: 'Enter your reminder message...',
                              border: OutlineInputBorder(),
                            ),
                            enabled: _remindersEnabled,
                          ),

                          const SizedBox(height: 16),

                          context.isMobile
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _remindersEnabled
                                          ? _sendTestReminder
                                          : null,
                                      icon: const Icon(Icons.send),
                                      label: const Text('Send Test'),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: _remindersEnabled
                                          ? _saveSettings
                                          : null,
                                      icon: _isSaving
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.save),
                                      label: Text(
                                        _isSaving
                                            ? 'Saving...'
                                            : 'Save Settings',
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _remindersEnabled
                                          ? _sendTestReminder
                                          : null,
                                      icon: const Icon(Icons.send),
                                      label: const Text('Send Test'),
                                    ),
                                    const SizedBox(width: 16),
                                    ElevatedButton.icon(
                                      onPressed: _remindersEnabled
                                          ? _saveSettings
                                          : null,
                                      icon: _isSaving
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.save),
                                      label: Text(
                                        _isSaving
                                            ? 'Saving...'
                                            : 'Save Settings',
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
