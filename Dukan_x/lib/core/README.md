# DukanX Enterprise Architecture

## 🏗️ Architecture Overview

DukanX implements a **production-ready, enterprise-grade offline-first architecture** designed to handle 10M+ users with zero data loss.

```
┌─────────────────────────────────────────────────────────────────┐
│                         UI Layer                                 │
│              (Screens, Widgets, State Management)               │
├─────────────────────────────────────────────────────────────────┤
│                      Repository Layer                            │
│         (BaseRepository, BillsRepository, etc.)                 │
│              ↓ writes local first, then syncs                   │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐    ┌─────────────────────────────────┐ │
│  │   Local Database    │    │         Sync Engine             │ │
│  │      (Drift)        │←→│   (SyncManager + StateМachine)  │ │
│  │                     │    │                                 │ │
│  │ • Bills             │    │ • Queue Management              │ │
│  │ • Customers         │    │ • Exponential Backoff           │ │
│  │ • Products          │    │ • Conflict Resolution           │ │
│  │ • SyncQueue         │    │ • Dead Letter Queue             │ │
│  │ • AuditLogs         │    │ • Multi-step Operations         │ │
│  └─────────────────────┘    └─────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                    Background Services                           │
│     (BackgroundSyncService, MonitoringService)                  │
├─────────────────────────────────────────────────────────────────┤
│                       Cloud Layer                                │
│  ┌─────────────────────┐    ┌─────────────────────────────────┐ │
│  │   Firestore         │    │   Cloud Functions               │ │
│  │   (Replica DB)      │    │   • OCR Processing              │ │
│  │                     │    │   • Voice-to-Bill               │ │
│  │   Firebase Storage  │    │   • Distributed Counters        │ │
│  └─────────────────────┘    └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 📁 Core Directory Structure

```
lib/core/
├── app_bootstrap.dart           # Central service initialization
├── database/
│   ├── tables.dart              # Drift table definitions
│   ├── app_database.dart        # Database class with DAOs
│   └── app_database.g.dart      # Generated code
├── sync/
│   ├── sync_queue_state_machine.dart  # State machine for sync operations
│   ├── sync_manager.dart        # Firestore sync orchestrator
│   ├── sync_queue_local_ops.dart # Local DB operations for sync
│   └── background_sync_service.dart # Background execution
├── repository/
│   ├── base_repository.dart     # Abstract dual-write pattern
│   └── bills_repository.dart    # Bills implementation
├── monitoring/
│   └── monitoring_service.dart  # Logging, metrics, health checks
└── responsive/
    └── responsive_layout.dart   # Cross-platform UI utilities
```

## 🔄 Offline-First Dual-Write Pattern

### How It Works

1. **UI writes to LOCAL database first** (always succeeds)
2. **Operation is queued in SyncQueue** (persistent)
3. **SyncManager processes queue** when online
4. **Conflicts are resolved** using server-wins + versioning
5. **Failed operations** retry with exponential backoff
6. **Exhausted retries** move to Dead Letter Queue

### Example Usage

```dart
// In your screen/bloc
final billsRepo = BillsRepository(
  database: AppDatabase.instance,
  userId: currentUserId,
);

// Create bill - writes to local DB immediately
final result = await billsRepo.createBill(
  customerId: 'cust123',
  customerName: 'John Doe',
  items: billItems,
  billDate: DateTime.now(),
);

if (result.success) {
  // Bill is saved locally and queued for sync
  print('Bill created: ${result.data!.invoiceNumber}');
}

// Watch for real-time updates
billsRepo.watchAll().listen((bills) {
  // UI updates automatically
});
```

## 📊 Sync Queue State Machine

```
                    ┌──────────────┐
                    │   PENDING    │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
             ┌──────│ IN_PROGRESS  │──────┐
             │      └──────────────┘      │
        Success                       Failure
             │                            │
      ┌──────▼───────┐           ┌───────▼──────┐
      │    SYNCED    │           │    FAILED    │
      │  (Terminal)  │           └───────┬──────┘
      └──────────────┘                   │
                                  Retry < Max
                                         │
                                  ┌──────▼───────┐
                                  │    RETRY     │
                                  └──────┬───────┘
                                         │
                                  Retry >= Max
                                         │
                                  ┌──────▼───────┐
                                  │ DEAD_LETTER  │
                                  │ (Manual Fix) │
                                  └──────────────┘
```

## 🔧 Key Components

### 1. AppBootstrap
Initializes all services in correct order:
```dart
await AppBootstrap.instance.initialize(
  userId: currentUser.uid,
  enableBackgroundSync: true,
);
```

### 2. MonitoringService
Structured logging, performance metrics, health checks:
```dart
monitoring.info('BillsScreen', 'Bill created', metadata: {'id': bill.id});
monitoring.startTrace('createBill');
// ... operation
monitoring.stopTrace('createBill', category: 'database', success: true);
```

### 3. BaseRepository
Abstract class enforcing offline-first pattern:
```dart
class OrdersRepository extends BaseRepository<Order> {
  @override
  Future<void> insertLocal(Order entity) async {
    // Your Drift insert logic
  }
  // ... other abstract methods
}
```

### 4. SyncManager
Orchestrates Firestore synchronization:
```dart
// Manual sync trigger
await syncManager.syncNow();

// Listen to sync events
syncManager.syncEventStream.listen((event) {
  print('Synced: ${event.documentId}');
});

// Check health
final metrics = syncManager.getHealthMetrics();
```

### 5. BackgroundSyncService
Platform-aware background execution:
```dart
await backgroundSync.triggerImmediateSync();

// Get statistics
final stats = backgroundSync.getStatistics();
```

## 📱 Database Schema

| Table | Purpose |
|-------|---------|
| `sync_queue` | Pending operations to sync |
| `bills` | Invoice data |
| `bill_items` | Line items for bills |
| `customers` | Customer records |
| `products` | Product catalog |
| `payments` | Payment records |
| `expenses` | Business expenses |
| `file_uploads` | File upload queue |
| `ocr_tasks` | OCR processing queue |
| `voice_tasks` | Voice-to-bill queue |
| `schema_versions` | Migration tracking |
| `checksums` | Data integrity verification |
| `audit_logs` | Change history |
| `dead_letter_queue` | Failed operations |

## 🔐 Security

- **Firebase App Check** - Protects APIs from abuse
- **User Isolation** - All data under `users/{userId}/`
- **Optimistic Locking** - Version field prevents overwrite conflicts
- **Audit Logs** - Full history of data changes

## 📈 Testing

Run enterprise tests:
```bash
flutter test test/core/
```

Generate coverage report:
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## 🚀 Getting Started

1. **Generate Drift code:**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

2. **Initialize in main.dart:**
   ```dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
     
     // Initialize after user authentication
     FirebaseAuth.instance.authStateChanges().listen((user) {
       if (user != null) {
         AppBootstrap.instance.initialize(userId: user.uid);
       }
     });
     
     runApp(MyApp());
   }
   ```

3. **Use repositories in your screens:**
   ```dart
   final billsRepo = BillsRepository(
     database: appBootstrap.database,
     userId: currentUser.uid,
   );
   ```

## 📋 Checklist for 10/10

- [x] Offline-first architecture
- [x] Drift local database with comprehensive schema
- [x] Sync Queue with state machine
- [x] Exponential backoff with jitter
- [x] Dead letter queue for failed operations
- [x] Audit logging
- [x] Monitoring & observability
- [x] Background sync service
- [x] Base repository pattern
- [x] Bills repository implementation
- [x] Analytics dashboard
- [x] Responsive layout utilities
- [x] Unit tests for core components
- [ ] Integration tests (in progress)
- [ ] WorkManager integration (scaffolded)
- [ ] Complete all feature repositories

---

**Built with ❤️ by DukanX Engineering**
