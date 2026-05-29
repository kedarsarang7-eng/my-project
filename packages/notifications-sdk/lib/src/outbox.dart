// ============================================================================
// Outbox — durable offline buffer for emitted events.
// ----------------------------------------------------------------------------
// While the device is offline (or the Event_Bus refuses the publish for a
// transient reason), `emit()` appends the serialized envelope here and
// returns successfully. `flushOutbox()` drains the buffer in `created_at`
// ascending order on the next successful connect (REQ 8.8, 9.7).
//
// The outbox MUST survive a process restart, so the default implementation
// persists JSON Lines to a file under the application documents directory.
// An in-memory implementation is exposed for tests and non-persistent hosts.
// SharedPreferences is intentionally NOT used as the default backing store
// because Android caps a single value at ~1 MB and emitted events can be
// larger than that in aggregate.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// One persisted entry inside the outbox.
///
/// We keep both the original [EventContract] JSON and a parsed
/// [createdAt] string so flush ordering (`created_at` ASC, REQ 8.8) doesn't
/// require re-parsing the whole event each time.
class OutboxEntry {
  final String id;
  final String createdAt;
  final Map<String, dynamic> eventJson;

  const OutboxEntry({
    required this.id,
    required this.createdAt,
    required this.eventJson,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'created_at': createdAt,
        'event': eventJson,
      };

  factory OutboxEntry.fromJson(Map<String, dynamic> json) {
    return OutboxEntry(
      id: json['id'] as String,
      createdAt: json['created_at'] as String,
      eventJson: Map<String, dynamic>.from(json['event'] as Map),
    );
  }
}

/// Storage abstraction so apps can plug in their own persistence (Drift,
/// Hive, SQLite, encrypted file, whatever) without forking the SDK.
///
/// All methods MUST be safe to call concurrently from the perspective of the
/// SDK — implementations are responsible for any internal locking.
abstract class OutboxStorage {
  /// Append one entry to the tail of the buffer. Returns when persisted.
  Future<void> append(OutboxEntry entry);

  /// Read every pending entry, sorted by `created_at` ascending. Pending
  /// entries are those that have not been removed via [removeMany].
  Future<List<OutboxEntry>> readAllAscending();

  /// Atomically remove the given ids from the buffer. Used after a flush
  /// successfully publishes a batch.
  Future<void> removeMany(Iterable<String> ids);

  /// Drop every entry. Primarily for tests.
  Future<void> clear();
}

/// Volatile, in-memory storage. Loses data on process exit.
class InMemoryOutboxStorage implements OutboxStorage {
  final List<OutboxEntry> _entries = <OutboxEntry>[];

  @override
  Future<void> append(OutboxEntry entry) async {
    _entries.add(entry);
  }

  @override
  Future<List<OutboxEntry>> readAllAscending() async {
    final copy = List<OutboxEntry>.from(_entries);
    copy.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return copy;
  }

  @override
  Future<void> removeMany(Iterable<String> ids) async {
    final asSet = ids.toSet();
    _entries.removeWhere((e) => asSet.contains(e.id));
  }

  @override
  Future<void> clear() async => _entries.clear();
}

/// File-backed storage using one JSON object per line (JSONL).
///
/// Append-only writes plus a periodic compaction on remove keep the format
/// crash-safe enough for an offline outbox: a partial trailing line is
/// silently dropped during read. A best-effort fsync (`flush(FileMode.write)`)
/// is issued after every append.
class FileOutboxStorage implements OutboxStorage {
  final File _file;

  /// Lock that serialises append/read/remove so concurrent emits from the
  /// same process don't interleave their writes mid-line.
  final _lock = _AsyncLock();

  FileOutboxStorage._(this._file);

  /// Open or create the outbox file at [path]. Parent directories are
  /// created if missing.
  factory FileOutboxStorage(String path) {
    final f = File(path);
    if (!f.parent.existsSync()) {
      f.parent.createSync(recursive: true);
    }
    if (!f.existsSync()) {
      f.createSync();
    }
    return FileOutboxStorage._(f);
  }

  /// Resolve a default outbox path under the given documents directory,
  /// e.g. `<docsDir>/notifications_sdk/outbox.jsonl`.
  static String defaultPath(String documentsDir) =>
      p.join(documentsDir, 'notifications_sdk', 'outbox.jsonl');

  @override
  Future<void> append(OutboxEntry entry) async {
    await _lock.run(() async {
      final line = '${jsonEncode(entry.toJson())}\n';
      final raf = await _file.open(mode: FileMode.append);
      try {
        await raf.writeString(line);
        await raf.flush();
      } finally {
        await raf.close();
      }
    });
  }

  @override
  Future<List<OutboxEntry>> readAllAscending() async {
    return _lock.run(() async {
      final entries = await _readEntries();
      entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return entries;
    });
  }

  @override
  Future<void> removeMany(Iterable<String> ids) async {
    await _lock.run(() async {
      final removeSet = ids.toSet();
      final remaining = (await _readEntries())
          .where((e) => !removeSet.contains(e.id))
          .toList();
      // Rewrite atomically via a temp file swap.
      final tmp = File('${_file.path}.tmp');
      final sink = tmp.openWrite();
      try {
        for (final e in remaining) {
          sink.writeln(jsonEncode(e.toJson()));
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (await _file.exists()) {
        await _file.delete();
      }
      await tmp.rename(_file.path);
    });
  }

  @override
  Future<void> clear() async {
    await _lock.run(() async {
      if (await _file.exists()) {
        await _file.writeAsString('');
      }
    });
  }

  Future<List<OutboxEntry>> _readEntries() async {
    if (!await _file.exists()) return <OutboxEntry>[];
    final content = await _file.readAsString();
    if (content.isEmpty) return <OutboxEntry>[];
    final out = <OutboxEntry>[];
    for (final line in const LineSplitter().convert(content)) {
      if (line.isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) {
          out.add(OutboxEntry.fromJson(decoded));
        }
      } catch (_) {
        // Drop a corrupt trailing line silently — outbox stays best-effort
        // durable; one bad line never blocks the rest of the buffer.
      }
    }
    return out;
  }
}

/// Minimal async mutex (one waiter at a time). Avoids pulling in `package:synchronized`.
/// The chained-future trick: each new `run()` waits on the previous tail
/// and replaces it with its own completer, so concurrent emits from the
/// same isolate serialise without ever interleaving file-write bytes.
class _AsyncLock {
  Future<void> _last = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    final prev = _last;
    _last = completer.future.then<void>((_) => null, onError: (_) {});
    prev.whenComplete(() async {
      try {
        completer.complete(await action());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }
}
