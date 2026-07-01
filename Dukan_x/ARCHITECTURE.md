# DukanX System Architecture

> **Strictly Enforced Architecture**
> 
> **LOCAL STORAGE (Offline-First)** → **REPOSITORY LAYER** → **FIRESTORE DATABASE (Cloud Sync)**

This document serves as the **Single Source of Truth** for the application architecture. All new features MUST adhere to these patterns.

## 1. Core Architecture Rules
1.  **Offline-First**: The app must function 100% without internet.
2.  **Single Source of Truth**: The `Local Database` (Drift/SQLite) is the source of truth for the UI.
3.  **No Direct Firestore**: The UI **NEVER** speaks to Firestore directly.
4.  **Repository Pattern**: All data access is mediated by Repositories extending `BaseRepository`.
5.  **Sync Engine**: Changes are pushed to Firestore via `SyncManager` in the background.

---

## 2. Data Flow

### Write Flow (e.g., Create Order)
1.  **UI**: User saves an Order.
2.  **Repo**: `OrderRepository.createOrder(order)` is called.
3.  **Local DB**: Order is saved to SQLite immediately.
4.  **UI**: Updates instantly (reactive stream from SQLite).
5.  **Sync**: Repository creates a `SyncQueueItem` (payload: Order JSON) and enqueues it.
6.  **Background**: `SyncManager` picks up the item (when online).
7.  **Cloud**: `SyncManager` pushes data to Firestore.
8.  **Status**: On success, `isSynced` flag in Local DB is set to `true`.

### Read Flow
1.  **UI**: Subscribes to `Stream<List<Order>>` from Repository.
2.  **Repo**: Returns stream from `AppDatabase` (Drift DAO).
3.  **Background**: `FirestoreListener` detects remote changes.
4.  **Sync**: `SyncManager` updates Local DB with new data.
5.  **Reflect**: Local DB update triggers the stream, updating the UI automatically.

---

## 3. Database Schemas

### A. Local Schema (Drift/SQLite)
*See `lib/core/database/app_database.dart`*

All tables must include basic sync metadata:
```dart
  TextColumn get id => text()();
  TextColumn get userId => text()(); // Owner ID
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()(); // Soft Delete
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();
```

### B. Firestore Schema (Cloud)
*Root Collection: `users` or `vendors` (based on auth)*

Structure:
```
vendors/{userId}
  ├── customers/{customerId}
  ├── products/{productId}
  ├── bills/{billId}
  ├── expenses/{expenseId}
  ├── ...
```
*Note: We use subcollections under the User/Vendor ID to ensure strict data isolation.*

---

## 4. Repository Layer
*See `lib/core/repository/base_repository.dart`*

Every feature must have a Repository that extends `BaseRepository<T>`.

**Responsibilities:**
-   `insertLocal(T entity)`
-   `updateLocal(T entity)`
-   `softDeleteLocal(String id)`
-   `enqueSync(OperationType type, T entity)` (Provided by Base)

---

## 5. Sync Logic
*See `lib/core/sync/sync_manager.dart`*

**Key Features:**
-   **Queue-Based**: Operations are queued sequentially.
-   **Retry Mechanism**: Exponential backoff for failed syncs.
-   **Conflict Resolution**:
    -   Server Wins (Time-based / Version-based).
    -   Conflicts are logged and can be resolved manually if needed.
-   **Dead Letter Queue**: Operations failing > Max Retries are moved here for manual inspection.

---

## 6. Security (Roles & Rules)
*See `firestore.rules`*

-   **Owner Only**: `request.auth.uid == userId`
-   **Role Based**: Checks against `request.auth.token.roles` if applicable.

---
**Status Indicators:**
-   🟢 Synced (All good)
-   🟡 Syncing (In progress)
-   🔴 Failed (Retry scheduled)
