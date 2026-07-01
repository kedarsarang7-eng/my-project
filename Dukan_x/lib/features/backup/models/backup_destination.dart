import 'package:flutter/foundation.dart';

/// Where a backup can be written.
///
/// Some destinations require filesystem-level access that mobile platform
/// sandboxes (Android/iOS) do not allow, so they are gated to desktop only.
/// [availableForCurrentPlatform] is the single source of truth the UI uses to
/// decide which options to offer — it must never fake a mobile USB/SSD picker.
enum BackupDestination {
  googleDrive(
    label: 'Google Drive',
    requiresDesktop: false,
  ),
  localDevice(
    label: 'Local Device Storage',
    requiresDesktop: false,
  ),
  usbDrive(
    label: 'USB Drive',
    requiresDesktop: true,
  ),
  externalSsd(
    label: 'External SSD',
    requiresDesktop: true,
  ),
  externalHardDrive(
    label: 'External Hard Drive',
    requiresDesktop: true,
  ),
  networkStorage(
    label: 'Network Storage',
    requiresDesktop: true,
  );

  const BackupDestination({
    required this.label,
    required this.requiresDesktop,
  });

  final String label;

  /// True for destinations that need desktop-class filesystem access.
  final bool requiresDesktop;

  /// Whether this destination is selectable on the current platform.
  bool get availableForCurrentPlatform =>
      !requiresDesktop || _isDesktopPlatform;

  /// Destinations that may be offered on the current platform.
  static List<BackupDestination> availableDestinations() =>
      values.where((d) => d.availableForCurrentPlatform).toList();

  static bool get _isDesktopPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }
}
