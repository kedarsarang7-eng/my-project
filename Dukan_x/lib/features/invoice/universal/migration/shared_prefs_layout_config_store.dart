import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../models/business_type.dart';
import '../config/invoice_layout_config.dart';
import 'invoice_layout_migration.dart';

/// Offline-first persistent [LayoutConfigStore] backed by SharedPreferences.
///
/// Configs are held in memory (so the sync [LayoutConfigStore] API works) and
/// serialised as a single JSON blob keyed by [BusinessType.name]. Call [load]
/// before use and [save] after mutations to persist. This matches the app's
/// offline-first pattern; the [RemoteLayoutConfigSync] pushes the same JSON to
/// DynamoDB via API Gateway.
class SharedPrefsLayoutConfigStore implements LayoutConfigStore {
  static const String storageKey = 'invoice_layout_configs.v3';

  final Map<BusinessType, InvoiceLayoutConfig> _mem = {};
  SharedPreferences? _prefs;

  /// Load persisted configs into memory. Safe to call multiple times.
  Future<void> load() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    _mem.clear();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    for (final entry in decoded.entries) {
      final cfg = InvoiceLayoutConfig.fromJson(
        entry.value as Map<String, dynamic>,
      );
      _mem[BusinessType.values.byName(entry.key)] = cfg;
    }
  }

  /// Persist the current in-memory configs.
  Future<void> save() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final map = <String, dynamic>{
      for (final e in _mem.entries) e.key.name: e.value.toJson(),
    };
    await prefs.setString(storageKey, jsonEncode(map));
  }

  @override
  bool has(BusinessType t) => _mem.containsKey(t);
  @override
  void put(BusinessType t, InvoiceLayoutConfig c) => _mem[t] = c;
  @override
  void remove(BusinessType t) => _mem.remove(t);
  @override
  InvoiceLayoutConfig? get(BusinessType t) => _mem[t];
  @override
  int get count => _mem.length;
  @override
  List<BusinessType> get types => _mem.keys.toList();
  @override
  Map<BusinessType, InvoiceLayoutConfig> get all => Map.unmodifiable(_mem);
}
