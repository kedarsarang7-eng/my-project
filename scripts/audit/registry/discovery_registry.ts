/**
 * Discovery Registry CSV Manager
 *
 * Central orchestrator that integrates all analyzer outputs into the
 * Discovery Registry CSV. Handles read/write for the registry with all
 * columns matching the schema, detects file additions, deletions, and
 * renames between scan cycles, and merges analyzer results into a
 * single registry update pass.
 *
 * Requirements: 1.3, 1.4, 1.5
 */

import * as fs from 'fs';
import * as path from 'path';

// ─── Interfaces ─────────────────────────────────────────────────────────────

/** A single entry in the Discovery Registry CSV */
export interface RegistryEntry {
  project: string;
  feature: string;
  fileName: string;
  relativePath: string;
  businessTypes: string;
  mockData: boolean;
  mockReasons: string;
  apiConnected: boolean;
  offlineReady: boolean;
  uiConsistent: boolean;
  navWired: boolean;
  priority: string;
  status: string;
  statusReason: string;
  statusTimestamp: string;
}

/** Outputs from various analyzers that feed into the registry update */
export interface AnalyzerOutputs {
  /** Screen scan results from the screen discovery engine */
  screenEntries?: RegistryEntry[];
  /** Set of file paths connected to real APIs (from API mapper) */
  apiConnectedPaths?: Set<string>;
  /** Set of file paths reachable in the navigation graph */
  navWiredPaths?: Set<string>;
  /** Set of file paths passing UI consistency checks */
  uiConsistentPaths?: Set<string>;
  /** Set of file paths with offline support implemented */
  offlineReadyPaths?: Set<string>;
  /** Map of file paths to mock detection results (reasons string) */
  mockDetections?: Map<string, string>;
}

/** Result of detecting changes between scan cycles */
export interface FileChangeResult {
  /** Entries that are new (not in existing registry) */
  added: RegistryEntry[];
  /** Entries that still exist (present in both) */
  unchanged: RegistryEntry[];
  /** Entries that were removed (in existing but not in new scan) */
  removed: RegistryEntry[];
  /** Entries that were likely renamed (same fileName, different path) */
  renamed: Array<{ oldPath: string; newEntry: RegistryEntry }>;
}

// ─── CSV Column Definitions ─────────────────────────────────────────────────

const CSV_HEADERS: string[] = [
  'Project',
  'Feature',
  'FileName',
  'RelativePath',
  'BusinessTypes',
  'MockData',
  'MockReasons',
  'ApiConnected',
  'OfflineReady',
  'UiConsistent',
  'NavWired',
  'Priority',
  'Status',
  'StatusReason',
  'StatusTimestamp',
];

// ─── Discovery Registry Class ───────────────────────────────────────────────

/**
 * Manages the Discovery Registry CSV — the central inventory of all screens.
 *
 * Provides:
 * - CSV read/write with all 15 columns
 * - File-watch integration (additions, deletions, renames between scans)
 * - Single-pass integration of all analyzer outputs
 */
export class DiscoveryRegistry {
  /**
   * Reads the registry CSV from disk and parses it into RegistryEntry objects.
   *
   * Returns an empty array if the file doesn't exist or contains only headers.
   * Skips the header row and any empty lines.
   */
  readRegistry(csvPath: string): RegistryEntry[] {
    if (!fs.existsSync(csvPath)) {
      return [];
    }

    const content = fs.readFileSync(csvPath, 'utf-8');
    const lines = content.split(/\r?\n/);

    if (lines.length <= 1) {
      return [];
    }

    const entries: RegistryEntry[] = [];

    // Skip header row (index 0)
    for (let i = 1; i < lines.length; i++) {
      const line = lines[i].trim();
      if (line === '') continue;

      const fields = parseCsvLine(line);
      if (fields.length >= 12) {
        entries.push(fieldsToEntry(fields));
      }
    }

    return entries;
  }

  /**
   * Writes the given entries to a CSV file with proper headers.
   *
   * Creates parent directories if they don't exist.
   * Overwrites the file if it already exists.
   */
  writeRegistry(csvPath: string, entries: RegistryEntry[]): void {
    const dir = path.dirname(csvPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    const lines: string[] = [CSV_HEADERS.map(escapeCsvField).join(',')];

    for (const entry of entries) {
      lines.push(entryToCsvLine(entry));
    }

    fs.writeFileSync(csvPath, lines.join('\n') + '\n', 'utf-8');
  }

  /**
   * Merges new scan results with existing registry entries.
   *
   * Strategy:
   * - Entries present in both: update scan data, preserve status fields
   * - Entries only in scanResults: append as new ("Not Started")
   * - Entries only in existing: mark as "Removed"
   * - Entries with same fileName but different path: treat as rename
   *
   * Matching key: relativePath (normalized to forward slashes)
   */
  mergeResults(existing: RegistryEntry[], scanResults: RegistryEntry[]): RegistryEntry[] {
    const now = new Date().toISOString();
    const existingByPath = new Map<string, RegistryEntry>();
    const existingByFileName = new Map<string, RegistryEntry[]>();

    for (const entry of existing) {
      const normalizedPath = normalizePath(entry.relativePath);
      existingByPath.set(normalizedPath, entry);

      // Index by fileName for rename detection
      const fileEntries = existingByFileName.get(entry.fileName) ?? [];
      fileEntries.push(entry);
      existingByFileName.set(entry.fileName, fileEntries);
    }

    const scanByPath = new Map<string, RegistryEntry>();
    for (const entry of scanResults) {
      scanByPath.set(normalizePath(entry.relativePath), entry);
    }

    const merged: RegistryEntry[] = [];
    const processedExistingPaths = new Set<string>();

    // Process scan results
    for (const scanEntry of scanResults) {
      const normalizedScanPath = normalizePath(scanEntry.relativePath);
      const existingEntry = existingByPath.get(normalizedScanPath);

      if (existingEntry) {
        // Entry exists in both — update scan data, preserve status
        processedExistingPaths.add(normalizePath(existingEntry.relativePath));
        merged.push({
          ...scanEntry,
          status: existingEntry.status,
          statusReason: existingEntry.statusReason,
          statusTimestamp: existingEntry.statusTimestamp,
        });
      } else {
        // Check for rename: same fileName exists in existing but at different path
        const possibleRenames = existingByFileName.get(scanEntry.fileName);
        const renamedFrom = possibleRenames?.find(
          (e) => !scanByPath.has(normalizePath(e.relativePath))
        );

        if (renamedFrom) {
          // Rename detected — update path, preserve status
          processedExistingPaths.add(normalizePath(renamedFrom.relativePath));
          merged.push({
            ...scanEntry,
            status: renamedFrom.status,
            statusReason: `File renamed from ${renamedFrom.relativePath}`,
            statusTimestamp: now,
          });
        } else {
          // New entry
          merged.push({
            ...scanEntry,
            status: 'Not Started',
            statusReason: 'Discovered in scan',
            statusTimestamp: now,
          });
        }
      }
    }

    // Mark removed entries (exist in old registry but not in new scan)
    for (const existingEntry of existing) {
      const normalizedExistingPath = normalizePath(existingEntry.relativePath);
      if (!processedExistingPaths.has(normalizedExistingPath)) {
        merged.push({
          ...existingEntry,
          status: 'Removed',
          statusReason: 'File no longer exists in codebase',
          statusTimestamp: now,
        });
      }
    }

    return merged;
  }

  /**
   * Integrates all analyzer outputs into the registry in a single update pass.
   *
   * 1. Reads the existing registry from disk
   * 2. Applies analyzer outputs to enrich screen entries
   * 3. Merges with existing registry (additions, updates, removals)
   * 4. Writes the updated registry back to disk
   *
   * Returns the final merged list of entries.
   */
  updateFromAnalyzers(registryPath: string, analyzerResults: AnalyzerOutputs): RegistryEntry[] {
    const existing = this.readRegistry(registryPath);

    // Start with screen entries from the discovery engine, or empty
    let scanResults = analyzerResults.screenEntries ?? [];

    // Enrich entries with analyzer outputs
    scanResults = scanResults.map((entry) => {
      const normalizedPath = normalizePath(entry.relativePath);
      return {
        ...entry,
        apiConnected: analyzerResults.apiConnectedPaths?.has(normalizedPath) ?? entry.apiConnected,
        navWired: analyzerResults.navWiredPaths?.has(normalizedPath) ?? entry.navWired,
        uiConsistent: analyzerResults.uiConsistentPaths?.has(normalizedPath) ?? entry.uiConsistent,
        offlineReady: analyzerResults.offlineReadyPaths?.has(normalizedPath) ?? entry.offlineReady,
        mockData: analyzerResults.mockDetections?.has(normalizedPath)
          ? analyzerResults.mockDetections.get(normalizedPath) !== ''
          : entry.mockData,
        mockReasons: analyzerResults.mockDetections?.has(normalizedPath)
          ? analyzerResults.mockDetections.get(normalizedPath)!
          : entry.mockReasons,
      };
    });

    // Merge with existing registry (handles additions, deletions, renames)
    const merged = this.mergeResults(existing, scanResults);

    // Write the updated registry
    this.writeRegistry(registryPath, merged);

    return merged;
  }

  /**
   * Detects file changes (additions, deletions, renames) between scan cycles.
   *
   * Compares existing registry entries against new scan results to categorize
   * each entry as added, unchanged, removed, or renamed.
   */
  detectFileChanges(existing: RegistryEntry[], scanResults: RegistryEntry[]): FileChangeResult {
    const existingByPath = new Map<string, RegistryEntry>();
    const existingByFileName = new Map<string, RegistryEntry[]>();

    for (const entry of existing) {
      const normalizedPath = normalizePath(entry.relativePath);
      existingByPath.set(normalizedPath, entry);
      const fileEntries = existingByFileName.get(entry.fileName) ?? [];
      fileEntries.push(entry);
      existingByFileName.set(entry.fileName, fileEntries);
    }

    const scanByPath = new Map<string, RegistryEntry>();
    for (const entry of scanResults) {
      scanByPath.set(normalizePath(entry.relativePath), entry);
    }

    const added: RegistryEntry[] = [];
    const unchanged: RegistryEntry[] = [];
    const removed: RegistryEntry[] = [];
    const renamed: Array<{ oldPath: string; newEntry: RegistryEntry }> = [];
    const matchedExistingPaths = new Set<string>();

    for (const scanEntry of scanResults) {
      const normalizedScanPath = normalizePath(scanEntry.relativePath);

      if (existingByPath.has(normalizedScanPath)) {
        unchanged.push(scanEntry);
        matchedExistingPaths.add(normalizedScanPath);
      } else {
        // Check for rename
        const possibleRenames = existingByFileName.get(scanEntry.fileName);
        const renamedFrom = possibleRenames?.find(
          (e) => !scanByPath.has(normalizePath(e.relativePath))
        );

        if (renamedFrom) {
          renamed.push({ oldPath: renamedFrom.relativePath, newEntry: scanEntry });
          matchedExistingPaths.add(normalizePath(renamedFrom.relativePath));
        } else {
          added.push(scanEntry);
        }
      }
    }

    // Entries in existing but not matched
    for (const entry of existing) {
      if (!matchedExistingPaths.has(normalizePath(entry.relativePath))) {
        removed.push(entry);
      }
    }

    return { added, unchanged, removed, renamed };
  }
}

// ─── CSV Utility Functions ──────────────────────────────────────────────────

/**
 * Parses a single CSV line into field values.
 * Handles quoted fields (with embedded commas and escaped quotes).
 */
export function parseCsvLine(line: string): string[] {
  const fields: string[] = [];
  let i = 0;
  const length = line.length;

  while (i < length) {
    if (line[i] === '"') {
      // Quoted field
      i++; // skip opening quote
      let value = '';
      while (i < length) {
        if (line[i] === '"') {
          if (i + 1 < length && line[i + 1] === '"') {
            // Escaped quote
            value += '"';
            i += 2;
          } else {
            // End of quoted field
            i++; // skip closing quote
            break;
          }
        } else {
          value += line[i];
          i++;
        }
      }
      fields.push(value);
      // Skip comma after field
      if (i < length && line[i] === ',') {
        i++;
      }
    } else {
      // Unquoted field
      const commaIndex = line.indexOf(',', i);
      if (commaIndex === -1) {
        fields.push(line.substring(i));
        break;
      } else {
        fields.push(line.substring(i, commaIndex));
        i = commaIndex + 1;
      }
    }
  }

  // Handle trailing comma (empty last field)
  if (line.length > 0 && line[line.length - 1] === ',') {
    fields.push('');
  }

  return fields;
}

/**
 * Escapes a CSV field value: wraps in double quotes if it contains
 * commas, quotes, or newlines. Internal quotes are doubled.
 */
export function escapeCsvField(field: string): string {
  if (field.includes(',') || field.includes('"') || field.includes('\n')) {
    return `"${field.replace(/"/g, '""')}"`;
  }
  return field;
}

/**
 * Converts a RegistryEntry to a CSV line string.
 */
export function entryToCsvLine(entry: RegistryEntry): string {
  const fields: string[] = [
    entry.project,
    entry.feature,
    entry.fileName,
    entry.relativePath,
    entry.businessTypes,
    String(entry.mockData),
    entry.mockReasons,
    String(entry.apiConnected),
    String(entry.offlineReady),
    String(entry.uiConsistent),
    String(entry.navWired),
    entry.priority,
    entry.status,
    entry.statusReason,
    entry.statusTimestamp,
  ];
  return fields.map(escapeCsvField).join(',');
}

/**
 * Converts a list of CSV fields to a RegistryEntry.
 */
export function fieldsToEntry(fields: string[]): RegistryEntry {
  return {
    project: fields[0] ?? '',
    feature: fields[1] ?? '',
    fileName: fields[2] ?? '',
    relativePath: fields[3] ?? '',
    businessTypes: fields[4] ?? '',
    mockData: (fields[5] ?? '').toLowerCase() === 'true',
    mockReasons: fields[6] ?? '',
    apiConnected: (fields[7] ?? '').toLowerCase() === 'true',
    offlineReady: (fields[8] ?? '').toLowerCase() === 'true',
    uiConsistent: (fields[9] ?? '').toLowerCase() === 'true',
    navWired: (fields[10] ?? '').toLowerCase() === 'true',
    priority: fields[11] ?? 'Low',
    status: fields[12] ?? 'Not Started',
    statusReason: fields[13] ?? '',
    statusTimestamp: fields[14] ?? '',
  };
}

/**
 * Normalizes a file path to use forward slashes for consistent comparison.
 */
export function normalizePath(filePath: string): string {
  return filePath.replace(/\\/g, '/');
}
