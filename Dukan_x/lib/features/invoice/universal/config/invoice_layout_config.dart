import '../../../../models/business_type.dart';
import 'invoice_section.dart';
import 'invoice_section_config.dart';

/// The complete, ordered set of section configs the rendering engine consumes.
///
/// A [InvoiceLayoutConfig] is produced from a per-business default (see
/// [UniversalInvoicePresets]) and may then have tenant overrides merged on top
/// (Phase 6 Settings Panel). The engine renders sections purely from this data.
class InvoiceLayoutConfig {
  /// Current schema version for the config-driven engine. Legacy PDF path uses
  /// [EnhancedInvoiceConfig.version] == 2; this engine is version 3, allowing a
  /// clean feature-flagged rollback to the legacy renderer.
  static const int currentSchemaVersion = 3;

  final BusinessType businessType;
  final int schemaVersion;
  final List<InvoiceSectionConfig> sections;

  const InvoiceLayoutConfig({
    required this.businessType,
    this.schemaVersion = currentSchemaVersion,
    required this.sections,
  });

  /// Sections that should actually render (enabled && visible), sorted by order.
  List<InvoiceSectionConfig> get renderableSections {
    final list = sections.where((s) => s.shouldRender).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// All sections sorted by order (regardless of visibility). Used by the
  /// Settings Panel (Phase 6).
  List<InvoiceSectionConfig> get orderedSections {
    final list = [...sections]..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  InvoiceSectionConfig? sectionFor(InvoiceSection section) {
    for (final s in sections) {
      if (s.section == section) return s;
    }
    return null;
  }

  /// Merge tenant overrides (by [InvoiceSection]) on top of this config. Only
  /// the overridden sections are replaced; ordering and others are preserved.
  InvoiceLayoutConfig withOverrides(
    Map<InvoiceSection, InvoiceSectionConfig> overrides,
  ) {
    if (overrides.isEmpty) return this;
    final merged = sections
        .map((s) => overrides[s.section] ?? s)
        .toList(growable: false);
    return InvoiceLayoutConfig(
      businessType: businessType,
      schemaVersion: schemaVersion,
      sections: merged,
    );
  }

  Map<String, dynamic> toJson() => {
    'businessType': businessType.name,
    'schemaVersion': schemaVersion,
    'sections': sections.map((s) => s.toJson()).toList(),
  };

  factory InvoiceLayoutConfig.fromJson(Map<String, dynamic> json) {
    return InvoiceLayoutConfig(
      businessType: BusinessType.values.byName(json['businessType'] as String),
      schemaVersion: json['schemaVersion'] as int? ?? currentSchemaVersion,
      sections: (json['sections'] as List<dynamic>? ?? const [])
          .map((s) => InvoiceSectionConfig.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
