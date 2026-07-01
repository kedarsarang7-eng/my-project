import 'package:flutter/material.dart';
import '../models/gst_settings_model.dart';
import '../repositories/gst_repository.dart';
import '../services/gstin_validator.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/session/session_manager.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// GST Settings Screen - Configure GST registration and preferences
class GstSettingsScreen extends StatefulWidget {
  const GstSettingsScreen({super.key});

  @override
  State<GstSettingsScreen> createState() => _GstSettingsScreenState();
}

class _GstSettingsScreenState extends State<GstSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gstinController = TextEditingController();
  final _legalNameController = TextEditingController();
  final _tradeNameController = TextEditingController();

  final GstRepository _gstRepo = GstRepository();

  bool _isLoading = true;
  bool _isSaving = false;
  GstSettingsModel? _settings;
  String? _selectedStateCode;
  String _filingFrequency = 'MONTHLY';
  bool _isCompositionScheme = false;
  bool _isEInvoiceEnabled = false;
  DateTime? _registrationDate;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _gstinController.dispose();
    _legalNameController.dispose();
    _tradeNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final userId = sl<SessionManager>().ownerId;
      if (userId == null) return;

      final settings = await _gstRepo.getGstSettings(userId);
      if (settings != null) {
        _settings = settings;
        _gstinController.text = settings.gstin ?? '';
        _legalNameController.text = settings.legalName ?? '';
        _tradeNameController.text = settings.tradeName ?? '';
        _selectedStateCode = settings.stateCode;
        _filingFrequency = settings.filingFrequency;
        _isCompositionScheme = settings.isCompositionScheme;
        _isEInvoiceEnabled = settings.isEInvoiceEnabled;
        _registrationDate = settings.registrationDate;
      }
    } catch (e) {
      debugPrint('Error loading GST settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final userId = sl<SessionManager>().ownerId;
      if (userId == null) return;

      // Extract state code from GSTIN if provided
      String? stateCode = _selectedStateCode;
      if (_gstinController.text.isNotEmpty && stateCode == null) {
        stateCode = GstinValidator.getStateCode(_gstinController.text);
      }

      final settings = GstSettingsModel(
        id: userId,
        gstin: _gstinController.text.isEmpty
            ? null
            : _gstinController.text.toUpperCase(),
        stateCode: stateCode,
        legalName: _legalNameController.text.isEmpty
            ? null
            : _legalNameController.text,
        tradeName: _tradeNameController.text.isEmpty
            ? null
            : _tradeNameController.text,
        filingFrequency: _filingFrequency,
        isCompositionScheme: _isCompositionScheme,
        isEInvoiceEnabled: _isEInvoiceEnabled,
        registrationDate: _registrationDate,
        createdAt: _settings?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _gstRepo.saveGstSettings(settings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GST settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GST Settings'),
        actions: [
          if (!_isLoading)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save'),
            ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // GST Registration Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GST Registration',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // GSTIN Field
                            TextFormField(
                              controller: _gstinController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'GSTIN',
                                hintText: '22AAAAA0000A1Z5',
                                prefixIcon: Icon(Icons.business),
                                helperText:
                                    '15-character GST registration number',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return null; // Optional
                                }
                                final result = GstinValidator.validateGstin(
                                  value,
                                );
                                if (!result.isValid) {
                                  return result.errorMessage;
                                }
                                return null;
                              },
                              onChanged: (value) {
                                if (value.length >= 2) {
                                  setState(() {
                                    _selectedStateCode = value.substring(0, 2);
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            // State Dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedStateCode,
                              decoration: const InputDecoration(
                                labelText: 'State',
                                prefixIcon: Icon(Icons.location_on),
                              ),
                              items: IndianStates.sortedList.map((entry) {
                                return DropdownMenuItem(
                                  value: entry.key,
                                  child: Text('${entry.key} - ${entry.value}'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedStateCode = value);
                              },
                            ),
                            const SizedBox(height: 16),

                            // Legal Name
                            TextFormField(
                              controller: _legalNameController,
                              decoration: const InputDecoration(
                                labelText: 'Legal Name',
                                prefixIcon: Icon(Icons.badge),
                                helperText: 'As per GST registration',
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Trade Name
                            TextFormField(
                              controller: _tradeNameController,
                              decoration: const InputDecoration(
                                labelText: 'Trade Name (Optional)',
                                prefixIcon: Icon(Icons.store),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Registration Date
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.calendar_today),
                              title: const Text('Registration Date'),
                              subtitle: Text(
                                _registrationDate != null
                                    ? '${_registrationDate!.day}/${_registrationDate!.month}/${_registrationDate!.year}'
                                    : 'Not set',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _registrationDate ?? DateTime.now(),
                                  firstDate: DateTime(
                                    2017,
                                    7,
                                    1,
                                  ), // GST launch date
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  setState(() => _registrationDate = date);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Filing Settings Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filing Settings',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Filing Frequency
                            DropdownButtonFormField<String>(
                              value: _filingFrequency,
                              decoration: const InputDecoration(
                                labelText: 'Filing Frequency',
                                prefixIcon: Icon(Icons.schedule),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'MONTHLY',
                                  child: Text('Monthly'),
                                ),
                                DropdownMenuItem(
                                  value: 'QUARTERLY',
                                  child: Text('Quarterly (QRMP)'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _filingFrequency = value);
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            // Composition Scheme
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Composition Scheme'),
                              subtitle: const Text(
                                'Flat tax rate, no input credit',
                              ),
                              value: _isCompositionScheme,
                              onChanged: (value) {
                                setState(() => _isCompositionScheme = value);
                              },
                            ),

                            // E-Invoice
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('E-Invoice Enabled'),
                              subtitle: const Text(
                                'Generate IRN for B2B invoices',
                              ),
                              value: _isEInvoiceEnabled,
                              onChanged: (value) {
                                setState(() => _isEInvoiceEnabled = value);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Info Card
                    Card(
                      color: theme.colorScheme.primaryContainer.withOpacity(
                        0.3,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'GST features will only appear on invoices after you save these settings with a valid GSTIN.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}
