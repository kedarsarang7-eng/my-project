/// File-Ownership Map — classifies every project file into one of three scopes
/// (activeVertical, sharedCore, otherVerticalExclusive) relative to a given
/// Business_Type, and exposes the per-widget consumer set.
///
/// Uses:
/// - Sidebar resolution: each `SidebarMenuItem.id` → `tryGetScreenForItem(id)` → source file
/// - Feature-folder heuristic: `lib/features/<folder>/...` → vertical via `verticals.json`
/// - Shared-core detection: consumer-set size > 1 OR path under known shared roots
///
/// Requirements: 1.2, 1.4
library;

import 'dart:convert';
import 'dart:io';

import '../analyzers/screen_discovery.dart';
import '../models/audit_engine_models.dart';

/// Known shared root paths. Files under these directories are always classified
/// as shared-core regardless of consumer-set size.
const List<String> _sharedRootPaths = ['lib/core/', 'lib/widgets/'];

/// Maps a `verticals.json` `businessType` string to the corresponding enum value.
/// Returns null if no match is found.
BusinessType? _parseBusinessType(String raw) {
  final normalized = raw.toLowerCase().replaceAll(RegExp(r'[\s/&]'), '');
  for (final bt in BusinessType.values) {
    final enumNormalized = bt.displayName.toLowerCase().replaceAll(
      RegExp(r'[\s/&]'),
      '',
    );
    if (enumNormalized == normalized) return bt;
  }
  return null;
}

/// Pre-computed ownership data for a single file.
class FileOwnershipEntry {
  /// The canonical file path.
  final String filePath;

  /// Set of Business_Types that consume this file (via sidebar resolution or
  /// feature-folder mapping).
  final Set<BusinessType> consumers;

  const FileOwnershipEntry({required this.filePath, required this.consumers});
}

/// Classifies files into ownership scopes and exposes consumer sets.
///
/// Constructable with pre-computed ownership data (for testability) or built
/// from project sources via [FileOwnershipMap.build].
class FileOwnershipMap {
  /// Internal map: canonical file path → set of consuming Business_Types.
  final Map<String, Set<BusinessType>> _consumers;

  /// Feature folder → BusinessType mapping derived from verticals.json.
  final Map<String, BusinessType> _folderToBusinessType;

  /// The screen discovery engine used for the feature-folder heuristic.
  final ScreenDiscoveryEngine _discoveryEngine;

  /// Creates a FileOwnershipMap from pre-computed ownership data.
  ///
  /// [consumers] maps canonical file paths to their consuming Business_Types.
  /// [folderToBusinessType] maps feature folder names to Business_Types.
  /// [discoveryEngine] is used for the `deriveVertical` heuristic.
  FileOwnershipMap({
    required Map<String, Set<BusinessType>> consumers,
    required Map<String, BusinessType> folderToBusinessType,
    ScreenDiscoveryEngine? discoveryEngine,
  }) : _consumers = consumers,
       _folderToBusinessType = folderToBusinessType,
       _discoveryEngine = discoveryEngine ?? ScreenDiscoveryEngine();

  /// Builds a [FileOwnershipMap] from a verticals.json configuration file
  /// and pre-resolved sidebar screen mappings.
  ///
  /// [verticalsJsonPath] is the path to the verticals.json config file.
  /// [sidebarScreenFiles] maps each Business_Type to the set of canonical file
  /// paths reachable from its sidebar entries (resolved via `tryGetScreenForItem`).
  factory FileOwnershipMap.build({
    required String verticalsJsonPath,
    required Map<BusinessType, Set<String>> sidebarScreenFiles,
    ScreenDiscoveryEngine? discoveryEngine,
  }) {
    final engine = discoveryEngine ?? ScreenDiscoveryEngine();

    // Load verticals.json to build folder → BusinessType mapping
    final folderToBusinessType = _loadFolderMapping(verticalsJsonPath);

    // Build consumer map from sidebar screen files
    final consumers = <String, Set<BusinessType>>{};

    for (final entry in sidebarScreenFiles.entries) {
      final businessType = entry.key;
      final files = entry.value;

      for (final rawPath in files) {
        final canonical = canonicalFilePath(rawPath);
        consumers.putIfAbsent(canonical, () => <BusinessType>{});
        consumers[canonical]!.add(businessType);
      }
    }

    return FileOwnershipMap(
      consumers: consumers,
      folderToBusinessType: folderToBusinessType,
      discoveryEngine: engine,
    );
  }

  /// Classifies a file into one of the three scopes relative to the active
  /// Business_Type.
  ///
  /// Classification rules (in priority order):
  /// 1. If the file is under a shared root path → [FileScope.sharedCore]
  /// 2. If the file's consumer-set size > 1 → [FileScope.sharedCore]
  /// 3. If the file belongs to the active Business_Type → [FileScope.activeVertical]
  /// 4. If the file belongs exclusively to another Business_Type →
  ///    [FileScope.otherVerticalExclusive]
  /// 5. If the file is unknown (not in the map), apply the feature-folder
  ///    heuristic to determine ownership.
  FileScope classifyFile(String filePath, BusinessType active) {
    final canonical = canonicalFilePath(filePath);

    // Rule 1: Check shared root paths
    if (_isUnderSharedRoot(canonical)) {
      return FileScope.sharedCore;
    }

    // Resolve consumers (from pre-computed map + feature-folder heuristic)
    final fileConsumers = _resolveConsumers(canonical);

    // Rule 2: Multiple consumers → shared core
    if (fileConsumers.length > 1) {
      return FileScope.sharedCore;
    }

    // Rule 3: Single consumer is the active type → active vertical
    if (fileConsumers.contains(active)) {
      return FileScope.activeVertical;
    }

    // Rule 4: Single consumer is a different type → other vertical exclusive
    if (fileConsumers.isNotEmpty) {
      return FileScope.otherVerticalExclusive;
    }

    // Rule 5: No consumers found — use feature-folder heuristic
    final vertical = _discoveryEngine.deriveVertical(canonical);
    if (vertical == 'core/general') {
      // Files in core/general with no explicit consumer are shared
      return FileScope.sharedCore;
    }

    // Check if the feature folder maps to a known business type
    final folderOwner = _folderToBusinessType[vertical];
    if (folderOwner == active) {
      return FileScope.activeVertical;
    } else if (folderOwner != null) {
      return FileScope.otherVerticalExclusive;
    }

    // Truly unknown files default to shared (conservative)
    return FileScope.sharedCore;
  }

  /// Returns the set of Business_Types that consume a given file.
  ///
  /// Combines pre-computed sidebar resolution data with the feature-folder
  /// heuristic for files not in the pre-computed map.
  Set<BusinessType> getConsumers(String filePath) {
    final canonical = canonicalFilePath(filePath);
    return _resolveConsumers(canonical);
  }

  /// Whether a file is a Shared_Core_Widget.
  ///
  /// A file is shared-core if:
  /// - Its path starts with a known shared root (`lib/core/`, `lib/widgets/`)
  /// - Its consumer-set size > 1
  bool isSharedCore(String filePath) {
    final canonical = canonicalFilePath(filePath);

    if (_isUnderSharedRoot(canonical)) {
      return true;
    }

    final fileConsumers = _resolveConsumers(canonical);
    return fileConsumers.length > 1;
  }

  /// Returns all file paths tracked in this ownership map.
  Iterable<String> get trackedFiles => _consumers.keys;

  /// Returns the folder-to-BusinessType mapping.
  Map<String, BusinessType> get folderToBusinessType =>
      Map.unmodifiable(_folderToBusinessType);

  // ─── Private helpers ─────────────────────────────────────────────────────────

  /// Checks if a canonical path is under a known shared root.
  bool _isUnderSharedRoot(String canonical) {
    for (final root in _sharedRootPaths) {
      if (canonical.contains(root)) {
        return true;
      }
    }
    return false;
  }

  /// Resolves the full consumer set for a canonical file path, combining
  /// pre-computed data with feature-folder heuristic.
  Set<BusinessType> _resolveConsumers(String canonical) {
    // Start with pre-computed consumers
    final result = Set<BusinessType>.from(_consumers[canonical] ?? {});

    // Supplement with feature-folder heuristic if not already populated
    if (result.isEmpty && !_isUnderSharedRoot(canonical)) {
      final vertical = _discoveryEngine.deriveVertical(canonical);
      if (vertical != 'core/general') {
        final folderOwner = _folderToBusinessType[vertical];
        if (folderOwner != null) {
          result.add(folderOwner);
        }
      }
    }

    return result;
  }

  /// Loads the folder→BusinessType mapping from verticals.json.
  static Map<String, BusinessType> _loadFolderMapping(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return {};
    }

    final content = file.readAsStringSync();
    final json = jsonDecode(content) as Map<String, dynamic>;
    final verticals = json['verticals'] as List<dynamic>? ?? [];

    final mapping = <String, BusinessType>{};
    for (final v in verticals) {
      final map = v as Map<String, dynamic>;
      final folder = map['featureFolder'] as String?;
      final btStr = map['businessType'] as String?;
      if (folder != null && btStr != null) {
        final bt = _parseBusinessType(btStr);
        if (bt != null) {
          mapping[folder] = bt;
        }
      }
    }

    return mapping;
  }
}
