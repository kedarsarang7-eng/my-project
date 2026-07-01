// Pharmacy — canonical drug-schedule resolver.
//
// The pharmacy vertical historically carried two competing `DrugSchedule`
// enums plus a free-form `BillItem.drugSchedule` string:
//   * `pharmacy_business_rules.dart`  -> {otc, h, h1, x}
//   * `drug_schedule_service.dart`    -> {none, scheduleH, scheduleH1, scheduleX}
//
// That split let scheduled-drug enforcement be bypassed when the string and
// enum disagreed (audit §14). This resolver reconciles every representation
// into a single canonical value so all enforcement logic reads the same
// schedule (Requirements 22.1–22.3, 7.4).

import '../../inventory/services/drug_schedule_service.dart' as inventory;
import 'pharmacy_business_rules.dart' as rules;

/// The single canonical schedule representation used by all scheduled-drug
/// enforcement logic in the pharmacy vertical.
///
/// * [nonScheduled] — OTC / no restriction (also the null/empty default).
/// * [scheduleH], [scheduleH1], [scheduleX] — the regulated schedules that
///   require a prescription before dispensing.
/// * [unrecognized] — a non-empty raw value that matches no known schedule;
///   enforcement must reject the item rather than silently treat it as OTC.
enum CanonicalDrugSchedule {
  nonScheduled,
  scheduleH,
  scheduleH1,
  scheduleX,
  unrecognized,
}

/// Reconciles raw schedule strings and the legacy `DrugSchedule` enums into a
/// single [CanonicalDrugSchedule] value.
class DrugScheduleResolver {
  DrugScheduleResolver._();

  /// Resolve a raw `BillItem.drugSchedule` string to its canonical value.
  ///
  /// Matching is case-insensitive and ignores surrounding/interior whitespace
  /// as well as `-`/`_` separators (Requirement 22.2), so `"H1"`,
  /// `" schedule h1 "`, `"Schedule-H1"`, and `"scheduleH1"` all resolve to
  /// [CanonicalDrugSchedule.scheduleH1].
  ///
  /// * `null` or empty/whitespace-only input -> [CanonicalDrugSchedule.nonScheduled]
  ///   (Requirement 7.4).
  /// * A non-empty value matching nothing -> [CanonicalDrugSchedule.unrecognized]
  ///   (Requirement 22.4).
  static CanonicalDrugSchedule fromRaw(String? raw) {
    if (raw == null) return CanonicalDrugSchedule.nonScheduled;

    // Normalize: trim, lowercase, and strip spaces and separator characters so
    // every spelling collapses to a single comparable token.
    final normalized = raw.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');

    if (normalized.isEmpty) return CanonicalDrugSchedule.nonScheduled;

    switch (normalized) {
      case 'otc':
      case 'none':
      case 'nonscheduled':
        return CanonicalDrugSchedule.nonScheduled;
      case 'h':
      case 'scheduleh':
        return CanonicalDrugSchedule.scheduleH;
      case 'h1':
      case 'scheduleh1':
        return CanonicalDrugSchedule.scheduleH1;
      case 'x':
      case 'schedulex':
        return CanonicalDrugSchedule.scheduleX;
      default:
        return CanonicalDrugSchedule.unrecognized;
    }
  }

  /// Map the legacy `pharmacy_business_rules.dart` `DrugSchedule` enum
  /// ({otc, h, h1, x}) to its canonical value.
  static CanonicalDrugSchedule fromBusinessRules(rules.DrugSchedule schedule) {
    switch (schedule) {
      case rules.DrugSchedule.otc:
        return CanonicalDrugSchedule.nonScheduled;
      case rules.DrugSchedule.h:
        return CanonicalDrugSchedule.scheduleH;
      case rules.DrugSchedule.h1:
        return CanonicalDrugSchedule.scheduleH1;
      case rules.DrugSchedule.x:
        return CanonicalDrugSchedule.scheduleX;
    }
  }

  /// Map the legacy `drug_schedule_service.dart` `DrugSchedule` enum
  /// ({none, scheduleH, scheduleH1, scheduleX}) to its canonical value.
  static CanonicalDrugSchedule fromInventory(inventory.DrugSchedule schedule) {
    switch (schedule) {
      case inventory.DrugSchedule.none:
        return CanonicalDrugSchedule.nonScheduled;
      case inventory.DrugSchedule.scheduleH:
        return CanonicalDrugSchedule.scheduleH;
      case inventory.DrugSchedule.scheduleH1:
        return CanonicalDrugSchedule.scheduleH1;
      case inventory.DrugSchedule.scheduleX:
        return CanonicalDrugSchedule.scheduleX;
    }
  }

  /// True for the regulated schedules H, H1, and X — i.e. the schedules that
  /// require a prescription before dispensing. [CanonicalDrugSchedule.unrecognized]
  /// is NOT scheduled here; callers must handle it as an explicit error per
  /// Requirement 22.4 rather than dispensing it as a scheduled drug.
  static bool isScheduled(CanonicalDrugSchedule schedule) {
    return schedule == CanonicalDrugSchedule.scheduleH ||
        schedule == CanonicalDrugSchedule.scheduleH1 ||
        schedule == CanonicalDrugSchedule.scheduleX;
  }
}
