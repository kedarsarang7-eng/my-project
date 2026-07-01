import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../data/repositories/marketing_repository.dart';
import '../../data/models/campaign_model.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Create Campaign Screen
class CreateCampaignScreen extends StatefulWidget {
  const CreateCampaignScreen({super.key});

  @override
  State<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends State<CreateCampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = sl<MarketingRepository>();

  final _nameController = TextEditingController();
  final _messageController = TextEditingController();

  CampaignType _selectedType = CampaignType.whatsapp;
  TargetSegment _selectedSegment = TargetSegment.all;
  DateTime? _scheduledDate;
  bool _isLoading = false;

  List<Map<String, dynamic>> _templates = [];
  String? _selectedTemplateId;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) return;

    final result = await _repository.getTemplates(userId);
    if (result.isSuccess) {
      var templates = result.data!;
      if (templates.isEmpty) {
        await _repository.initializeSystemTemplates(userId);
        final reloadResult = await _repository.getTemplates(userId);
        if (reloadResult.isSuccess) {
          templates = reloadResult.data!;
        }
      }
      setState(() => _templates = templates);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Create Campaign'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Campaign Details Section
            _buildSectionHeader('Campaign Details', Icons.campaign),
            const SizedBox(height: 12),
            _buildCard(
              isDark,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Campaign Name',
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Campaign Type
                DropdownButtonFormField<CampaignType>(
                  value: _selectedType,
                  decoration: InputDecoration(
                    labelText: 'Channel',
                    prefixIcon: const Icon(Icons.send),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: CampaignType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(
                            _getTypeIcon(type),
                            size: 20,
                            color: _getTypeColor(type),
                          ),
                          const SizedBox(width: 8),
                          Text(_formatType(type)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedType = v!),
                ),
                const SizedBox(height: 16),

                // Target Segment
                DropdownButtonFormField<TargetSegment>(
                  value: _selectedSegment,
                  decoration: InputDecoration(
                    labelText: 'Target Customers',
                    prefixIcon: const Icon(Icons.people),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: TargetSegment.values.map((seg) {
                    return DropdownMenuItem(
                      value: seg,
                      child: Text(_formatSegment(seg)),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedSegment = v!),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Message Section
            _buildSectionHeader('Message', Icons.message),
            const SizedBox(height: 12),
            _buildCard(
              isDark,
              children: [
                // Template Selector
                if (_templates.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedTemplateId,
                    decoration: InputDecoration(
                      labelText: 'Use Template (Optional)',
                      prefixIcon: const Icon(Icons.description),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    hint: const Text('Select template'),
                    isExpanded: true,
                    items: _templates.map((t) {
                      return DropdownMenuItem(
                        value: t['id'] as String,
                        child: Text(t['name'] as String),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() => _selectedTemplateId = v);
                      if (v != null) {
                        final template = _templates.firstWhere(
                          (t) => t['id'] == v,
                        );
                        _messageController.text = template['content'] as String;
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Message Input
                TextFormField(
                  controller: _messageController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    hintText:
                        'Use {{customer_name}}, {{amount}}, {{shop_name}} as placeholders',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),

                const SizedBox(height: 12),

                // Placeholder Chips
                Wrap(
                  spacing: 8,
                  children: [
                    _buildPlaceholderChip('{{customer_name}}'),
                    _buildPlaceholderChip('{{amount}}'),
                    _buildPlaceholderChip('{{shop_name}}'),
                    _buildPlaceholderChip('{{due_date}}'),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Schedule Section
            _buildSectionHeader('Schedule (Optional)', Icons.schedule),
            const SizedBox(height: 12),
            _buildCard(
              isDark,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _scheduledDate != null ? Icons.schedule : Icons.send,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    _scheduledDate != null
                        ? 'Scheduled: ${_formatDate(_scheduledDate!)}'
                        : 'Send Immediately',
                  ),
                  subtitle: Text(
                    _scheduledDate != null
                        ? 'Tap to change'
                        : 'Tap to schedule for later',
                  ),
                  trailing: _scheduledDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              setState(() => _scheduledDate = null),
                        )
                      : null,
                  onTap: _selectScheduleDate,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Create Button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createCampaign,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        _scheduledDate != null
                            ? 'Schedule Campaign'
                            : 'Create & Send',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildCard(bool isDark, {required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildPlaceholderChip(String placeholder) {
    return ActionChip(
      label: Text(placeholder, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        _messageController.text += placeholder;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length),
        );
      },
    );
  }

  String _formatType(CampaignType type) {
    switch (type) {
      case CampaignType.whatsapp:
        return 'WhatsApp';
      case CampaignType.sms:
        return 'SMS';
      case CampaignType.both:
        return 'Both';
    }
  }

  String _formatSegment(TargetSegment segment) {
    switch (segment) {
      case TargetSegment.all:
        return 'All Customers';
      case TargetSegment.highValue:
        return 'High Value Customers';
      case TargetSegment.inactive:
        return 'Inactive Customers';
      case TargetSegment.overdue:
        return 'Customers with Due Payments';
      case TargetSegment.custom:
        return 'Custom Filter';
    }
  }

  Color _getTypeColor(CampaignType type) {
    switch (type) {
      case CampaignType.whatsapp:
        return const Color(0xFF25D366);
      case CampaignType.sms:
        return Colors.blue;
      case CampaignType.both:
        return Colors.purple;
    }
  }

  IconData _getTypeIcon(CampaignType type) {
    switch (type) {
      case CampaignType.whatsapp:
        return Icons.chat;
      case CampaignType.sms:
        return Icons.sms;
      case CampaignType.both:
        return Icons.message;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectScheduleDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _scheduledDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _createCampaign() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final userId = sl<SessionManager>().ownerId;
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not logged in')));
      return;
    }

    try {
      await _repository.createCampaign(
        userId: userId,
        name: _nameController.text.trim(),
        type: _selectedType.name.toUpperCase(),
        targetSegment: _selectedSegment.name.toUpperCase(),
        message: _messageController.text,
        templateId: _selectedTemplateId,
        scheduledAt: _scheduledDate,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Campaign created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
