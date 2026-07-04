/// Platform Verification Matrix Builder — accumulates per-platform verification
/// rows and produces the complete matrix for an audit cycle.
///
/// Each row records Light/Dark/Portrait/Landscape cell statuses (Pass/Fail/N/A)
/// for a [TargetPlatform]. The row's `resultPass` is true iff no cell is Fail.
///
/// Desktop platforms (Windows, Linux) automatically receive N/A for orientation
/// cells (portrait/landscape) with reason "Desktop platform does not rotate".
///
/// Requirements: 6.8
library;

import 'dart:io';

import '../models/audit_engine_models.dart';

/// Default N/A reason for desktop platforms that do not support rotation.
const String _desktopRotationNaReason = 'Desktop platform does not rotate';

/// Set of platforms that do not support rotation (portrait/landscape N/A).
const Set<TargetPlatform> _desktopPlatforms = {
  TargetPlatform.windowsDesktop,
  TargetPlatform.linuxDesktop,
};

/// Builds the Platform Verification Matrix one row at a time.
///
/// Usage:
/// ```dart
/// final builder = PlatformMatrixBuilder();
/// builder.addRow(
///   platform: TargetPlatform.windowsDesktop,
///   light: MatrixCell(status: CategoryStatus.pass),
///   dark: MatrixCell(status: CategoryStatus.pass),
/// );
/// builder.addRow(
///   platform: TargetPlatform.iphone,
///   light: MatrixCell(status: CategoryStatus.pass),
///   dark: MatrixCell(status: CategoryStatus.fail),
///   portrait: MatrixCell(status: CategoryStatus.pass),
///   landscape: MatrixCell(status: CategoryStatus.pass),
/// );
/// final matrix = builder.build();
/// ```
class PlatformMatrixBuilder {
  /// Accumulated rows keyed by platform (one row per platform).
  final Map<TargetPlatform, MatrixRow> _rows = {};

  /// Creates a [MatrixRow] for a specific target platform.
  ///
  /// For desktop platforms ([TargetPlatform.windowsDesktop],
  /// [TargetPlatform.linuxDesktop]), the [portrait] and [landscape] cells
  /// default to N/A with reason "Desktop platform does not rotate" if not
  /// explicitly provided.
  ///
  /// Returns the constructed [MatrixRow].
  MatrixRow rowFor(
    TargetPlatform platform, {
    required MatrixCell light,
    required MatrixCell dark,
    MatrixCell? portrait,
    MatrixCell? landscape,
  }) {
    final isDesktop = _desktopPlatforms.contains(platform);

    final effectivePortrait =
        portrait ??
        (isDesktop
            ? const MatrixCell(
                status: CategoryStatus.na,
                reason: _desktopRotationNaReason,
              )
            : const MatrixCell(status: CategoryStatus.pass));

    final effectiveLandscape =
        landscape ??
        (isDesktop
            ? const MatrixCell(
                status: CategoryStatus.na,
                reason: _desktopRotationNaReason,
              )
            : const MatrixCell(status: CategoryStatus.pass));

    return MatrixRow(
      platform: platform,
      light: light,
      dark: dark,
      portrait: effectivePortrait,
      landscape: effectiveLandscape,
    );
  }

  /// Adds a row to the matrix for a specific target platform.
  ///
  /// Uses [rowFor] to construct the row, applying desktop defaults for
  /// portrait/landscape when not provided.
  ///
  /// If a row for this platform already exists, it is replaced with the new one.
  void addRow({
    required TargetPlatform platform,
    required MatrixCell light,
    required MatrixCell dark,
    MatrixCell? portrait,
    MatrixCell? landscape,
  }) {
    final row = rowFor(
      platform,
      light: light,
      dark: dark,
      portrait: portrait,
      landscape: landscape,
    );
    _rows[platform] = row;
  }

  /// Sets individual cell values for a platform incrementally.
  ///
  /// If the platform already has a row, only the provided cells are updated;
  /// unspecified cells retain their existing values. If the platform has no
  /// existing row, missing cells default based on platform type (desktop gets
  /// N/A for orientation, others get Pass).
  void setCell({
    required TargetPlatform platform,
    MatrixCell? light,
    MatrixCell? dark,
    MatrixCell? portrait,
    MatrixCell? landscape,
  }) {
    final existing = _rows[platform];
    final isDesktop = _desktopPlatforms.contains(platform);

    final defaultCell = const MatrixCell(status: CategoryStatus.pass);
    final desktopOrientationDefault = const MatrixCell(
      status: CategoryStatus.na,
      reason: _desktopRotationNaReason,
    );

    final effectiveLight = light ?? existing?.light ?? defaultCell;
    final effectiveDark = dark ?? existing?.dark ?? defaultCell;
    final effectivePortrait =
        portrait ??
        existing?.portrait ??
        (isDesktop ? desktopOrientationDefault : defaultCell);
    final effectiveLandscape =
        landscape ??
        existing?.landscape ??
        (isDesktop ? desktopOrientationDefault : defaultCell);

    _rows[platform] = MatrixRow(
      platform: platform,
      light: effectiveLight,
      dark: effectiveDark,
      portrait: effectivePortrait,
      landscape: effectiveLandscape,
    );
  }

  /// Builds the complete matrix with one row per [TargetPlatform].
  ///
  /// Logs a warning to stderr for any platform in [TargetPlatform.values] that
  /// has no row added. Returns all accumulated rows ordered by
  /// [TargetPlatform.values] declaration order.
  List<MatrixRow> build() {
    // Warn about missing platforms
    for (final platform in TargetPlatform.values) {
      if (!_rows.containsKey(platform)) {
        stderr.writeln(
          '[PlatformMatrixBuilder] WARNING: No row added for '
          '${platform.label}. It will be absent from the matrix.',
        );
      }
    }

    // Return rows in TargetPlatform declaration order
    return TargetPlatform.values
        .where(_rows.containsKey)
        .map((p) => _rows[p]!)
        .toList();
  }

  /// Returns whether a row has been added for the given [platform].
  bool hasRow(TargetPlatform platform) => _rows.containsKey(platform);

  /// Returns the current row for a [platform], or null if not yet added.
  MatrixRow? getRow(TargetPlatform platform) => _rows[platform];

  /// Returns the number of rows currently added.
  int get rowCount => _rows.length;

  /// Resets the builder, removing all accumulated rows.
  void reset() {
    _rows.clear();
  }
}
