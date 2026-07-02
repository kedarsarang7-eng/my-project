import '../../../../core/subscription/subscription_tier.dart';
import 'invoice_field_config.dart';
import 'invoice_section.dart';

/// Configuration for a single invoice section.
///
/// Carries the exact 7 behavioral flags mandated by the spec, plus structural
/// identity metadata ([section], [order]) that is intentionally kept separate
/// from the behavioral flags. See design_docs/universal-invoice-architecture.md.
class InvoiceSectionConfig {
  // ── Identity / structural metadata (NOT behavioral flags) ──
  final InvoiceSection section;
  final int order;

  // ── The 7 required behavioral flags ──

  /// Master switch. When false the engine skips this section entirely.
  final bool enabled;

  /// Fields must be filled or the invoice cannot be saved/printed. Used for
  /// regulatory hard-stops. Meaningful only when [enabled] is true.
  final bool required;

  /// Render this section in the output (PDF/thermal/preview). A section may be
  /// enabled (captured) but hidden from the printed document.
  final bool visible;

  /// Whether the shop admin may toggle/modify this section from the Settings
  /// Panel (Phase 6). Locked sections (e.g. tax on a GST bill) set this false.
  final bool editable;

  /// True when the section only appears for specific business types.
  final bool businessTypeSpecific;

  /// Minimum subscription tier required to use this section. Enforcement is
  /// handled separately (Phase 6 / out of scope for the engine).
  final SubscriptionTier subscriptionTier;

  /// Whether the section can fully render with no network (e.g. UPI QR = true,
  /// e-invoice IRN QR = false).
  final bool offlineCompatible;

  /// Optional per-field control (for the product table this defines columns).
  final List<InvoiceFieldConfig> fields;

  const InvoiceSectionConfig({
    required this.section,
    required this.order,
    this.enabled = true,
    this.required = false,
    this.visible = true,
    this.editable = true,
    this.businessTypeSpecific = false,
    this.subscriptionTier = SubscriptionTier.basic,
    this.offlineCompatible = true,
    this.fields = const [],
  }) : assert(
         !required || enabled,
         'A section cannot be required while disabled.',
       );

  /// True when this section should actually be drawn: enabled AND visible.
  bool get shouldRender => enabled && visible;

  /// Visible fields in declared order — for the product table these are the
  /// columns to draw.
  List<InvoiceFieldConfig> get visibleFields =>
      fields.where((f) => f.enabled && f.visible).toList(growable: false);

  InvoiceSectionConfig copyWith({
    int? order,
    bool? enabled,
    bool? required,
    bool? visible,
    bool? editable,
    bool? businessTypeSpecific,
    SubscriptionTier? subscriptionTier,
    bool? offlineCompatible,
    List<InvoiceFieldConfig>? fields,
  }) {
    return InvoiceSectionConfig(
      section: section,
      order: order ?? this.order,
      enabled: enabled ?? this.enabled,
      required: required ?? this.required,
      visible: visible ?? this.visible,
      editable: editable ?? this.editable,
      businessTypeSpecific: businessTypeSpecific ?? this.businessTypeSpecific,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      offlineCompatible: offlineCompatible ?? this.offlineCompatible,
      fields: fields ?? this.fields,
    );
  }

  Map<String, dynamic> toJson() => {
    'section': section.name,
    'order': order,
    'enabled': enabled,
    'required': required,
    'visible': visible,
    'editable': editable,
    'businessTypeSpecific': businessTypeSpecific,
    'subscriptionTier': subscriptionTier.name,
    'offlineCompatible': offlineCompatible,
    'fields': fields.map((f) => f.toJson()).toList(),
  };

  factory InvoiceSectionConfig.fromJson(Map<String, dynamic> json) {
    return InvoiceSectionConfig(
      section: InvoiceSection.values.byName(json['section'] as String),
      order: json['order'] as int? ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      required: json['required'] as bool? ?? false,
      visible: json['visible'] as bool? ?? true,
      editable: json['editable'] as bool? ?? true,
      businessTypeSpecific: json['businessTypeSpecific'] as bool? ?? false,
      subscriptionTier: SubscriptionTier.values.byName(
        json['subscriptionTier'] as String? ?? 'basic',
      ),
      offlineCompatible: json['offlineCompatible'] as bool? ?? true,
      fields: (json['fields'] as List<dynamic>? ?? const [])
          .map((f) => InvoiceFieldConfig.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }
}
