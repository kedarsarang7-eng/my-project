// ============================================================================
// OFFLINE GST ROUTER — routes Offline_Lifetime_Mode bill GST through the
// EXISTING GST engine so cloud/offline parity holds by reuse
// ============================================================================
// Feature: offline-license-activation (Task 13.1)
//
// Requirement 11.2 demands that, for identical inputs, the GST (CGST / SGST /
// IGST) computed when a bill is created in Offline_Lifetime_Mode matches the
// Cloud_Subscription_Mode calculation to within 0.01. The design states this
// plainly: the GST engine is "reused unchanged offline; parity is a property,
// not a reimplementation."
//
// This router is the seam that GUARANTEES that property structurally: it does
// not contain ANY GST arithmetic of its own. It forwards the offline bill's
// line items + place-of-supply inputs straight into the existing
// `GstService.calculateInvoiceGst` — the SAME static engine the cloud path
// (`bills_repository.dart`) already calls. Because both modes call the same
// pure function with the same inputs, their outputs are byte-for-byte identical
// (well within the 0.01 tolerance), so parity is achieved by reuse rather than
// by a parallel offline implementation that could drift.
//
// Design constraints honoured here:
//   * REUSE, DON'T REBUILD. The router only delegates; `gst_service.dart` is
//     untouched. Intra-state → CGST + SGST and inter-state → IGST logic all
//     lives in the existing engine.
//   * SERVICE LAYER ONLY. Pure Dart, no Flutter / IO dependency; injected
//     through the existing `service_locator` (`sl`) and never referenced by the
//     widget tree (zero UI changes).
//
// Author: DukanX Engineering
// ============================================================================

import '../../features/gst/services/gst_service.dart';

/// Routes offline bill GST through the existing [GstService.calculateInvoiceGst]
/// engine so Offline_Lifetime_Mode and Cloud_Subscription_Mode produce
/// identical GST for identical inputs (Requirement 11.2).
///
/// The router is a thin, behaviour-free delegate: every CGST / SGST / IGST and
/// supply-type decision is made by the existing engine. It exists so the
/// offline write path has a single, explicit place that funnels into the same
/// engine the cloud path uses — making the cross-mode parity property
/// (Property 26) hold by construction.
class OfflineGstRouter {
  /// The same default seller state code the cloud path falls back to when GST
  /// settings have no state code (`bills_repository.dart` uses '27' / MH). Kept
  /// here only so offline callers match the cloud fallback exactly.
  static const String defaultStateCode = '27';

  const OfflineGstRouter();

  /// Computes the GST summary for an offline bill by delegating to the existing
  /// [GstService.calculateInvoiceGst] (Requirement 11.2).
  ///
  /// The parameters mirror the existing engine's signature exactly so no input
  /// is reshaped on the way through — identical inputs in both modes yield an
  /// identical [InvoiceGstSummary]. This method intentionally performs NO tax
  /// arithmetic itself.
  ///
  /// * [items] — the bill's line items (taxable value + GST rate per line),
  ///   already prepared as [LineItemForGst] exactly as the cloud path does.
  /// * [sellerStateCode] — the seller's GST state code.
  /// * [customerStateCode] — the customer's GST state code; `null`/empty makes
  ///   the engine treat the supply as intra-state (CGST + SGST).
  /// * [customerGstin] — the customer's GSTIN, used by the engine for B2B/B2C
  ///   classification.
  InvoiceGstSummary calculateBillGst({
    required List<LineItemForGst> items,
    required String sellerStateCode,
    required String? customerStateCode,
    required String? customerGstin,
  }) {
    // Single point of delegation — the SAME engine the cloud path calls.
    return GstService.calculateInvoiceGst(
      items: items,
      sellerStateCode: sellerStateCode,
      customerStateCode: customerStateCode,
      customerGstin: customerGstin,
    );
  }
}
