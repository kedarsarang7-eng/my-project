import 'package:flutter/material.dart';

import '../config/invoice_layout_config.dart';
import '../config/invoice_section.dart';
import '../config/invoice_section_config.dart';
import '../model/universal_invoice_data.dart';
import '../widgets/universal_invoice_template.dart';

/// Admin panel to enable/disable and reorder invoice sections with a live
/// preview that updates in real time.
///
/// OUT OF SCOPE (per Phase 6): subscription-tier gating logic. This panel only
/// edits the layout config; tier enforcement is handled separately using the
/// existing DukanX 4-tier gating config.
class InvoiceSectionsSettingsPanel extends StatefulWidget {
  final InvoiceLayoutConfig initialConfig;
  final UniversalInvoiceData previewData;

  /// Called whenever the config changes (toggle or reorder) so the host can
  /// persist tenant overrides.
  final ValueChanged<InvoiceLayoutConfig>? onChanged;

  const InvoiceSectionsSettingsPanel({
    super.key,
    required this.initialConfig,
    required this.previewData,
    this.onChanged,
  });

  static Key rowKey(InvoiceSection s) => ValueKey('row_${s.name}');

  @override
  State<InvoiceSectionsSettingsPanel> createState() =>
      _InvoiceSectionsSettingsPanelState();
}

class _InvoiceSectionsSettingsPanelState
    extends State<InvoiceSectionsSettingsPanel> {
  late List<InvoiceSectionConfig> _sections;

  @override
  void initState() {
    super.initState();
    _sections = widget.initialConfig.orderedSections;
  }

  InvoiceLayoutConfig get _currentConfig => InvoiceLayoutConfig(
    businessType: widget.initialConfig.businessType,
    schemaVersion: widget.initialConfig.schemaVersion,
    sections: _sections,
  );

  void _emit() => widget.onChanged?.call(_currentConfig);

  void _toggle(int index, bool value) {
    final s = _sections[index];
    if (!s.editable) return; // locked sections cannot be toggled
    setState(() {
      _sections[index] = s.copyWith(enabled: value, visible: value);
    });
    _emit();
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final moved = _sections.removeAt(oldIndex);
      _sections.insert(newIndex, moved);
      // Re-number order to reflect the new sequence.
      for (var i = 0; i < _sections.length; i++) {
        _sections[i] = _sections[i].copyWith(order: i);
      }
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: true,
            itemCount: _sections.length,
            onReorder: _reorder,
            itemBuilder: (context, index) {
              final s = _sections[index];
              return SwitchListTile(
                key: InvoiceSectionsSettingsPanel.rowKey(s.section),
                title: Text(_label(s.section)),
                subtitle: _subtitle(s),
                value: s.enabled && s.visible,
                // Disabled (null) for locked sections so required ones stay on.
                onChanged: s.editable ? (v) => _toggle(index, v) : null,
                secondary: Icon(
                  s.editable ? Icons.drag_handle : Icons.lock_outline,
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        // ── Live preview ──
        Expanded(
          child: Container(
            key: const ValueKey('live_preview'),
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: SingleChildScrollView(
              child: UniversalInvoiceTemplate(
                config: _currentConfig,
                data: widget.previewData,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget? _subtitle(InvoiceSectionConfig s) {
    if (!s.editable) return const Text('Locked (required)');
    if (s.businessTypeSpecific) return const Text('Business-specific');
    return null;
  }

  static String _label(InvoiceSection s) {
    switch (s) {
      case InvoiceSection.businessInfo:
        return 'Business Info';
      case InvoiceSection.customerInfo:
        return 'Customer Info';
      case InvoiceSection.shipping:
        return 'Shipping';
      case InvoiceSection.productTable:
        return 'Product Table';
      case InvoiceSection.tax:
        return 'Tax';
      case InvoiceSection.payment:
        return 'Payment';
      case InvoiceSection.discount:
        return 'Discount';
      case InvoiceSection.bankDetails:
        return 'Bank Details';
      case InvoiceSection.warranty:
        return 'Warranty';
      case InvoiceSection.serialImei:
        return 'Serial / IMEI';
      case InvoiceSection.notes:
        return 'Notes';
      case InvoiceSection.terms:
        return 'Terms';
      case InvoiceSection.qr:
        return 'QR / UPI';
      case InvoiceSection.signature:
        return 'Signature';
      case InvoiceSection.logo:
        return 'Logo';
      case InvoiceSection.watermark:
        return 'Watermark';
    }
  }
}
