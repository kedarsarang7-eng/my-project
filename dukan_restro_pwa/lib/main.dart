// ============================================================================
// CUSTOMER PWA — MAIN ENTRY
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/pwa_cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // P0-07: Pre-init Hive so menu cache works on first paint without lazy delay.
  await PwaCacheService.init();
  runApp(const ProviderScope(child: RestroCustomerApp()));
}
