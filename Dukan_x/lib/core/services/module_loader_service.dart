import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ModuleLoaderService extends ChangeNotifier {
  static const String _modulesKey = 'active_saas_modules';

  List<String> _activeModules = [];
  bool _isInitialized = false;

  List<String> get activeModules => _activeModules;
  bool get isInitialized => _isInitialized;

  /// Load cached modules on startup
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cached = prefs.getString(_modulesKey);
    if (cached != null) {
      try {
        final List<dynamic> decoded = jsonDecode(cached);
        _activeModules = decoded.cast<String>();
      } catch (e) {
        _activeModules = [];
      }
    }
    _isInitialized = true;
    notifyListeners();
  }

  /// Check if a specific business module is allowed by Super Admin
  bool isModuleEnabled(String businessType) {
    if (_activeModules.isEmpty) {
      // Fallback or strict mode? Let's assume strict mode.
      return false;
    }
    return _activeModules.contains(businessType);
  }

  /// Update modules list (called on login/license validation or realtime sync)
  Future<void> updateActiveModules(List<String> modules) async {
    _activeModules = modules;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modulesKey, jsonEncode(modules));
    notifyListeners();
  }

  /// Add/Enable a module in real-time
  Future<void> enableModule(String businessType) async {
    if (!_activeModules.contains(businessType)) {
      _activeModules.add(businessType);
      await _save();
      notifyListeners();
    }
  }

  /// Remove/Disable a module in real-time
  Future<void> disableModule(String businessType) async {
    if (_activeModules.contains(businessType)) {
      _activeModules.remove(businessType);
      await _save();
      notifyListeners();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modulesKey, jsonEncode(_activeModules));
  }

  Future<void> clear() async {
    _activeModules = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_modulesKey);
    notifyListeners();
  }
}
