/// Field-level configuration nested inside an [InvoiceSectionConfig].
///
/// A field maps to a property on the invoice data (via [key]) and controls how
/// that property participates in the section — most importantly, for the
/// product table, the ordered set of visible fields defines the columns.
///
/// The four behavioral flags mirror the section-level flags so that individual
/// fields can be toggled or made mandatory independently of their section.
class InvoiceFieldConfig {
  /// Property key that maps to the invoice data (e.g. 'serialNo', 'hsn').
  final String key;

  /// Display label (localizable). For product-table fields this is the column
  /// header — e.g. the same 'serialNo' key is labelled 'IMEI' for a mobile
  /// shop and 'Serial No' for a computer store.
  final String label;

  final bool enabled;
  final bool required;
  final bool visible;
  final bool editable;

  const InvoiceFieldConfig({
    required this.key,
    required this.label,
    this.enabled = true,
    this.required = false,
    this.visible = true,
    this.editable = true,
  }) : assert(
         !required || enabled,
         'A field cannot be required while disabled (key: not-checked-at-runtime)',
       );

  InvoiceFieldConfig copyWith({
    String? label,
    bool? enabled,
    bool? required,
    bool? visible,
    bool? editable,
  }) {
    return InvoiceFieldConfig(
      key: key,
      label: label ?? this.label,
      enabled: enabled ?? this.enabled,
      required: required ?? this.required,
      visible: visible ?? this.visible,
      editable: editable ?? this.editable,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'enabled': enabled,
    'required': required,
    'visible': visible,
    'editable': editable,
  };

  factory InvoiceFieldConfig.fromJson(Map<String, dynamic> json) {
    return InvoiceFieldConfig(
      key: json['key'] as String,
      label: json['label'] as String? ?? json['key'] as String,
      enabled: json['enabled'] as bool? ?? true,
      required: json['required'] as bool? ?? false,
      visible: json['visible'] as bool? ?? true,
      editable: json['editable'] as bool? ?? true,
    );
  }
}
