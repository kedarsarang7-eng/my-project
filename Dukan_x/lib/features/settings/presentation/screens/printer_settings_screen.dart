import 'package:flutter/material.dart';
import '../../../../providers/app_state_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/thermal_print_service.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/modern_ui_components.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Modern Professional Printer Settings Screen
class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  static const _kThermalEnabled = 'printer.thermal.enabled';
  static const _kThermalWidth = 'printer.thermal.width';
  static const _kAutoCut = 'printer.thermal.autocut';

  bool _thermalEnabled = false;
  String _width = '80mm';
  bool _autoCut = true;
  bool _saving = false;

  final ThermalPrintService _thermalService = ThermalPrintService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _thermalEnabled = prefs.getBool(_kThermalEnabled) ?? false;
      _width = prefs.getString(_kThermalWidth) ?? '80mm';
      _autoCut = prefs.getBool(_kAutoCut) ?? true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kThermalEnabled, _thermalEnabled);
    await prefs.setString(_kThermalWidth, _width);
    await prefs.setBool(_kAutoCut, _autoCut);
    setState(() => _saving = false);
    if (!mounted) return;
    _showSuccessSnackBar('Printer settings saved');
  }

  Future<void> _testPrint() async {
    try {
      await _thermalService.configurePrinter(
        ThermalPrinterSettings(width: _width, autoCut: _autoCut),
      );
      await _thermalService.testPrint();
      if (!mounted) return;
      _showSuccessSnackBar('Test print sent successfully');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Test print failed: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return Scaffold(
      backgroundColor: isDark ? FuturisticColors.background : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? FuturisticColors.background : const Color(0xFFF8FAFC),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.print_rounded,
                color: Color(0xFF06B6D4),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Printer Settings',
              style: TextStyle(
                fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_saving ? 'Saving...' : 'Save'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF3B82F6),
                backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info Card
            _buildInfoCard(isDark),
            const SizedBox(height: 24),

            // Thermal Printing Toggle
            _buildSectionHeader('Thermal Printer', isDark),
            const SizedBox(height: 12),
            _buildSettingCard(
              isDark: isDark,
              child: SwitchListTile.adaptive(
                value: _thermalEnabled,
                onChanged: (v) => setState(() => _thermalEnabled = v),
                title: Text(
                  'Enable Thermal Printing',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                subtitle: Text(
                  'Use thermal printer instead of A4 format',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                  ),
                ),
                activeColor: const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 24),

            // Paper Width Selection
            _buildSectionHeader('Paper Width', isDark),
            const SizedBox(height: 12),
            _buildSettingCard(
              isDark: isDark,
              child: Column(
                children: [
                  _buildWidthOption(
                    value: '80mm',
                    label: '80mm',
                    description: 'Standard thermal receipt width',
                    icon: Icons.receipt_long,
                    isDark: isDark,
                  ),
                  Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
                  _buildWidthOption(
                    value: '58mm',
                    label: '58mm',
                    description: 'Compact portable printers',
                    icon: Icons.receipt,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Auto Cut Toggle
            _buildSectionHeader('Advanced Options', isDark),
            const SizedBox(height: 12),
            _buildSettingCard(
              isDark: isDark,
              child: SwitchListTile.adaptive(
                value: _autoCut,
                onChanged: (v) => setState(() => _autoCut = v),
                title: Text(
                  'Auto Cut',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                subtitle: Text(
                  'Automatically cut paper after printing (ESC/POS)',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                  ),
                ),
                activeColor: const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 32),

            // Test Print Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _testPrint,
                icon: const Icon(Icons.print_rounded, size: 22),
                label: const Text(
                  'Test Print',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF06B6D4).withOpacity(0.2), const Color(0xFF06B6D4).withOpacity(0.05)]
              : [const Color(0xFF06B6D4).withOpacity(0.1), const Color(0xFF06B6D4).withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF06B6D4).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF06B6D4),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configure your thermal printer',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Settings apply to all receipts and invoices printed via thermal printer.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
      ),
    );
  }

  Widget _buildSettingCard({required bool isDark, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildWidthOption({
    required String value,
    required String label,
    required String description,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _width == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _width = value),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF3B82F6).withOpacity(isDark ? 0.2 : 0.1)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected ? const Color(0xFF3B82F6) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Radio<String>(
                value: value,
                groupValue: _width,
                onChanged: (v) => setState(() => _width = v ?? value),
                activeColor: const Color(0xFF3B82F6),
                fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                  if (states.contains(MaterialState.selected)) {
                    return const Color(0xFF3B82F6);
                  }
                  return isDark ? const Color(0xFF475569) : const Color(0xFFD1D5DB);
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
