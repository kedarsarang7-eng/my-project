import '../../../../core/subscription/subscription_tier.dart';
import '../../../../models/business_type.dart';
import 'invoice_field_config.dart';
import 'invoice_layout_config.dart';
import 'invoice_section.dart';
import 'invoice_section_config.dart';

/// Default [InvoiceLayoutConfig]s per business type.
///
/// PHASE 2 SCOPE: only the 3 pilot business types are wired — Grocery Store,
/// Mobile Shop, and Wholesale Distributor. The remaining universal types are
/// wired in Phase 3 into this SAME registry (no new template files). Requesting
/// an unwired type throws [UnimplementedError] so scope is explicit and
/// testable.
class UniversalInvoicePresets {
  /// The 9 universal business types wired into the ONE universal engine.
  /// Phase 2 wired the first 3 pilots; Phase 3 added the remaining 6. The 3
  /// dedicated templates (Pharmacy, Restaurant, Jewellery) are Phase 4 and are
  /// intentionally NOT part of the universal engine.
  static const Set<BusinessType> wiredTypes = {
    // Phase 2 pilots
    BusinessType.grocery,
    BusinessType.mobileShop,
    BusinessType.wholesale,
    // Phase 3
    BusinessType.computerShop,
    BusinessType.electronics,
    BusinessType.bookStore,
    BusinessType.clothing,
    BusinessType.autoParts,
    BusinessType.hardware,
  };

  static bool isWired(BusinessType type) => wiredTypes.contains(type);

  /// Get the default layout config for [type].
  static InvoiceLayoutConfig forType(BusinessType type) {
    switch (type) {
      // Phase 2 pilots
      case BusinessType.grocery:
        return _grocery();
      case BusinessType.mobileShop:
        return _mobileShop();
      case BusinessType.wholesale:
        return _wholesale();
      // Phase 3
      case BusinessType.computerShop:
        return _computerShop();
      case BusinessType.electronics:
        return _electronics();
      case BusinessType.bookStore:
        return _bookStore();
      case BusinessType.clothing:
        return _clothing();
      case BusinessType.autoParts:
        return _autoParts();
      case BusinessType.hardware:
        return _hardware();
      default:
        throw UnimplementedError(
          'Business type "${type.name}" is not a universal-engine type. '
          'Universal types: ${wiredTypes.map((e) => e.name).join(", ")}. '
          'Pharmacy/Restaurant/Jewellery use dedicated templates (Phase 4).',
        );
    }
  }

  // ── helpers ──
  static InvoiceFieldConfig _f(
    String key,
    String label, {
    bool visible = true,
    bool required = false,
  }) => InvoiceFieldConfig(
    key: key,
    label: label,
    visible: visible,
    required: required,
  );

  // ========================================================================
  // GROCERY STORE (pilot) — simple retail. No serial/IMEI/warranty. HSN
  // present but hidden by default (togglable in Phase 6). Tax optional.
  // ========================================================================
  static InvoiceLayoutConfig _grocery() {
    return InvoiceLayoutConfig(
      businessType: BusinessType.grocery,
      sections: [
        const InvoiceSectionConfig(
          section: InvoiceSection.logo,
          order: 0,
          editable: true,
        ),
        const InvoiceSectionConfig(
          section: InvoiceSection.businessInfo,
          order: 1,
          required: true,
          editable: false,
        ),
        const InvoiceSectionConfig(
          section: InvoiceSection.customerInfo,
          order: 2,
        ),
        InvoiceSectionConfig(
          section: InvoiceSection.productTable,
          order: 3,
          required: true,
          editable: false,
          fields: [
            _f('sno', '#'),
            _f('name', 'Item'),
            _f('hsn', 'HSN', visible: false), // togglable in Phase 6
            _f('qty', 'Qty'),
            _f('unit', 'Unit'),
            _f('rate', 'Rate'),
            _f('discount', 'Discount'),
            _f('amount', 'Amount'),
          ],
        ),
        // Tax optional for grocery (many items 0% / composition dealers).
        const InvoiceSectionConfig(
          section: InvoiceSection.tax,
          order: 4,
          enabled: true,
          visible: false,
        ),
        const InvoiceSectionConfig(section: InvoiceSection.discount, order: 5),
        const InvoiceSectionConfig(section: InvoiceSection.payment, order: 6),
        const InvoiceSectionConfig(
          section: InvoiceSection.qr,
          order: 7,
          offlineCompatible: true,
        ),
        const InvoiceSectionConfig(section: InvoiceSection.terms, order: 8),
        // Present but off by default.
        const InvoiceSectionConfig(
          section: InvoiceSection.bankDetails,
          order: 9,
          enabled: false,
          visible: false,
          subscriptionTier: SubscriptionTier.pro,
        ),
        const InvoiceSectionConfig(
          section: InvoiceSection.signature,
          order: 10,
          enabled: false,
          visible: false,
        ),
        const InvoiceSectionConfig(
          section: InvoiceSection.watermark,
          order: 11,
          enabled: false,
          visible: false,
        ),
      ],
    );
  }

  // ========================================================================
  // MOBILE SHOP (pilot) — IMEI + Warranty mandatory, HSN + GST shown.
  // ========================================================================
  static InvoiceLayoutConfig _mobileShop() {
    return InvoiceLayoutConfig(
      businessType: BusinessType.mobileShop,
      sections: [
        const InvoiceSectionConfig(section: InvoiceSection.logo, order: 0),
        const InvoiceSectionConfig(
          section: InvoiceSection.businessInfo,
          order: 1,
          required: true,
          editable: false,
        ),
        const InvoiceSectionConfig(
          section: InvoiceSection.customerInfo,
          order: 2,
        ),
        InvoiceSectionConfig(
          section: InvoiceSection.productTable,
          order: 3,
          required: true,
          editable: false,
          fields: [
            _f('sno', '#'),
            _f('name', 'Product'),
            _f('serialNo', 'IMEI', required: true), // labelled IMEI here
            _f('warranty', 'Warranty', required: true),
            _f('hsn', 'HSN'),
            _f('qty', 'Qty'),
            _f('rate', 'MRP'),
            _f('gst', 'GST%'),
            _f('amount', 'Amount'),
          ],
        ),
        const InvoiceSectionConfig(
          section: InvoiceSection.tax,
          order: 4,
          required: true,
          editable: false,
        ),
        const InvoiceSectionConfig(section: InvoiceSection.discount, order: 5),
        const InvoiceSectionConfig(section: InvoiceSection.payment, order: 6),
        // IMEI recorded => warranty traceability note.
        const InvoiceSectionConfig(
          section: InvoiceSection.serialImei,
          order: 7,
          required: true,
          businessTypeSpecific: true,
        ),
        const InvoiceSectionConfig(
          section: InvoiceSection.warranty,
          order: 8,
          businessTypeSpecific: true,
        ),
        const InvoiceSectionConfig(section: InvoiceSection.qr, order: 9),
        const InvoiceSectionConfig(section: InvoiceSection.terms, order: 10),
        const InvoiceSectionConfig(
          section: InvoiceSection.signature,
          order: 11,
        ),
        const InvoiceSectionConfig(
          section: InvoiceSection.watermark,
          order: 12,
          enabled: false,
          visible: false,
        ),
      ],
    );
  }

  // ========================================================================
  // WHOLESALE DISTRIBUTOR (pilot) — B2B: shipping/dispatch + bank details +
  // GST + terms mandatory. No serial/warranty. Bulk quantities.
  // ========================================================================
  static InvoiceLayoutConfig _wholesale() => _build(
    type: BusinessType.wholesale,
    columns: [
      _f('sno', '#'),
      _f('name', 'Item'),
      _f('hsn', 'HSN', required: true),
      _f('qty', 'Qty'),
      _f('unit', 'Unit'),
      _f('rate', 'Rate'),
      _f('gst', 'GST%'),
      _f('amount', 'Amount'),
    ],
    customerRequired: true,
    shipping: true,
    shippingRequired: true,
    bankDetails: true,
    bankRequired: true,
    notes: true,
    termsRequired: true,
    signature: true,
  );

  // ========================================================================
  // PHASE 3 — remaining 6 universal types, expressed as DATA on the SAME
  // engine. A shared builder composes the common section skeleton; only the
  // product-table columns and a few flags differ per business type.
  // ========================================================================

  /// Compose a standard universal layout. Sections common to all universal
  /// types are built here; per-type variation is passed in as flags/columns.
  static InvoiceLayoutConfig _build({
    required BusinessType type,
    required List<InvoiceFieldConfig> columns,
    bool customerRequired = false,
    bool shipping = false,
    bool shippingRequired = false,
    bool taxVisible = true,
    bool taxRequired = true,
    bool warrantySection = false,
    bool serialImeiSection = false,
    bool bankDetails = false,
    bool bankRequired = false,
    bool notes = false,
    bool termsRequired = false,
    bool signature = false,
  }) {
    var order = 0;
    final sections = <InvoiceSectionConfig>[
      InvoiceSectionConfig(section: InvoiceSection.logo, order: order++),
      InvoiceSectionConfig(
        section: InvoiceSection.businessInfo,
        order: order++,
        required: true,
        editable: false,
      ),
      InvoiceSectionConfig(
        section: InvoiceSection.customerInfo,
        order: order++,
        required: customerRequired,
      ),
    ];

    if (shipping) {
      sections.add(
        InvoiceSectionConfig(
          section: InvoiceSection.shipping,
          order: order++,
          required: shippingRequired,
          businessTypeSpecific: true,
        ),
      );
    }

    sections.add(
      InvoiceSectionConfig(
        section: InvoiceSection.productTable,
        order: order++,
        required: true,
        editable: false,
        fields: columns,
      ),
    );

    sections.add(
      InvoiceSectionConfig(
        section: InvoiceSection.tax,
        order: order++,
        enabled: true,
        visible: taxVisible,
        required: taxRequired && taxVisible,
        // GST bills lock the tax section; optional-tax businesses can toggle.
        editable: !taxRequired,
      ),
    );

    sections.add(
      InvoiceSectionConfig(section: InvoiceSection.discount, order: order++),
    );
    sections.add(
      InvoiceSectionConfig(section: InvoiceSection.payment, order: order++),
    );

    if (bankDetails) {
      sections.add(
        InvoiceSectionConfig(
          section: InvoiceSection.bankDetails,
          order: order++,
          required: bankRequired,
        ),
      );
    }
    if (serialImeiSection) {
      sections.add(
        InvoiceSectionConfig(
          section: InvoiceSection.serialImei,
          order: order++,
          businessTypeSpecific: true,
        ),
      );
    }
    if (warrantySection) {
      sections.add(
        InvoiceSectionConfig(
          section: InvoiceSection.warranty,
          order: order++,
          businessTypeSpecific: true,
        ),
      );
    }
    if (notes) {
      sections.add(
        InvoiceSectionConfig(section: InvoiceSection.notes, order: order++),
      );
    }

    sections.add(
      InvoiceSectionConfig(
        section: InvoiceSection.terms,
        order: order++,
        required: termsRequired,
      ),
    );
    sections.add(
      InvoiceSectionConfig(section: InvoiceSection.qr, order: order++),
    );

    if (signature) {
      sections.add(
        InvoiceSectionConfig(section: InvoiceSection.signature, order: order++),
      );
    }

    sections.add(
      InvoiceSectionConfig(
        section: InvoiceSection.watermark,
        order: order++,
        enabled: false,
        visible: false,
      ),
    );

    return InvoiceLayoutConfig(businessType: type, sections: sections);
  }

  // Computer Store — Serial + Warranty(required) + HSN + GST.
  static InvoiceLayoutConfig _computerShop() => _build(
    type: BusinessType.computerShop,
    columns: [
      _f('sno', '#'),
      _f('name', 'Product'),
      _f('serialNo', 'Serial No'),
      _f('warranty', 'Warranty', required: true),
      _f('hsn', 'HSN'),
      _f('qty', 'Qty'),
      _f('rate', 'Rate'),
      _f('gst', 'GST%'),
      _f('amount', 'Amount'),
    ],
    warrantySection: true,
    serialImeiSection: true,
    signature: true,
  );

  // Electronics Store — Serial + Warranty + HSN + GST (IMEI optional/off).
  static InvoiceLayoutConfig _electronics() => _build(
    type: BusinessType.electronics,
    columns: [
      _f('sno', '#'),
      _f('name', 'Product'),
      _f('serialNo', 'Serial No'),
      _f('warranty', 'Warranty'),
      _f('hsn', 'HSN'),
      _f('qty', 'Qty'),
      _f('rate', 'MRP'),
      _f('gst', 'GST%'),
      _f('amount', 'Amount'),
    ],
    warrantySection: true,
    serialImeiSection: true,
    signature: true,
  );

  // Book Store — simple; ISBN visible, tax optional (many books 0% GST).
  static InvoiceLayoutConfig _bookStore() => _build(
    type: BusinessType.bookStore,
    columns: [
      _f('sno', '#'),
      _f('name', 'Title'),
      _f('isbn', 'ISBN'),
      _f('hsn', 'HSN', visible: false),
      _f('qty', 'Qty'),
      _f('rate', 'Rate'),
      _f('discount', 'Discount'),
      _f('amount', 'Amount'),
    ],
    taxVisible: false,
    taxRequired: false,
  );

  // Clothing Store — Size + Color, discount emphasised, exchange terms.
  static InvoiceLayoutConfig _clothing() => _build(
    type: BusinessType.clothing,
    columns: [
      _f('sno', '#'),
      _f('name', 'Item'),
      _f('size', 'Size'),
      _f('color', 'Color'),
      _f('qty', 'Qty'),
      _f('rate', 'Price'),
      _f('discount', 'Discount'),
      _f('amount', 'Amount'),
    ],
  );

  // Auto Parts Store — Part No + Warranty + HSN + GST. IMEI disabled.
  static InvoiceLayoutConfig _autoParts() => _build(
    type: BusinessType.autoParts,
    columns: [
      _f('sno', '#'),
      _f('name', 'Part'),
      _f('partNumber', 'Part No'),
      _f('warranty', 'Warranty'),
      _f('hsn', 'HSN'),
      _f('qty', 'Qty'),
      _f('rate', 'Rate'),
      _f('gst', 'GST%'),
      _f('amount', 'Amount'),
    ],
    warrantySection: true,
    signature: true,
  );

  // Hardware Store — HSN(required) + Unit; goods-not-returnable terms.
  static InvoiceLayoutConfig _hardware() => _build(
    type: BusinessType.hardware,
    columns: [
      _f('sno', '#'),
      _f('name', 'Item'),
      _f('hsn', 'HSN', required: true),
      _f('qty', 'Qty'),
      _f('unit', 'Unit'),
      _f('rate', 'Rate'),
      _f('gst', 'GST%'),
      _f('amount', 'Amount'),
    ],
    termsRequired: true,
  );
}
