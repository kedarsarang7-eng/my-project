// AUDIT_SYSTEM — SHARED VALUE TYPES
//
// Plain, dependency-free value types reused across the Audit_System governance
// core (target selection, scope guard, enumeration, advance decision, ...).
//
// These types depend on NOTHING but `dart:core`, so they import cleanly into
// `flutter_test` + `dartproptest` suites exactly as `tool/responsive_audit.dart`
// does today. Keep this file pure: no Flutter, no I/O.
//
// Part of: per-screen-business-type-audit-remediation (Tasks 1, 2.1)
// _Requirements: 1.8, 2.2_

/// The single module folder name that is NEVER a selectable Business_Type.
/// Excluded at every enumeration/selection boundary (Req 1.4, 1.5).
const String kTemplateModule = '_template';

/// A reference to a single Screen within a Business_Type.
///
/// A Screen is identified by its forward-slash, package-relative `.dart` file
/// path; a Business_Type by its module folder name under `lib/modules/`
/// (never `_template`). This is the single source of truth for screen identity
/// (design "Single source of truth for screen identity").
class ScreenRef implements Comparable<ScreenRef> {
  ScreenRef({required this.businessType, required this.screenPath});

  /// Module folder name under `lib/modules/`, never `_template`.
  final String businessType;

  /// Forward-slash, package-relative path ending in `.dart`.
  final String screenPath;

  @override
  bool operator ==(Object other) =>
      other is ScreenRef &&
      other.businessType == businessType &&
      other.screenPath == screenPath;

  @override
  int get hashCode => Object.hash(businessType, screenPath);

  @override
  int compareTo(ScreenRef other) {
    final byType = businessType.compareTo(other.businessType);
    if (byType != 0) return byType;
    return screenPath.compareTo(other.screenPath);
  }

  @override
  String toString() => 'ScreenRef($businessType, $screenPath)';

  Map<String, Object?> toJson() => <String, Object?>{
    'businessType': businessType,
    'screenPath': screenPath,
  };

  static ScreenRef fromJson(Map<String, Object?> json) => ScreenRef(
    businessType: json['businessType'] as String,
    screenPath: json['screenPath'] as String,
  );
}

/// The single (Business_Type, Screen) pair selected for the current Iteration
/// (Req 1.1). Status is tracked by the Iteration State Machine against the
/// target rather than embedded here, keeping this value type decoupled from the
/// status enum so selection/scope/advance logic stays dependency-light.
class IterationTarget implements Comparable<IterationTarget> {
  IterationTarget({required this.businessType, required this.screenPath});

  /// Module folder under `lib/modules/`, never `_template`.
  final String businessType;

  /// Forward-slash, package-relative `.dart` path of the Screen.
  final String screenPath;

  /// The (businessType, screen) pair this target represents.
  ScreenRef get screenRef =>
      ScreenRef(businessType: businessType, screenPath: screenPath);

  @override
  bool operator ==(Object other) =>
      other is IterationTarget &&
      other.businessType == businessType &&
      other.screenPath == screenPath;

  @override
  int get hashCode => Object.hash(businessType, screenPath);

  @override
  int compareTo(IterationTarget other) {
    final byType = businessType.compareTo(other.businessType);
    if (byType != 0) return byType;
    return screenPath.compareTo(other.screenPath);
  }

  @override
  String toString() => 'IterationTarget($businessType, $screenPath)';

  Map<String, Object?> toJson() => <String, Object?>{
    'businessType': businessType,
    'screenPath': screenPath,
  };

  static IterationTarget fromJson(Map<String, Object?> json) => IterationTarget(
    businessType: json['businessType'] as String,
    screenPath: json['screenPath'] as String,
  );
}

/// An audit or fix activity proposed against a (Business_Type, Screen). Used by
/// the scope guard to reject anything outside the active Iteration_Target
/// (Req 1.2).
class Activity {
  Activity({
    required this.businessType,
    required this.screenPath,
    this.description,
  });

  final String businessType;
  final String screenPath;

  /// Optional human-readable note describing the activity.
  final String? description;

  @override
  String toString() =>
      'Activity($businessType, $screenPath${description == null ? '' : ', $description'})';
}

/// The enumerated universe of selectable (Business_Type, Screen) pairs.
///
/// Built by the Screen Enumerator from `lib/modules/`, with `_template`
/// excluded. Used by the Target Selector to validate that a proposed target
/// exists (Req 1.5) and by the Completed Registry / Advance Decision to decide
/// when every Screen of every non-template Business_Type is done (Req 16.1).
class ScreenUniverse {
  ScreenUniverse(Map<String, List<ScreenRef>> byBusinessType)
    : _byBusinessType = _freeze(byBusinessType);

  /// Empty universe — convenient default for callers building incrementally.
  ScreenUniverse.empty() : _byBusinessType = const <String, List<ScreenRef>>{};

  final Map<String, List<ScreenRef>> _byBusinessType;

  static Map<String, List<ScreenRef>> _freeze(
    Map<String, List<ScreenRef>> input,
  ) {
    final out = <String, List<ScreenRef>>{};
    for (final entry in input.entries) {
      // Defensive: never let the template module into the universe (Req 1.4).
      if (entry.key == kTemplateModule) continue;
      final sorted = [...entry.value]..sort();
      out[entry.key] = List<ScreenRef>.unmodifiable(sorted);
    }
    return Map<String, List<ScreenRef>>.unmodifiable(out);
  }

  /// All Business_Types in the universe, sorted, never including `_template`.
  List<String> get businessTypes => _byBusinessType.keys.toList()..sort();

  /// True iff [businessType] exists in the universe (and is not `_template`).
  bool hasBusinessType(String businessType) =>
      _byBusinessType.containsKey(businessType);

  /// Screens for [businessType]; empty when the Business_Type is unknown.
  List<ScreenRef> screensFor(String businessType) =>
      _byBusinessType[businessType] ?? const <ScreenRef>[];

  /// True iff [screenPath] exists for [businessType].
  bool hasScreen(String businessType, String screenPath) =>
      screensFor(businessType).any((s) => s.screenPath == screenPath);

  /// Every (Business_Type, Screen) pair across the universe, sorted.
  List<ScreenRef> get allScreens {
    final out = <ScreenRef>[];
    for (final bt in businessTypes) {
      out.addAll(screensFor(bt));
    }
    return out;
  }

  /// Total number of Screens across all Business_Types.
  int get totalScreens =>
      _byBusinessType.values.fold(0, (sum, list) => sum + list.length);

  /// True iff the universe contains zero Business_Types.
  bool get isEmpty => _byBusinessType.isEmpty;
}
