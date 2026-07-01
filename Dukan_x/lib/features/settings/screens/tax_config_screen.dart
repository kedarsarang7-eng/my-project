// ============================================================================
// TAX CONFIGURATION SCREEN - GST SLAB MANAGEMENT
// ============================================================================
// Configure default GST rates, HSN/SAC mappings, and tax preferences.
// ============================================================================
import 'package:flutter/material.dart';
import '../../../core/theme/futuristic_colors.dart';
import '../../../widgets/modern_ui_components.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class TaxConfigScreen extends StatefulWidget {
  const TaxConfigScreen({super.key});

  @override
  State<TaxConfigScreen> createState() => _TaxConfigScreenState();
}

class _TaxConfigScreenState extends State<TaxConfigScreen> {
  // GST Slabs
  static const List<double> gstSlabs = [0, 5, 12, 18, 28];
  double _defaultGstRate = 18;
  bool _gstEnabled = true;
  bool _compositionScheme = false;
  String _gstState = 'Maharashtra';
  final _gstinController = TextEditingController();
  bool _loading = true;

  // Indian states
  static const List<String> indianStates = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    'Delhi',
    'Jammu & Kashmir',
    'Ladakh',
    'Andaman & Nicobar',
    'Chandigarh',
    'Dadra & Nagar Haveli',
    'Daman & Diu',
    'Lakshadweep',
    'Puducherry',
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _gstinController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _defaultGstRate = prefs.getDouble('tax_default_gst_rate') ?? 18;
      _gstEnabled = prefs.getBool('tax_gst_enabled') ?? true;
      _compositionScheme = prefs.getBool('tax_composition_scheme') ?? false;
      _gstState = prefs.getString('tax_gst_state') ?? 'Maharashtra';
      _gstinController.text = prefs.getString('tax_gstin') ?? '';
      _loading = false;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tax_default_gst_rate', _defaultGstRate);
    await prefs.setBool('tax_gst_enabled', _gstEnabled);
    await prefs.setBool('tax_composition_scheme', _compositionScheme);
    await prefs.setString('tax_gst_state', _gstState);
    await prefs.setString('tax_gstin', _gstinController.text.trim());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✅ Tax settings saved!'),
        backgroundColor: FuturisticColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        backgroundColor: isDark
            ? FuturisticColors.darkBackground
            : FuturisticColors.background,
        body: BoundedBox(
          maxWidth: 800,
          child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(FuturisticColors.primary),
          ),
        ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? FuturisticColors.darkBackground
          : FuturisticColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark
            ? FuturisticColors.darkSurface
            : FuturisticColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
              ),
              child: const Icon(
                Icons.account_balance,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              'Tax Configuration',
              style: AppTypography.headlineMedium.copyWith(
                color: isDark
                    ? FuturisticColors.darkTextPrimary
                    : FuturisticColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppSpacing.md),
            decoration: BoxDecoration(
              gradient: AppGradients.primaryGradient,
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
            ),
            child: TextButton.icon(
              onPressed: _savePreferences,
              icon: const Icon(Icons.save, color: Colors.white, size: 18),
              label: Text(
                'SAVE',
                style: AppTypography.labelMedium.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // GST Enable/Disable
            _buildSection(
              isDark,
              title: 'GST Settings',
              icon: Icons.receipt_long,
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      'Enable GST',
                      style: AppTypography.labelLarge.copyWith(
                        color: isDark
                            ? FuturisticColors.darkTextPrimary
                            : FuturisticColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Apply GST on all invoices',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark
                            ? FuturisticColors.darkTextSecondary
                            : FuturisticColors.textSecondary,
                      ),
                    ),
                    value: _gstEnabled,
                    onChanged: (v) => setState(() => _gstEnabled = v),
                    activeColor: FuturisticColors.primary,
                  ),
                  if (_gstEnabled) ...[
                    SwitchListTile(
                      title: Text(
                        'Composition Scheme',
                        style: AppTypography.labelLarge.copyWith(
                          color: isDark
                              ? FuturisticColors.darkTextPrimary
                              : FuturisticColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'For businesses with turnover < ₹1.5 Cr',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark
                              ? FuturisticColors.darkTextSecondary
                              : FuturisticColors.textSecondary,
                        ),
                      ),
                      value: _compositionScheme,
                      onChanged: (v) => setState(() => _compositionScheme = v),
                      activeColor: FuturisticColors.warning,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // GSTIN
            if (_gstEnabled) ...[
              _buildSection(
                isDark,
                title: 'GSTIN & State',
                icon: Icons.badge,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: TextField(
                        controller: _gstinController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'GSTIN Number',
                          hintText: '22AAAAA0000A1Z5',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.md,
                            ),
                          ),
                          prefixIcon: const Icon(Icons.badge),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _gstState,
                        decoration: InputDecoration(
                          labelText: 'Business State',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.md,
                            ),
                          ),
                          prefixIcon: const Icon(Icons.location_on),
                        ),
                        items: indianStates
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _gstState = v ?? _gstState),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // Default GST Rate
            _buildSection(
              isDark,
              title: 'Default GST Rate',
              icon: Icons.percent,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Text(
                      '${_defaultGstRate.toStringAsFixed(0)}%',
                      style: AppTypography.headlineMedium.copyWith(
                        color: FuturisticColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: responsiveValue<double>(context,
                    mobile: 28.0,
                    tablet: 30.0,
                    desktop: 32.0,  // PRESERVED: Desktop uses exactly 32 as before
                  ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: gstSlabs.map((rate) {
                        final isSelected = _defaultGstRate == rate;
                        return ChoiceChip(
                          label: Text('${rate.toStringAsFixed(0)}%'),
                          selected: isSelected,
                          onSelected: (v) =>
                              setState(() => _defaultGstRate = rate),
                          selectedColor: FuturisticColors.primary.withValues(alpha: 
                            0.2,
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? FuturisticColors.primary
                                : isDark
                                ? FuturisticColors.darkTextPrimary
                                : FuturisticColors.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Applied automatically to new products without a specific GST rate.',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark
                            ? FuturisticColors.darkTextSecondary
                            : FuturisticColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Tax Type Info
            _buildSection(
              isDark,
              title: 'Tax Breakdown',
              icon: Icons.info_outline,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    _buildTaxInfoRow(
                      isDark,
                      'Intra-State (Same State)',
                      'CGST + SGST (split equally)',
                    ),
                    const Divider(),
                    _buildTaxInfoRow(
                      isDark,
                      'Inter-State (Different State)',
                      'IGST (full rate)',
                    ),
                    const Divider(),
                    _buildTaxInfoRow(
                      isDark,
                      'Composition Scheme',
                      'Flat 1% (traders) / 5% (restaurants)',
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

  Widget _buildSection(
    bool isDark, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return ModernCard(
      backgroundColor: isDark
          ? FuturisticColors.darkSurface
          : FuturisticColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(icon, color: FuturisticColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: AppTypography.labelLarge.copyWith(
                    color: isDark
                        ? FuturisticColors.darkTextPrimary
                        : FuturisticColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildTaxInfoRow(bool isDark, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isDark
                    ? FuturisticColors.darkTextPrimary
                    : FuturisticColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.labelSmall.copyWith(
                color: isDark
                    ? FuturisticColors.darkTextSecondary
                    : FuturisticColors.textSecondary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
