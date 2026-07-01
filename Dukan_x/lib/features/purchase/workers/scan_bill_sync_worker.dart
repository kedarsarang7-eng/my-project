// ============================================================================
// Scan Bill Sync Worker
// ============================================================================
// P0: Background sync using WorkManager
// Runs periodically to retry offline queue items
// ============================================================================

import 'package:workmanager/workmanager.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/connection_service.dart';
import '../services/scan_bill_offline_queue.dart';

/// Background sync task name
const String scanBillSyncTask = 'scan_bill_sync';
const String scanBillPeriodicTask = 'scan_bill_periodic_sync';

/// Initialize work manager for scan bill sync
Future<void> initializeScanBillSyncWorker() async {
  final logger = sl<LoggerService>();
  
  try {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    
    logger.info('ScanBillSyncWorker initialized');
    
    // Register periodic sync task
    await Workmanager().registerPeriodicTask(
      scanBillPeriodicTask,
      scanBillSyncTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
    
    logger.info('Periodic sync task registered (15 min interval)');
  } catch (e, stackTrace) {
    logger.error('Failed to initialize sync worker', 
        {'error': e.toString()}, stackTrace);
  }
}

/// Callback dispatcher for background tasks
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final logger = sl<LoggerService>();
    
    logger.info('Background sync task started', {'task': task});
    
    try {
      // Initialize services
      final connection = sl<ConnectionService>();
      final queue = sl<ScanBillOfflineQueue>();
      
      await queue.initialize();
      
      // Check if online
      if (!await connection.isOnline()) {
        logger.info('Offline, skipping background sync');
        return Future.value(true);
      }
      
      // Check if there are pending items
      final pendingCount = await queue.getPendingCount();
      if (pendingCount == 0) {
        logger.info('No pending items, skipping sync');
        return Future.value(true);
      }
      
      logger.info('Processing background sync', {'pendingItems': pendingCount});
      
      // Process queue
      await queue.processQueue();
      
      logger.info('Background sync completed');
      return Future.value(true);
      
    } catch (e, stackTrace) {
      logger.error('Background sync failed', 
          {'error': e.toString(), 'task': task}, stackTrace);
      return Future.value(false);
    }
  });
}

/// Trigger immediate sync
Future<void> triggerImmediateSync() async {
  final logger = sl<LoggerService>();
  
  try {
    await Workmanager().registerOneOffTask(
      '${scanBillSyncTask}_immediate_${DateTime.now().millisecondsSinceEpoch}',
      scanBillSyncTask,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    
    logger.info('Immediate sync triggered');
  } catch (e, stackTrace) {
    logger.error('Failed to trigger immediate sync', 
        {'error': e.toString()}, stackTrace);
  }
}

/// Cancel all sync tasks
Future<void> cancelSyncTasks() async {
  final logger = sl<LoggerService>();
  
  try {
    await Workmanager().cancelAll();
    logger.info('All sync tasks cancelled');
  } catch (e, stackTrace) {
    logger.error('Failed to cancel sync tasks', 
        {'error': e.toString()}, stackTrace);
  }
}

/// Check if periodic sync is enabled
Future<bool> isPeriodicSyncEnabled() async {
  // WorkManager doesn't provide a direct way to check this
  // We track it separately in shared preferences if needed
  return true; // Assume enabled if initialized
}
