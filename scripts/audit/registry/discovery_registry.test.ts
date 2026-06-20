/**
 * Unit tests for Discovery Registry CSV Manager
 *
 * Tests: CSV read/write, merge logic (additions, deletions, renames),
 * analyzer output integration, and CSV parsing edge cases.
 */

import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import {
  DiscoveryRegistry,
  RegistryEntry,
  AnalyzerOutputs,
  parseCsvLine,
  escapeCsvField,
  entryToCsvLine,
  fieldsToEntry,
  normalizePath,
} from './discovery_registry';

// ─── Helpers ────────────────────────────────────────────────────────────────

function createTempDir(): string {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'registry-test-'));
}

function makeEntry(overrides: Partial<RegistryEntry> = {}): RegistryEntry {
  return {
    project: 'Dukan_x',
    feature: 'restaurant',
    fileName: 'menu_screen.dart',
    relativePath: 'lib/features/restaurant/presentation/screens/menu_screen.dart',
    businessTypes: 'Restaurant',
    mockData: false,
    mockReasons: '',
    apiConnected: true,
    offlineReady: false,
    uiConsistent: true,
    navWired: true,
    priority: 'Medium',
    status: 'Not Started',
    statusReason: '',
    statusTimestamp: '',
    ...overrides,
  };
}

// ─── CSV Parsing Tests ──────────────────────────────────────────────────────

describe('parseCsvLine', () => {
  it('parses simple unquoted fields', () => {
    const result = parseCsvLine('a,b,c');
    expect(result).toEqual(['a', 'b', 'c']);
  });

  it('parses quoted fields containing commas', () => {
    const result = parseCsvLine('"hello, world",b,c');
    expect(result).toEqual(['hello, world', 'b', 'c']);
  });

  it('parses quoted fields with escaped quotes', () => {
    const result = parseCsvLine('"say ""hello""",b');
    expect(result).toEqual(['say "hello"', 'b']);
  });

  it('parses empty fields', () => {
    const result = parseCsvLine('a,,c');
    expect(result).toEqual(['a', '', 'c']);
  });

  it('handles trailing comma as empty last field', () => {
    const result = parseCsvLine('a,b,');
    expect(result).toEqual(['a', 'b', '']);
  });
});

describe('escapeCsvField', () => {
  it('returns field as-is when no special characters', () => {
    expect(escapeCsvField('hello')).toBe('hello');
  });

  it('wraps in quotes when field contains comma', () => {
    expect(escapeCsvField('hello, world')).toBe('"hello, world"');
  });

  it('doubles internal quotes and wraps', () => {
    expect(escapeCsvField('say "hi"')).toBe('"say ""hi"""');
  });

  it('wraps in quotes when field contains newline', () => {
    expect(escapeCsvField('line1\nline2')).toBe('"line1\nline2"');
  });
});

describe('normalizePath', () => {
  it('converts backslashes to forward slashes', () => {
    expect(normalizePath('lib\\features\\restaurant')).toBe('lib/features/restaurant');
  });

  it('preserves forward slashes', () => {
    expect(normalizePath('lib/features/restaurant')).toBe('lib/features/restaurant');
  });
});

// ─── RegistryEntry Conversion Tests ─────────────────────────────────────────

describe('entryToCsvLine / fieldsToEntry round-trip', () => {
  it('round-trips a standard entry', () => {
    const entry = makeEntry();
    const csvLine = entryToCsvLine(entry);
    const fields = parseCsvLine(csvLine);
    const restored = fieldsToEntry(fields);
    expect(restored).toEqual(entry);
  });

  it('round-trips entry with special characters in mockReasons', () => {
    const entry = makeEntry({
      mockReasons: 'hardcoded_array, todo_placeholder',
      mockData: true,
    });
    const csvLine = entryToCsvLine(entry);
    const fields = parseCsvLine(csvLine);
    const restored = fieldsToEntry(fields);
    expect(restored).toEqual(entry);
  });

  it('round-trips entry with quotes in statusReason', () => {
    const entry = makeEntry({
      statusReason: 'Fixed "broken" navigation',
    });
    const csvLine = entryToCsvLine(entry);
    const fields = parseCsvLine(csvLine);
    const restored = fieldsToEntry(fields);
    expect(restored).toEqual(entry);
  });
});

// ─── Read/Write Tests ───────────────────────────────────────────────────────

describe('DiscoveryRegistry read/write', () => {
  let registry: DiscoveryRegistry;
  let tempDir: string;

  beforeEach(() => {
    registry = new DiscoveryRegistry();
    tempDir = createTempDir();
  });

  afterEach(() => {
    fs.rmSync(tempDir, { recursive: true, force: true });
  });

  it('returns empty array for non-existent file', () => {
    const result = registry.readRegistry(path.join(tempDir, 'missing.csv'));
    expect(result).toEqual([]);
  });

  it('returns empty array for file with only headers', () => {
    const csvPath = path.join(tempDir, 'empty.csv');
    fs.writeFileSync(csvPath, 'Project,Feature,FileName\n');
    const result = registry.readRegistry(csvPath);
    expect(result).toEqual([]);
  });

  it('writes and reads back entries correctly', () => {
    const csvPath = path.join(tempDir, 'test.csv');
    const entries = [
      makeEntry(),
      makeEntry({
        fileName: 'order_screen.dart',
        relativePath: 'lib/features/restaurant/presentation/screens/order_screen.dart',
        priority: 'High',
      }),
    ];

    registry.writeRegistry(csvPath, entries);
    const result = registry.readRegistry(csvPath);

    expect(result).toHaveLength(2);
    expect(result[0]).toEqual(entries[0]);
    expect(result[1]).toEqual(entries[1]);
  });

  it('creates parent directories when writing', () => {
    const csvPath = path.join(tempDir, 'nested', 'deep', 'test.csv');
    registry.writeRegistry(csvPath, [makeEntry()]);
    expect(fs.existsSync(csvPath)).toBe(true);
  });
});

// ─── Merge Tests ────────────────────────────────────────────────────────────

describe('DiscoveryRegistry mergeResults', () => {
  let registry: DiscoveryRegistry;

  beforeEach(() => {
    registry = new DiscoveryRegistry();
  });

  it('appends new entries with "Not Started" status', () => {
    const existing: RegistryEntry[] = [];
    const scanResults = [makeEntry()];

    const merged = registry.mergeResults(existing, scanResults);

    expect(merged).toHaveLength(1);
    expect(merged[0].status).toBe('Not Started');
    expect(merged[0].statusReason).toBe('Discovered in scan');
    expect(merged[0].statusTimestamp).not.toBe('');
  });

  it('preserves status fields for existing entries', () => {
    const existing = [
      makeEntry({
        status: 'In Progress',
        statusReason: 'Developer working on it',
        statusTimestamp: '2024-01-01T00:00:00.000Z',
      }),
    ];
    const scanResults = [
      makeEntry({ apiConnected: false }), // scan data changed
    ];

    const merged = registry.mergeResults(existing, scanResults);

    expect(merged).toHaveLength(1);
    expect(merged[0].status).toBe('In Progress');
    expect(merged[0].statusReason).toBe('Developer working on it');
    expect(merged[0].statusTimestamp).toBe('2024-01-01T00:00:00.000Z');
    expect(merged[0].apiConnected).toBe(false); // scan data updated
  });

  it('marks removed entries with "Removed" status', () => {
    const existing = [makeEntry()];
    const scanResults: RegistryEntry[] = []; // file was deleted

    const merged = registry.mergeResults(existing, scanResults);

    expect(merged).toHaveLength(1);
    expect(merged[0].status).toBe('Removed');
    expect(merged[0].statusReason).toBe('File no longer exists in codebase');
  });

  it('detects renames (same fileName, different path)', () => {
    const existing = [
      makeEntry({
        relativePath: 'lib/features/restaurant/screens/menu_screen.dart',
        status: 'Validated',
        statusReason: 'All checks passed',
        statusTimestamp: '2024-01-01T00:00:00.000Z',
      }),
    ];
    const scanResults = [
      makeEntry({
        relativePath: 'lib/features/restaurant/presentation/screens/menu_screen.dart',
      }),
    ];

    const merged = registry.mergeResults(existing, scanResults);

    expect(merged).toHaveLength(1);
    // Preserves old status
    expect(merged[0].status).toBe('Validated');
    // New path is used
    expect(merged[0].relativePath).toBe(
      'lib/features/restaurant/presentation/screens/menu_screen.dart'
    );
    // Status reason indicates rename
    expect(merged[0].statusReason).toContain('renamed');
  });

  it('handles mixed additions, updates, and removals', () => {
    const existing = [
      makeEntry({
        fileName: 'existing_screen.dart',
        relativePath: 'lib/features/restaurant/screens/existing_screen.dart',
        status: 'In Progress',
        statusReason: 'WIP',
        statusTimestamp: '2024-01-01T00:00:00.000Z',
      }),
      makeEntry({
        fileName: 'removed_screen.dart',
        relativePath: 'lib/features/restaurant/screens/removed_screen.dart',
      }),
    ];
    const scanResults = [
      makeEntry({
        fileName: 'existing_screen.dart',
        relativePath: 'lib/features/restaurant/screens/existing_screen.dart',
      }),
      makeEntry({
        fileName: 'new_screen.dart',
        relativePath: 'lib/features/restaurant/screens/new_screen.dart',
      }),
    ];

    const merged = registry.mergeResults(existing, scanResults);

    expect(merged).toHaveLength(3);

    const existingEntry = merged.find((e) => e.fileName === 'existing_screen.dart');
    const newEntry = merged.find((e) => e.fileName === 'new_screen.dart');
    const removedEntry = merged.find((e) => e.fileName === 'removed_screen.dart');

    expect(existingEntry?.status).toBe('In Progress');
    expect(newEntry?.status).toBe('Not Started');
    expect(removedEntry?.status).toBe('Removed');
  });
});

// ─── Analyzer Integration Tests ─────────────────────────────────────────────

describe('DiscoveryRegistry updateFromAnalyzers', () => {
  let registry: DiscoveryRegistry;
  let tempDir: string;

  beforeEach(() => {
    registry = new DiscoveryRegistry();
    tempDir = createTempDir();
  });

  afterEach(() => {
    fs.rmSync(tempDir, { recursive: true, force: true });
  });

  it('enriches entries with API connected data', () => {
    const csvPath = path.join(tempDir, 'registry.csv');
    const screenPath = 'lib/features/restaurant/presentation/screens/menu_screen.dart';

    const outputs: AnalyzerOutputs = {
      screenEntries: [makeEntry({ apiConnected: false })],
      apiConnectedPaths: new Set([normalizePath(screenPath)]),
    };

    const result = registry.updateFromAnalyzers(csvPath, outputs);

    expect(result).toHaveLength(1);
    expect(result[0].apiConnected).toBe(true);
  });

  it('enriches entries with navigation wired data', () => {
    const csvPath = path.join(tempDir, 'registry.csv');
    const screenPath = 'lib/features/restaurant/presentation/screens/menu_screen.dart';

    const outputs: AnalyzerOutputs = {
      screenEntries: [makeEntry({ navWired: false })],
      navWiredPaths: new Set([normalizePath(screenPath)]),
    };

    const result = registry.updateFromAnalyzers(csvPath, outputs);

    expect(result).toHaveLength(1);
    expect(result[0].navWired).toBe(true);
  });

  it('enriches entries with mock detection data', () => {
    const csvPath = path.join(tempDir, 'registry.csv');
    const screenPath = 'lib/features/restaurant/presentation/screens/menu_screen.dart';

    const outputs: AnalyzerOutputs = {
      screenEntries: [makeEntry({ mockData: false, mockReasons: '' })],
      mockDetections: new Map([
        [normalizePath(screenPath), 'hardcoded_array,todo_placeholder'],
      ]),
    };

    const result = registry.updateFromAnalyzers(csvPath, outputs);

    expect(result).toHaveLength(1);
    expect(result[0].mockData).toBe(true);
    expect(result[0].mockReasons).toBe('hardcoded_array,todo_placeholder');
  });

  it('persists results to disk', () => {
    const csvPath = path.join(tempDir, 'registry.csv');

    const outputs: AnalyzerOutputs = {
      screenEntries: [makeEntry()],
    };

    registry.updateFromAnalyzers(csvPath, outputs);

    // Verify file was written
    expect(fs.existsSync(csvPath)).toBe(true);

    // Verify we can read it back
    const readBack = registry.readRegistry(csvPath);
    expect(readBack).toHaveLength(1);
    expect(readBack[0].fileName).toBe('menu_screen.dart');
  });

  it('merges with existing registry on subsequent runs', () => {
    const csvPath = path.join(tempDir, 'registry.csv');

    // First scan
    const firstOutputs: AnalyzerOutputs = {
      screenEntries: [
        makeEntry({
          fileName: 'screen_a.dart',
          relativePath: 'lib/features/restaurant/screens/screen_a.dart',
        }),
      ],
    };
    registry.updateFromAnalyzers(csvPath, firstOutputs);

    // Second scan — new screen added, old one still exists
    const secondOutputs: AnalyzerOutputs = {
      screenEntries: [
        makeEntry({
          fileName: 'screen_a.dart',
          relativePath: 'lib/features/restaurant/screens/screen_a.dart',
        }),
        makeEntry({
          fileName: 'screen_b.dart',
          relativePath: 'lib/features/restaurant/screens/screen_b.dart',
        }),
      ],
    };
    const result = registry.updateFromAnalyzers(csvPath, secondOutputs);

    expect(result).toHaveLength(2);
  });
});

// ─── File Change Detection Tests ────────────────────────────────────────────

describe('DiscoveryRegistry detectFileChanges', () => {
  let registry: DiscoveryRegistry;

  beforeEach(() => {
    registry = new DiscoveryRegistry();
  });

  it('detects added files', () => {
    const existing: RegistryEntry[] = [];
    const scanResults = [makeEntry()];

    const changes = registry.detectFileChanges(existing, scanResults);

    expect(changes.added).toHaveLength(1);
    expect(changes.unchanged).toHaveLength(0);
    expect(changes.removed).toHaveLength(0);
    expect(changes.renamed).toHaveLength(0);
  });

  it('detects removed files', () => {
    const existing = [makeEntry()];
    const scanResults: RegistryEntry[] = [];

    const changes = registry.detectFileChanges(existing, scanResults);

    expect(changes.added).toHaveLength(0);
    expect(changes.unchanged).toHaveLength(0);
    expect(changes.removed).toHaveLength(1);
    expect(changes.renamed).toHaveLength(0);
  });

  it('detects unchanged files', () => {
    const entry = makeEntry();
    const existing = [entry];
    const scanResults = [entry];

    const changes = registry.detectFileChanges(existing, scanResults);

    expect(changes.added).toHaveLength(0);
    expect(changes.unchanged).toHaveLength(1);
    expect(changes.removed).toHaveLength(0);
    expect(changes.renamed).toHaveLength(0);
  });

  it('detects renamed files (same fileName, different path)', () => {
    const existing = [
      makeEntry({
        relativePath: 'lib/features/restaurant/old/menu_screen.dart',
      }),
    ];
    const scanResults = [
      makeEntry({
        relativePath: 'lib/features/restaurant/new/menu_screen.dart',
      }),
    ];

    const changes = registry.detectFileChanges(existing, scanResults);

    expect(changes.added).toHaveLength(0);
    expect(changes.unchanged).toHaveLength(0);
    expect(changes.removed).toHaveLength(0);
    expect(changes.renamed).toHaveLength(1);
    expect(changes.renamed[0].oldPath).toBe('lib/features/restaurant/old/menu_screen.dart');
    expect(changes.renamed[0].newEntry.relativePath).toBe(
      'lib/features/restaurant/new/menu_screen.dart'
    );
  });
});
