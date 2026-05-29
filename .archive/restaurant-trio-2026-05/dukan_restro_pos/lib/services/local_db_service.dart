import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/pos_table.dart';
import '../models/pos_menu_item.dart';

// ============================================================================
// LOCAL DB SERVICE (SQLite) — Caches tables, menu, and offline KOTs
// ============================================================================
class LocalDbService {
  static const _dbName = 'dukan_restro.db';
  static const _version = 1;

  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        // Tables cache
        await db.execute('''
          CREATE TABLE cached_tables (
            id TEXT PRIMARY KEY,
            number TEXT NOT KEY,
            status TEXT,
            floor TEXT,
            capacity INTEGER,
            currentOrderId TEXT
          )
        ''');

        // Menu cache
        await db.execute('''
          CREATE TABLE cached_categories (
            category_json TEXT
          )
        ''');

        // Offline KOTs (to be synced)
        await db.execute('''
          CREATE TABLE offline_kots (
            id TEXT PRIMARY KEY,
            payload_json TEXT,
            created_at TEXT
          )
        ''');
      },
    );
  }

  // ── Tables ─────────────────────────────────────────────────────────────────
  static Future<void> cacheTables(List<PosTable> tables) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('cached_tables');
      for (final t in tables) {
        await txn.insert('cached_tables', {
          'id': t.id,
          'number': t.number,
          'status': t.status.name,
          'floor': t.floor,
          'capacity': t.capacity,
          'currentOrderId': t.currentOrderId,
        });
      }
    });
  }

  static Future<List<PosTable>> getCachedTables() async {
    final d = await db;
    final rows = await d.query('cached_tables');
    return rows.map((r) {
      return PosTable(
        id: r['id'] as String,
        number: r['number'] as String,
        status: PosTableStatus.values.firstWhere(
          (e) => e.name == r['status'],
          orElse: () => PosTableStatus.free,
        ),
        floor: r['floor'] as String,
        capacity: r['capacity'] as int,
        currentOrderId: r['currentOrderId'] as String?,
      );
    }).toList();
  }

  // ── Menu ────────────────────────────────────────────────────────────────────
  static Future<void> cacheMenu(List<PosCategory> categories) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('cached_categories');
      for (final c in categories) {
        await txn.insert('cached_categories', {
          'category_json': jsonEncode({
            'id': c.id,
            'name': c.name,
            'items': c.items
                .map(
                  (i) => <String, dynamic>{
                    'id': i.id,
                    'name': i.name,
                    'price': i.price,
                    'category': i.category,
                    'isVeg': i.isVeg,
                    'isAvailable': i.isAvailable,
                    'description': i.description,
                    'imageUrl': i.imageUrl,
                    'variations': i.variations,
                    'addons': i.addons,
                  },
                )
                .toList(),
          }),
        });
      }
    });
  }

  static Future<List<PosCategory>> getCachedMenu() async {
    final d = await db;
    final rows = await d.query('cached_categories');
    return rows.map((r) {
      final json = jsonDecode(r['category_json'] as String);
      return PosCategory.fromJson(json);
    }).toList();
  }

  // ── Offline KOTs ────────────────────────────────────────────────────────────
  static Future<void> saveOfflineKot(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final d = await db;
    await d.insert('offline_kots', {
      'id': id,
      'payload_json': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getOfflineKots() async {
    final d = await db;
    final rows = await d.query('offline_kots', orderBy: 'created_at ASC');
    return rows.map((r) {
      return {
        'id': r['id'],
        'payload': jsonDecode(r['payload_json'] as String),
      };
    }).toList();
  }

  static Future<void> removeOfflineKot(String id) async {
    final d = await db;
    await d.delete('offline_kots', where: 'id = ?', whereArgs: [id]);
  }
}
