import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../data/super_admin_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Generate License Key Screen — Full Form (BUG-LIC-011 fix)
///
/// All fields: Plan, Duration, Business Type, Owner Name/Email/Phone,
/// Business Name, Max Devices, Notes.
class GenerateLicenseScreen extends StatefulWidget {
  const GenerateLicenseScreen({super.key});

  @override
  State<GenerateLicenseScreen> createState() => _GenerateLicenseScreenState();
}

class _GenerateLicenseScreenState extends State<GenerateLicenseScreen> {
  final SuperAdminRepository _repo = SuperAdminRepository();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _ownerNameCtrl = TextEditingController();
  final _ownerEmailCtrl = TextEditingController();
  final _ownerPhoneCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _maxDevicesCtrl = TextEditingController(text: '1');

  String _selectedPlan = 'basic';
  String _selectedDuration = '12 months';
  String _selectedBusinessType = 'general';
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _generatedResult;

  static const List<String> _plans = ['basic', 'pro', 'premium', 'enterprise'];

  static const List<String> _durations = [
    '1 month', '3 months', '6 months', '12 months',
    '2 Years', '3 Years', 'Lifetime',
  ];

  static const List<String> _businessTypes = [
    'general', 'grocery', 'pharmacy', 'restaurant', 'clothing',
    'electronics', 'mobile_shop', 'computer_shop', 'hardware',
    'service', 'wholesale', 'petrol_pump', 'vegetables_broker',
    'clinic', 'book_store', 'jewellery', 'auto_parts', 'other',
  ];

  @override
  void dispose() {
    _ownerNameCtrl.dispose();
    _ownerEmailCtrl.dispose();
    _ownerPhoneCtrl.dispose();
    _businessNameCtrl.dispose();
    _notesCtrl.dispose();
    _maxDevicesCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateKey() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isLoading = true; _error = null; _generatedResult = null; });

    try {
      final result = await _repo.generateLicenseKey(
        plan: _selectedPlan,
        duration: _selectedDuration,
        businessType: _selectedBusinessType,
        ownerName: _ownerNameCtrl.text.trim().isEmpty ? null : _ownerNameCtrl.text.trim(),
        ownerEmail: _ownerEmailCtrl.text.trim().isEmpty ? null : _ownerEmailCtrl.text.trim(),
        ownerPhone: _ownerPhoneCtrl.text.trim().isEmpty ? null : _ownerPhoneCtrl.text.trim(),
        businessName: _businessNameCtrl.text.trim().isEmpty ? null : _businessNameCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        maxDevices: int.tryParse(_maxDevicesCtrl.text) ?? 1,
      );
      setState(() { _generatedResult = result; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label copied to clipboard'),
          backgroundColor: FuturisticColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FuturisticColors.background,
      appBar: AppBar(
        title: const Text('Generate License Key'),
        backgroundColor: FuturisticColors.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              _buildGlassCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: FuturisticColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.vpn_key_rounded, color: FuturisticColors.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('New License Key', style: TextStyle(fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20), fontWeight: FontWeight.bold, color: FuturisticColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text('Generate a DKX license with owner info', style: TextStyle(color: FuturisticColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Plan & Duration ──
              _buildGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('License Configuration'),
                    const SizedBox(height: 16),
                    _buildDropdown('Plan Tier', _selectedPlan, _plans, (v) => setState(() => _selectedPlan = v!)),
                    const SizedBox(height: 16),
                    _buildDropdown('Duration', _selectedDuration, _durations, (v) => setState(() => _selectedDuration = v!)),
                    const SizedBox(height: 16),
                    _buildDropdown('Business Type', _selectedBusinessType, _businessTypes, (v) => setState(() => _selectedBusinessType = v!)),
                    const SizedBox(height: 16),
                    _buildTextField(_maxDevicesCtrl, 'Max Devices', icon: Icons.devices, keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 1 || n > 10) return 'Enter 1-10';
                        return null;
                      }),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Owner Info ──
              _buildGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Owner Information'),
                    const SizedBox(height: 16),
                    _buildTextField(_ownerNameCtrl, 'Owner Name', icon: Icons.person),
                    const SizedBox(height: 12),
                    _buildTextField(_ownerEmailCtrl, 'Owner Email', icon: Icons.email, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _buildTextField(_ownerPhoneCtrl, 'Owner Phone', icon: Icons.phone, keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    _buildTextField(_businessNameCtrl, 'Business Name', icon: Icons.storefront),
                    const SizedBox(height: 12),
                    _buildTextField(_notesCtrl, 'Notes / Remarks', icon: Icons.notes, maxLines: 3),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Generate Button ──
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _generateKey,
                  icon: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.key, color: Colors.white),
                  label: Text(
                    _isLoading ? 'Generating...' : 'Generate Key',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FuturisticColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              // ── Error ──
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: FuturisticColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: FuturisticColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: FuturisticColors.error),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_error!, style: TextStyle(color: FuturisticColors.error))),
                    ],
                  ),
                ),
              ],

              // ── Result ──
              if (_generatedResult != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
                  decoration: BoxDecoration(
                    color: FuturisticColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: FuturisticColors.success.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: FuturisticColors.success, size: 28),
                          const SizedBox(width: 12),
                          Text('License Generated!', style: TextStyle(fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20), fontWeight: FontWeight.bold, color: FuturisticColors.success)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildResultRow('License Key', _generatedResult!['license_key'] ?? '', isBold: true, copyable: true),
                      const Divider(height: 24, color: FuturisticColors.success),
                      _buildResultRow('Tenant ID', _generatedResult!['tenant_id'] ?? '', copyable: true),
                      const Divider(height: 24, color: FuturisticColors.success),
                      _buildResultRow('Plan', (_generatedResult!['plan'] ?? '').toString().toUpperCase()),
                      const Divider(height: 24, color: FuturisticColors.success),
                      _buildResultRow('Expiry Date', _generatedResult!['expiry_date'] ?? ''),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: FuturisticColors.premiumCardDecoration(),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: FuturisticColors.textPrimary));
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: FuturisticColors.surface,
      style: TextStyle(color: FuturisticColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: FuturisticColors.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: FuturisticColors.border)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: items.map((v) => DropdownMenuItem(value: v, child: Text(v.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w500)))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, {
    IconData? icon, TextInputType? keyboardType, int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: FuturisticColors.textPrimary),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: FuturisticColors.textSecondary),
        prefixIcon: icon != null ? Icon(icon, color: FuturisticColors.textSecondary, size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: FuturisticColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: FuturisticColors.primary)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {bool isBold = false, bool copyable = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 110, child: Text(label, style: TextStyle(fontSize: 14, color: FuturisticColors.textSecondary, fontWeight: FontWeight.w500))),
        Expanded(
          child: SelectableText(value, style: TextStyle(
            fontSize: isBold ? 18 : 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontFamily: isBold ? 'monospace' : null,
            color: FuturisticColors.textPrimary,
            letterSpacing: isBold ? 1.2 : 0,
          )),
        ),
        if (copyable) IconButton(
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () => _copyToClipboard(value, label),
          tooltip: 'Copy $label',
          color: FuturisticColors.primary,
        ),
      ],
    );
  }
}
