import 'package:dukanx/core/subscription/subscription_tier.dart';
import 'package:dukanx/features/invoice/universal/config/invoice_field_config.dart';
import 'package:dukanx/features/invoice/universal/config/invoice_layout_config.dart';
import 'package:dukanx/features/invoice/universal/config/invoice_section.dart';
import 'package:dukanx/features/invoice/universal/config/invoice_section_config.dart';
import 'package:dukanx/features/invoice/universal/config/universal_invoice_presets.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InvoiceFieldConfig JSON + copyWith', () {
    test('round-trips through JSON', () {
      const f = InvoiceFieldConfig(
        key: 'serialNo',
        label: 'IMEI',
        enabled: true,
        required: true,
        visible: true,
        editable: false,
      );
      final j = f.toJson();
      final back = InvoiceFieldConfig.fromJson(j);
      expect(back.key, 'serialNo');
      expect(back.label, 'IMEI');
      expect(back.required, isTrue);
      expect(back.editable, isFalse);
    });

    test('copyWith overrides selected fields, keeps key', () {
      const f = InvoiceFieldConfig(key: 'hsn', label: 'HSN');
      final c = f.copyWith(visible: false, label: 'HSN Code');
      expect(c.key, 'hsn');
      expect(c.label, 'HSN Code');
      expect(c.visible, isFalse);
    });

    test('fromJson tolerates missing optional keys', () {
      final back = InvoiceFieldConfig.fromJson({'key': 'qty'});
      expect(back.label, 'qty');
      expect(back.enabled, isTrue);
    });
  });

  group('InvoiceSectionConfig JSON + copyWith + helpers', () {
    test('round-trips through JSON incl. tier + fields', () {
      const s = InvoiceSectionConfig(
        section: InvoiceSection.tax,
        order: 3,
        required: true,
        editable: false,
        subscriptionTier: SubscriptionTier.premium,
        fields: [InvoiceFieldConfig(key: 'gst', label: 'GST%')],
      );
      final back = InvoiceSectionConfig.fromJson(s.toJson());
      expect(back.section, InvoiceSection.tax);
      expect(back.order, 3);
      expect(back.required, isTrue);
      expect(back.subscriptionTier, SubscriptionTier.premium);
      expect(back.fields.single.key, 'gst');
    });

    test('shouldRender = enabled && visible', () {
      const on = InvoiceSectionConfig(section: InvoiceSection.qr, order: 0);
      const off = InvoiceSectionConfig(
        section: InvoiceSection.qr,
        order: 0,
        visible: false,
      );
      expect(on.shouldRender, isTrue);
      expect(off.shouldRender, isFalse);
    });

    test('visibleFields filters disabled/invisible', () {
      const s = InvoiceSectionConfig(
        section: InvoiceSection.productTable,
        order: 0,
        fields: [
          InvoiceFieldConfig(key: 'name', label: 'Item'),
          InvoiceFieldConfig(key: 'hsn', label: 'HSN', visible: false),
          InvoiceFieldConfig(key: 'x', label: 'X', enabled: false),
        ],
      );
      expect(s.visibleFields.map((f) => f.key), ['name']);
    });

    test('copyWith changes order + enabled', () {
      const s = InvoiceSectionConfig(section: InvoiceSection.notes, order: 1);
      final c = s.copyWith(order: 9, enabled: false, visible: false);
      expect(c.order, 9);
      expect(c.enabled, isFalse);
      expect(c.section, InvoiceSection.notes);
    });
  });

  group('InvoiceLayoutConfig JSON + overrides + ordering', () {
    test('round-trips a full preset through JSON', () {
      final cfg = UniversalInvoicePresets.forType(BusinessType.mobileShop);
      final back = InvoiceLayoutConfig.fromJson(cfg.toJson());
      expect(back.businessType, BusinessType.mobileShop);
      expect(back.schemaVersion, cfg.schemaVersion);
      expect(back.sections.length, cfg.sections.length);
    });

    test('orderedSections sorts by order; renderableSections filters', () {
      final cfg = UniversalInvoicePresets.forType(BusinessType.grocery);
      final ordered = cfg.orderedSections;
      for (var i = 1; i < ordered.length; i++) {
        expect(ordered[i].order >= ordered[i - 1].order, isTrue);
      }
      // renderable excludes disabled bankDetails
      expect(
        cfg.renderableSections.any(
          (s) => s.section == InvoiceSection.bankDetails,
        ),
        isFalse,
      );
    });

    test('withOverrides replaces a section, preserves the rest', () {
      final cfg = UniversalInvoicePresets.forType(BusinessType.grocery);
      final terms = cfg.sectionFor(InvoiceSection.terms)!;
      final hidden = terms.copyWith(enabled: false, visible: false);
      final updated = cfg.withOverrides({InvoiceSection.terms: hidden});
      expect(updated.sectionFor(InvoiceSection.terms)!.visible, isFalse);
      // untouched section unchanged
      expect(updated.sectionFor(InvoiceSection.productTable)!.enabled, isTrue);
      // empty overrides returns same instance
      expect(identical(cfg.withOverrides(const {}), cfg), isTrue);
    });

    test('sectionFor returns null for absent section', () {
      const cfg = InvoiceLayoutConfig(
        businessType: BusinessType.other,
        sections: [],
      );
      expect(cfg.sectionFor(InvoiceSection.tax), isNull);
    });
  });
}
