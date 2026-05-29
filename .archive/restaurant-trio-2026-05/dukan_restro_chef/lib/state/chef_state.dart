import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chef_models.dart';
import '../services/chef_api_service.dart';
import '../services/chef_ws_service.dart';

class ChefState extends ChangeNotifier {
  ChefState() {
    _init();
  }

  final ChefWsService _ws = ChefWsService();
  StreamSubscription<String>? _wsSub;
  List<ChefKot> activeKots = [];
  List<ChefKot> completedKots = [];
  bool loading = true;
  String station = 'All';

  Future<void> _init() async {
    await refresh();
    await _ws.connect();
    _wsSub = _ws.events.listen((_) => refresh());
  }

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    final fetched = await ChefApiService.fetchActiveKots();
    final done = fetched.where((k) => k.isCompleted).toList();
    final active = fetched.where((k) => !k.isCompleted).toList()
      ..sort((a, b) => b.priority ? 1 : -1);
    completedKots = [...done, ...completedKots].take(150).toList();
    activeKots = active;
    loading = false;
    notifyListeners();
  }

  List<ChefKot> get stationFiltered {
    if (station == 'All') return activeKots;
    return activeKots.where((k) {
      return k.items.any((i) => _stationMatches(i.name, station));
    }).toList();
  }

  Future<void> advanceItem(ChefKot kot, ChefKotItem item) async {
    final next = item.status == 'pending'
        ? 'preparing'
        : item.status == 'preparing'
        ? 'ready'
        : 'served';
    final ok = await ChefApiService.updateItemStatus(
      kotId: kot.id,
      itemId: item.id,
      status: next,
    );
    if (ok) await refresh();
  }

  Future<void> bulkCompleteSimpleItems(ChefKot kot) async {
    const simple = ['water', 'bread', 'poppadom'];
    for (final item in kot.items) {
      final name = item.name.toLowerCase();
      if (simple.any(name.contains) && item.status != 'served') {
        await ChefApiService.updateItemStatus(
          kotId: kot.id,
          itemId: item.id,
          status: item.status == 'pending'
              ? 'preparing'
              : item.status == 'preparing'
              ? 'ready'
              : 'served',
        );
      }
    }
    await refresh();
  }

  Future<void> markUnavailable(ChefKotItem item) async {
    await ChefApiService.markItemUnavailable(item.id);
  }

  void setStation(String value) {
    station = value;
    notifyListeners();
  }

  bool _stationMatches(String name, String station) {
    final n = name.toLowerCase();
    switch (station) {
      case 'Grill':
        return n.contains('grill') || n.contains('bbq');
      case 'Tandoor':
        return n.contains('tandoor') || n.contains('naan');
      case 'Cold':
        return n.contains('salad') || n.contains('cold');
      case 'Dessert':
        return n.contains('dessert') || n.contains('ice') || n.contains('cake');
      default:
        return true;
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _ws.dispose();
    super.dispose();
  }
}
