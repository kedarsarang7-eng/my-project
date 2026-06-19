/// CSV Writer Utility for the Discovery Registry.
///
/// Reads an existing registry CSV (if present), merges new scan results
/// with existing entries, handles file additions and deletions between
/// scan cycles, and writes the output CSV with proper headers.
///
/// Requirements: 1.3, 1.4, 1.5
library;

import 'dart:io';

import '../models/screen_entry.dart';

/// Represents a registry entry that may also be marked as removed.
class RegistryEntry {
  /// The underlying screen entry data.
  final ScreenEntry entry;

  /// Whether this entry has been marked as removed from the codebase.
  final bool removed;

  /// ISO8601 timestamp when the entry was marked as removed, or empty.
  final String removedAt;

  const RegistryEntry({
    required this.entry,
    this.removed = false,
    this.removedAt = '',
  });
}

/// CSV writer and merger for the Discovery Registry.
///
/// Handles:
/// - Reading an existing registry CSV
/// - Merging new scan results with existing entries
/// - Appending new entries discovered in the latest scan
/// - Marking entries as removed when their files no longer exist
/// - Writing the output CSV with proper headers
class CsvWriter {
  /// Parses a CSV file into a list of ScreenEntry objects.
  ///
  /// Returns an empty list if the file doesn't exist or has no data rows.
  /// Skips the header row automatically.
  List<ScreenEntry> readCsv(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      return [];
    }

    final lines = file.readAsLinesSync();
    if (lines.length <= 1) {
      // Only header or empty file
      return [];
    }

    final entries = <ScreenEntry>[];
    // Skip header row (index 0)
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final fields = _parseCsvLine(line);
      if (fields.length >= 12) {
        entries.add(ScreenEntry.fromCsvRow(fields));
      }
    }

    return entries;
  }

  /// Merges new scan results with existing registry entries.
  ///
  /// - Entries in [newEntries] that don't exist in [existingEntries] are
  ///   appended as new (status "Not Started").
  /// - Entries in [existingEntries] that still appear in [newEntries] are
  ///   updated with the latest scan data while preserving their status fields.
  /// - Entries in [existingEntries] that don't appear in [newEntries] are
  ///   marked as removed (status set to "Removed").
  ///
  /// Matching is based on [relativePath] as the unique key.
  List<ScreenEntry> merge({
    required List<ScreenEntry> existingEntries,
    required List<ScreenEntry> newEntries,
  }) {
    final existingByPath = <String, ScreenEntry>{};
    for (final entry in existingEntries) {
      existingByPath[entry.relativePath] = entry;
    }

    final newByPath = <String, ScreenEntry>{};
    for (final entry in newEntries) {
      newByPath[entry.relativePath] = entry;
    }

    final merged = <ScreenEntry>[];
    final now = DateTime.now().toUtc().toIso8601String();

    // Process entries that exist in the new scan
    for (final newEntry in newEntries) {
      final existing = existingByPath[newEntry.relativePath];
      if (existing != null) {
        // Entry already existed — update scan data, preserve status fields
        merged.add(
          ScreenEntry(
            project: newEntry.project,
            feature: newEntry.feature,
            fileName: newEntry.fileName,
            relativePath: newEntry.relativePath,
            businessTypes: newEntry.businessTypes,
            mockData: newEntry.mockData,
            mockReasons: newEntry.mockReasons,
            apiConnected: newEntry.apiConnected,
            offlineReady: newEntry.offlineReady,
            uiConsistent: newEntry.uiConsistent,
            navWired: newEntry.navWired,
            priority: newEntry.priority,
            status: existing.status,
            statusReason: existing.statusReason,
            statusTimestamp: existing.statusTimestamp,
          ),
        );
      } else {
        // New entry — append with default status
        merged.add(
          ScreenEntry(
            project: newEntry.project,
            feature: newEntry.feature,
            fileName: newEntry.fileName,
            relativePath: newEntry.relativePath,
            businessTypes: newEntry.businessTypes,
            mockData: newEntry.mockData,
            mockReasons: newEntry.mockReasons,
            apiConnected: newEntry.apiConnected,
            offlineReady: newEntry.offlineReady,
            uiConsistent: newEntry.uiConsistent,
            navWired: newEntry.navWired,
            priority: newEntry.priority,
            status: 'Not Started',
            statusReason: 'Discovered in scan',
            statusTimestamp: now,
          ),
        );
      }
    }

    // Mark removed entries (exist in old registry but not in new scan)
    for (final existing in existingEntries) {
      if (!newByPath.containsKey(existing.relativePath)) {
        // Mark as removed — keep entry but update status
        merged.add(
          ScreenEntry(
            project: existing.project,
            feature: existing.feature,
            fileName: existing.fileName,
            relativePath: existing.relativePath,
            businessTypes: existing.businessTypes,
            mockData: existing.mockData,
            mockReasons: existing.mockReasons,
            apiConnected: existing.apiConnected,
            offlineReady: existing.offlineReady,
            uiConsistent: existing.uiConsistent,
            navWired: existing.navWired,
            priority: existing.priority,
            status: 'Removed',
            statusReason: 'File no longer exists in codebase',
            statusTimestamp: now,
          ),
        );
      }
    }

    return merged;
  }

  /// Writes the given entries to a CSV file with proper headers.
  ///
  /// Creates parent directories if they don't exist.
  /// Overwrites the file if it already exists.
  void writeCsv(String filePath, List<ScreenEntry> entries) {
    final file = File(filePath);
    final parentDir = file.parent;
    if (!parentDir.existsSync()) {
      parentDir.createSync(recursive: true);
    }

    final buffer = StringBuffer();

    // Write header row
    buffer.writeln(ScreenEntry.csvHeaders.join(','));

    // Write data rows
    for (final entry in entries) {
      buffer.writeln(_toCsvLine(entry.toCsvRow()));
    }

    file.writeAsStringSync(buffer.toString());
  }

  /// Performs a full registry update cycle:
  /// 1. Reads existing registry (if present)
  /// 2. Merges with new scan results
  /// 3. Writes updated registry
  ///
  /// Returns the merged list of entries.
  List<ScreenEntry> updateRegistry({
    required String registryPath,
    required List<ScreenEntry> scanResults,
  }) {
    final existing = readCsv(registryPath);
    final merged = merge(existingEntries: existing, newEntries: scanResults);
    writeCsv(registryPath, merged);
    return merged;
  }

  /// Escapes a CSV field value: wraps in double quotes if it contains
  /// commas, quotes, or newlines. Internal quotes are doubled.
  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// Converts a list of field values to a single CSV line string.
  String _toCsvLine(List<String> fields) {
    return fields.map(_escapeCsvField).join(',');
  }

  /// Parses a single CSV line into a list of field values.
  ///
  /// Handles quoted fields (with embedded commas and escaped quotes).
  List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    var i = 0;
    final length = line.length;

    while (i < length) {
      if (line[i] == '"') {
        // Quoted field
        i++; // skip opening quote
        final buffer = StringBuffer();
        while (i < length) {
          if (line[i] == '"') {
            if (i + 1 < length && line[i + 1] == '"') {
              // Escaped quote
              buffer.write('"');
              i += 2;
            } else {
              // End of quoted field
              i++; // skip closing quote
              break;
            }
          } else {
            buffer.write(line[i]);
            i++;
          }
        }
        fields.add(buffer.toString());
        // Skip comma after field
        if (i < length && line[i] == ',') {
          i++;
        }
      } else {
        // Unquoted field
        final commaIndex = line.indexOf(',', i);
        if (commaIndex == -1) {
          fields.add(line.substring(i));
          break;
        } else {
          fields.add(line.substring(i, commaIndex));
          i = commaIndex + 1;
        }
      }
    }

    // Handle trailing comma (empty last field)
    if (line.isNotEmpty && line[line.length - 1] == ',') {
      fields.add('');
    }

    return fields;
  }
}
