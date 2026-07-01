// ============================================================================
// PHARMACY GST RESOLVER — per-item / per-schedule (HSN) GST mapping
// ============================================================================
// Replaces the single fixed `defaultGstRate: 12%` reliance for the pharmacy
// vertical with a schedule/HSN → GST-rate mapping that supports the statutory
// medicine slabs {0, 5, 12, 18, 28}% (Requirement 11.1).
//
// Resolution rules (Requirements 11.2–11.4):
//   * If the item's HSN code matches an entry in the mapping, apply that rate.
//   * Else if the item's schedule matches an entry in the schedule overlay,
//     apply that rate.
//   * Otherwise (unmatched / null / empty / out-of-range) apply the 12%
//     fallback and flag `usedFallback = true` so the caller can record that the
//     fallback was applied for that item.
//
// GST amount is computed in INTEGER PAISE with round-half-up via the shared
// `Paise` helper (Requirement 11.5), so MRP, GST, and credit-note math all
// agree on a single rounding rule.
//
// This resolver is PHARMACY-SCOPED. It does NOT modify the shared
// `business_type_config.dart` `defaultGstRate` used by the other 18 verticals
// (Requirement 5.3): those code paths keep computing GST exactly as before.
//
// Validates: Requirements 11.1, 11.2, 11.3, 11.4, 11.5.
// ============================================================================

import '../../utils/hsn_to_gst_rate_map.dart' show HSN_TO_GST_RATE;
import 'paise.dart';

/// The outcome of resolving a GST rate for a pharmacy line item.
///
/// * [ratePercent] — the GST rate to apply, always one of {0, 5, 12, 18, 28}.
/// * [usedFallback] — `true` when no schedule/HSN entry matched and the 12%
///   fallback was applied (Requirements 11.3, 11.4). Callers persist/record
///   this flag so fallback-taxed items are auditable.
class GstResolution {
  /// The resolved GST rate as a whole-number percentage.
  final int ratePercent;

  /// Whether the 12% fallback rate was used because nothing matched.
  final bool usedFallback;

  const GstResolution({required this.ratePercent, required this.usedFallback});

  @override
  bool operator ==(Object other) =>
      other is GstResolution &&
      other.ratePercent == ratePercent &&
      other.usedFallback == usedFallback;

  @override
  int get hashCode => Object.hash(ratePercent, usedFallback);

  @override
  String toString() =>
      'GstResolution(ratePercent: $ratePercent, usedFallback: $usedFallback)';
}

/// Resolves the GST rate for a pharmacy line item from its HSN code and/or
/// drug schedule, and computes the GST amount in integer paise.
///
/// The mappings are config-backed and injectable so the statutory slabs can be
/// adjusted (e.g. by a government notification) without touching call sites:
///
/// ```dart
/// final resolver = PharmacyGstResolver();                 // default slabs
/// final resolver = PharmacyGstResolver(                   // custom config
///   hsnOverlay: {'3004': 12},
///   scheduleOverlay: {'h': 12},
/// );
/// ```
class PharmacyGstResolver {
  /// The fallback GST rate applied when no schedule/HSN entry matches, or when
  /// the schedule/HSN value is null/empty/missing (Requirements 11.3, 11.4).
  static const int fallbackRatePercent = 12;

  /// The statutory GST slabs the pharmacy mapping is allowed to resolve to
  /// (Requirement 11.1). A mapping entry resolving outside this set is treated
  /// as no match so the fallback applies, keeping the output well-formed.
  static const Set<int> supportedRates = <int>{0, 5, 12, 18, 28};

  /// Default pharmacy HSN → GST overlay for common medicine/pharma codes.
  ///
  /// This overlay takes precedence over the shared `HSN_TO_GST_RATE` table so
  /// the messy multi-rate entries in that table (slab duplicates) cannot leak
  /// an incorrect medicine rate into the pharmacy vertical.
  static const Map<String, int> _defaultHsnOverlay = <String, int>{
    // 5% — life-saving / specified drugs and formulations.
    '3002': 5, // Human/animal blood, vaccines, antisera (life-saving slab)
    '3001': 5, // Glands and organs for therapeutic uses
    // 12% — standard medicine slab.
    '3003': 12, // Medicaments — bulk (two or more constituents)
    '3004': 12, // Medicaments — retail (most common medicine code)
    '3006': 12, // Pharmaceutical goods (sutures, dressings, kits)
    '3005': 12, // Wadding, gauze, bandages and similar dressings
    // 18% — non-medicine pharmacy/personal-care lines.
    '3401': 18, // Medicated soaps / toilet preparations
    '3306': 18, // Oral / dental hygiene preparations
    '9018': 12, // Medical / surgical instruments and appliances
  };

  /// Default schedule → GST overlay. Schedule classification (H/H1/X) is a
  /// regulatory control rather than a tax determinant, so by default scheduled
  /// medicines resolve to the standard 12% medicine slab. Provided as a
  /// configurable hook for tenants whose schedule maps to a specific slab.
  static const Map<String, int> _defaultScheduleOverlay = <String, int>{
    'otc': 12,
    'h': 12,
    'h1': 12,
    'x': 12,
  };

  final Map<String, int> _hsnOverlay;
  final Map<String, int> _scheduleOverlay;

  /// Creates a resolver. [hsnOverlay] and [scheduleOverlay] default to the
  /// built-in pharmacy slabs but can be overridden for configuration/tests.
  PharmacyGstResolver({
    Map<String, int>? hsnOverlay,
    Map<String, int>? scheduleOverlay,
  }) : _hsnOverlay = hsnOverlay ?? _defaultHsnOverlay,
       _scheduleOverlay = scheduleOverlay ?? _defaultScheduleOverlay;

  /// Resolve the GST rate for a pharmacy line item.
  ///
  /// Precedence: HSN match (statutory code, most specific) → schedule match →
  /// 12% fallback. A null/empty/whitespace value for both inputs, or a value
  /// that matches nothing (or maps outside [supportedRates]), yields the
  /// fallback with `usedFallback = true` (Requirements 11.2–11.4).
  GstResolution resolve({String? hsn, String? schedule}) {
    // 1. HSN takes precedence — it is the statutory tax code.
    final int? byHsn = _resolveHsn(hsn);
    if (byHsn != null) {
      return GstResolution(ratePercent: byHsn, usedFallback: false);
    }

    // 2. Fall back to the schedule overlay.
    final int? bySchedule = _resolveSchedule(schedule);
    if (bySchedule != null) {
      return GstResolution(ratePercent: bySchedule, usedFallback: false);
    }

    // 3. Nothing matched → 12% fallback, flagged.
    return const GstResolution(
      ratePercent: fallbackRatePercent,
      usedFallback: true,
    );
  }

  /// Compute the GST amount (in integer paise) for a taxable amount, using the
  /// round-half-up rule from [Paise] (Requirement 11.5).
  ///
  /// [taxableAmountPaise] is the line's taxable value in integer paise and
  /// [ratePercent] is the resolved GST rate. The fractional paise result of
  /// `taxable * rate / 100` is rounded half-up to the nearest whole paise.
  int gstAmountPaise({
    required int taxableAmountPaise,
    required int ratePercent,
  }) {
    return Paise.roundHalfUp(taxableAmountPaise * ratePercent / 100);
  }

  /// Convenience: resolve the rate and compute the GST amount in one call.
  /// Returns both the resolution (for recording fallback usage) and the paise
  /// amount.
  ({GstResolution resolution, int gstPaise}) resolveAmount({
    required int taxableAmountPaise,
    String? hsn,
    String? schedule,
  }) {
    final resolution = resolve(hsn: hsn, schedule: schedule);
    final gstPaise = gstAmountPaise(
      taxableAmountPaise: taxableAmountPaise,
      ratePercent: resolution.ratePercent,
    );
    return (resolution: resolution, gstPaise: gstPaise);
  }

  /// Look up an HSN code in the pharmacy overlay first, then the shared
  /// statutory table. Returns `null` when the code is null/empty, unmatched,
  /// or maps to a rate outside [supportedRates].
  int? _resolveHsn(String? hsn) {
    final key = hsn?.trim();
    if (key == null || key.isEmpty) return null;

    final int? overlayRate = _hsnOverlay[key];
    if (overlayRate != null && supportedRates.contains(overlayRate)) {
      return overlayRate;
    }

    final int? sharedRate = HSN_TO_GST_RATE[key];
    if (sharedRate != null && supportedRates.contains(sharedRate)) {
      return sharedRate;
    }

    return null;
  }

  /// Look up a schedule value in the schedule overlay using case-insensitive,
  /// separator-insensitive matching (so "Schedule-H1", " h1 ", "scheduleH1"
  /// all collapse to "h1"). Returns `null` when null/empty or unmatched.
  int? _resolveSchedule(String? schedule) {
    if (schedule == null) return null;
    final normalized = schedule
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_\-]'), '')
        .replaceAll('schedule', '');
    if (normalized.isEmpty) return null;

    final int? rate = _scheduleOverlay[normalized];
    if (rate != null && supportedRates.contains(rate)) {
      return rate;
    }
    return null;
  }
}
