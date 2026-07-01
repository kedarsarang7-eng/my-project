// Invoice Settings Screen
// Manage shop details, signature, and invoice preferences
//
// Created: 2024-12-25
// Author: DukanX Team

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_state_providers.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/repository/shop_repository.dart';
import '../../../services/signature_manager.dart';
import '../../../services/invoice_pdf_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class InvoiceSettingsScreen extends ConsumerStatefulWidget {
  const InvoiceSettingsScreen({super.key});

  @override
  ConsumerState<InvoiceSettingsScreen> createState() =>
      _InvoiceSettingsScreenState();
}

class _InvoiceSettingsScreenState extends ConsumerState<InvoiceSettingsScreen> {
  final _signatureManager =
      SignatureManager(); // Still using this for now, but will refactor later if needed
  final _shopRepository = sl<ShopRepository>();
  final _session = sl<SessionManager>();

  // Controllers
  final _shopNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _termsCtrl = TextEditingController();

  // State
  Uint8List? _signatureBytes;
  InvoiceLanguage _selectedLanguage = InvoiceLanguage.english;
  bool _showTax = false;
  bool _isGstBill = false;
  bool _isLoading = true;
  bool _isSaving = false;

  final GlobalKey<SignatureDrawingCanvasState> _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _addressCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _gstinCtrl.dispose();
    _termsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final ownerId = _session.ownerId;
      if (ownerId == null) return;

      // Load shop profile
      final result = await _shopRepository.getShopProfile(ownerId);
      final profile = result.data;
      if (profile != null) {
        setState(() {
          _shopNameCtrl.text = profile.name;
          _ownerNameCtrl.text = profile.ownerName ?? '';
          _addressCtrl.text = profile.address ?? '';
          _mobileCtrl.text = profile.phone ?? '';
          _emailCtrl.text = profile.email ?? '';
          _gstinCtrl.text = profile.gstin ?? '';
          _termsCtrl.text = profile.invoiceTerms ?? '';
          _showTax = profile.showTaxOnInvoice;
          _isGstBill = profile.isGstRegistered;

          final langIndex = profile.invoiceLanguage;
          if (langIndex < InvoiceLanguage.values.length) {
            _selectedLanguage = InvoiceLanguage.values[langIndex];
          }
        });
      }

      // Load signature
      final signature = await _signatureManager.getSignature();
      if (signature != null) {
        setState(() => _signatureBytes = signature);
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      final ownerId = _session.ownerId;
      if (ownerId == null) throw Exception('Not logged in');

      // Save profile settings
      await _shopRepository.updateShopProfile(
        ownerId: ownerId,
        shopName: _shopNameCtrl.text.trim(),
        ownerName: _ownerNameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        phone: _mobileCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        gstin: _gstinCtrl.text.trim(),
        invoiceTerms: _termsCtrl.text.trim(),
        showTaxOnInvoice: _showTax,
        isGstRegistered: _isGstBill,
        invoiceLanguage: _selectedLanguage.index,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSignatureOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add Signature',
              style: GoogleFonts.outfit(
                fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildOptionTile(
              icon: Icons.draw_rounded,
              title: 'Draw Signature',
              subtitle: 'Draw your signature on canvas',
              onTap: () {
                Navigator.pop(context);
                _showDrawSignatureSheet();
              },
            ),
            const SizedBox(height: 12),
            _buildOptionTile(
              icon: Icons.photo_library_rounded,
              title: 'Upload from Gallery',
              subtitle: 'Choose signature image',
              onTap: () async {
                Navigator.pop(context);
                final bytes = await _signatureManager
                    .pickSignatureFromGallery();
                if (bytes != null) {
                  final saved = await _signatureManager.saveSignature(bytes);
                  if (saved && mounted) {
                    setState(() => _signatureBytes = bytes);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Signature saved!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 12),
            _buildOptionTile(
              icon: Icons.camera_alt_rounded,
              title: 'Take Photo',
              subtitle: 'Capture signature image',
              onTap: () async {
                Navigator.pop(context);
                final bytes = await _signatureManager.pickSignatureFromCamera();
                if (bytes != null) {
                  final saved = await _signatureManager.saveSignature(bytes);
                  if (saved && mounted) {
                    setState(() => _signatureBytes = bytes);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Signature saved!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
            ),
            if (_signatureBytes != null) ...[
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.delete_rounded,
                title: 'Remove Signature',
                subtitle: 'Delete current signature',
                isDestructive: true,
                onTap: () async {
                  Navigator.pop(context);
                  final deleted = await _signatureManager.deleteSignature();
                  if (deleted && mounted) {
                    setState(() => _signatureBytes = null);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signature removed')),
                    );
                  }
                },
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showDrawSignatureSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Draw Your Signature',
                  style: GoogleFonts.outfit(
                    fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => _canvasKey.currentState?.clear(),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Drawing Canvas
            Center(
              child: SignatureDrawingCanvas(
                key: _canvasKey,
                width: MediaQuery.of(context).size.width - 64,
                height: 180,
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final state = _canvasKey.currentState;
                      if (state == null || state.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please draw your signature'),
                          ),
                        );
                        return;
                      }

                      final bytes = await _signatureManager
                          .convertDrawingToImage(
                            state.strokes,
                            Size(MediaQuery.of(context).size.width - 64, 180),
                          );

                      if (bytes != null) {
                        final saved = await _signatureManager.saveSignature(
                          bytes,
                        );
                        if (saved && mounted) {
                          setState(() => _signatureBytes = bytes);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Signature saved!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                    ),
                    child: const Text(
                      'Save Signature',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: isDestructive ? Colors.red.shade50 : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDestructive ? Colors.red.shade100 : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? Colors.red : const Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        color: isDestructive ? Colors.red : Colors.black87,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Invoice Settings',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveSettings,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shop Details Section
                  _buildSectionTitle('Shop Details', isDark),
                  _buildCard(
                    isDark,
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _shopNameCtrl,
                          label: 'Shop Name',
                          icon: Icons.storefront_rounded,
                          isDark: isDark,
                        ),
                        _buildTextField(
                          controller: _ownerNameCtrl,
                          label: 'Owner / Proprietor Name',
                          icon: Icons.person_rounded,
                          isDark: isDark,
                        ),
                        _buildTextField(
                          controller: _addressCtrl,
                          label: 'Shop Address',
                          icon: Icons.location_on_rounded,
                          isDark: isDark,
                          maxLines: 2,
                        ),
                        _buildTextField(
                          controller: _mobileCtrl,
                          label: 'Mobile Number',
                          icon: Icons.phone_rounded,
                          isDark: isDark,
                          keyboardType: TextInputType.phone,
                        ),
                        _buildTextField(
                          controller: _emailCtrl,
                          label: 'Email (Optional)',
                          icon: Icons.email_rounded,
                          isDark: isDark,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        _buildTextField(
                          controller: _gstinCtrl,
                          label: 'GSTIN (Optional)',
                          icon: Icons.receipt_long_rounded,
                          isDark: isDark,
                          isCaps: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Signature Section
                  _buildSectionTitle('Your Signature', isDark),
                  _buildCard(
                    isDark,
                    child: Column(
                      children: [
                        // Signature Preview
                        Container(
                          width: double.infinity,
                          height: 120,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white24
                                  : Colors.grey.shade300,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: _signatureBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(
                                    _signatureBytes!,
                                    fit: BoxFit.contain,
                                  ),
                                )
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.draw_rounded,
                                        size: 40,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No signature added',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white38
                                              : Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),

                        // Add/Change Signature Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _showSignatureOptions,
                            icon: Icon(
                              _signatureBytes != null
                                  ? Icons.edit_rounded
                                  : Icons.add_rounded,
                            ),
                            label: Text(
                              _signatureBytes != null
                                  ? 'Change Signature'
                                  : 'Add Signature',
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white24
                                    : const Color(0xFF1E3A8A),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Invoice Preferences
                  _buildSectionTitle('Invoice Preferences', isDark),
                  _buildCard(
                    isDark,
                    child: Column(
                      children: [
                        // Language Selection
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.language_rounded,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          title: Text(
                            'Invoice Language',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(_getLanguageName(_selectedLanguage)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showLanguageSelector,
                        ),
                        const Divider(),

                        // Show Tax
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.percent_rounded,
                              color: Colors.green,
                            ),
                          ),
                          title: Text(
                            'Show Tax on Invoice',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: const Text(
                            'Display tax column and amounts',
                          ),
                          value: _showTax,
                          onChanged: (v) => setState(() => _showTax = v),
                        ),
                        const Divider(),

                        // GST Invoice
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.receipt_rounded,
                              color: Colors.orange,
                            ),
                          ),
                          title: Text(
                            'GST Registered',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: const Text('Generate Tax Invoice header'),
                          value: _isGstBill,
                          onChanged: (v) => setState(() => _isGstBill = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Terms & Conditions
                  _buildSectionTitle('Terms & Conditions', isDark),
                  _buildCard(
                    isDark,
                    child: TextField(
                      controller: _termsCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Enter your invoice terms and conditions...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white24
                                : Colors.grey.shade300,
                          ),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade50,
                      ),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildCard(bool isDark, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool isCaps = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textCapitalization: isCaps
            ? TextCapitalization.characters
            : TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: isDark ? Colors.white54 : Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
          ),
          filled: true,
          fillColor: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.shade50,
        ),
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      ),
    );
  }

  String _getLanguageName(InvoiceLanguage lang) {
    switch (lang) {
      case InvoiceLanguage.english:
        return 'English';
      case InvoiceLanguage.hindi:
        return 'à¤¹à¤¿à¤‚à¤¦à¥€ (Hindi)';
      case InvoiceLanguage.marathi:
        return 'à¤®à¤°à¤¾à¤ à¥€ (Marathi)';
      case InvoiceLanguage.gujarati:
        return 'àª—à«àªœàª°àª¾àª¤à«€ (Gujarati)';
      case InvoiceLanguage.tamil:
        return 'à®¤à®®à®¿à®´à¯ (Tamil)';
      case InvoiceLanguage.telugu:
        return 'à°¤à±†à°²à±à°—à± (Telugu)';
      case InvoiceLanguage.kannada:
        return 'à²•à²¨à³à²¨à²¡ (Kannada)';
      case InvoiceLanguage.bengali:
        return 'à¦¬à¦¾à¦‚à¦²à¦¾ (Bengali)';
      case InvoiceLanguage.punjabi:
        return 'à¨ªà©°à¨œà¨¾à¨¬à©€ (Punjabi)';
      case InvoiceLanguage.malayalam:
        return 'à´®à´²à´¯à´¾à´³à´‚ (Malayalam)';
      case InvoiceLanguage.urdu:
        return 'Ø§Ø±Ø¯Ùˆ (Urdu)';
      case InvoiceLanguage.odia:
        return 'à¬“à¬¡à¬¿à¬† (Odia)';
      case InvoiceLanguage.assamese:
        return 'à¦…à¦¸à¦®à§€à¦¯à¦¼à¦¾ (Assamese)';
    }
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Select Invoice Language',
                style: GoogleFonts.outfit(
                  fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: InvoiceLanguage.values.length,
                itemBuilder: (context, index) {
                  final lang = InvoiceLanguage.values[index];
                  final isSelected = lang == _selectedLanguage;

                  return ListTile(
                    leading: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: Color(0xFF1E3A8A),
                          )
                        : const Icon(Icons.circle_outlined, color: Colors.grey),
                    title: Text(_getLanguageName(lang)),
                    onTap: () {
                      setState(() => _selectedLanguage = lang);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
