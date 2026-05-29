# Offline Sync Conflict Resolution Strategy

## Overview

This document describes the conflict resolution strategy for DukanX offline-first synchronization. When multiple devices modify the same record while offline, conflicts must be resolved deterministically.

---

## Conflict Scenarios

### Scenario 1: Simultaneous Edit (Last-Write-Wins)

```
Device A: Updates IMEI status to "SOLD" at 10:00 AM (offline)
Device B: Updates same IMEI status to "IN_SERVICE" at 10:30 AM (offline)
Both sync at 11:00 AM
```

**Resolution**: Last write wins based on `updatedAt` timestamp.

### Scenario 2: Delete vs Update

```
Device A: Deletes invoice at 10:00 AM (soft delete, offline)
Device B: Updates same invoice at 10:30 AM (offline)
Both sync at 11:00 AM
```

**Resolution**: Delete wins. Device B's update is discarded with conflict log entry.

### Scenario 3: Field-Level Merge (Partial Update)

```
Device A: Updates "customerName" on service job (offline)
Device B: Updates "status" on same service job (offline)
Both sync at 11:00 AM
```

**Resolution**: Field-level merge. Both changes applied if on different fields.

### Scenario 4: Stock Decrement Conflict

```
Device A: Sells 5 units of Product X (offline)
Device B: Sells 3 units of Product X (offline)
Only 6 units available
```

**Resolution**: 
1. First sync succeeds (based on sync timestamp)
2. Second sync fails with "Insufficient stock" error
3. Manual resolution required

---

## Conflict Resolution Strategy

### 1. Timestamp-Based (Last-Write-Wins)

**Applies to**: Most entity types (Service Jobs, IMEI records, Invoices, Exchanges)

```dart
ResolutionResult resolveByTimestamp(LocalRecord local, ServerRecord server) {
  if (local.updatedAt > server.updatedAt) {
    return ResolutionResult.useLocal();
  } else {
    return ResolutionResult.useServer();
  }
}
```

**Pros**: Simple, deterministic  
**Cons**: May lose legitimate concurrent edits

### 2. Field-Level Merge

**Applies to**: Service Jobs, Complex entities with multiple fields

```dart
ResolutionResult resolveByMerge(LocalRecord local, ServerRecord server) {
  final merged = server.copyWith(
    // Fields modified locally only
    customerName: local.customerName != server.customerName 
        ? local.customerName 
        : server.customerName,
    // Status is protected - use timestamp
    status: local.updatedAt > server.updatedAt 
        ? local.status 
        : server.status,
  );
  return ResolutionResult.merged(merged);
}
```

**Pros**: Preserves non-conflicting changes  
**Cons**: Complex, requires field-level tracking

### 3. Business Logic Resolution

**Applies to**: Stock, Inventory, IMEI status

```dart
ResolutionResult resolveByBusinessLogic(LocalRecord local, ServerRecord server) {
  // IMEI status: SOLD takes precedence over IN_STOCK
  if (server.status == IMEISerialStatus.sold) {
    return ResolutionResult.useServer(); // Cannot un-sell
  }
  
  // Stock: Use sum if both added stock
  if (local.operation == 'ADD_STOCK' && server.operation == 'ADD_STOCK') {
    return ResolutionResult.mergeSum(local.quantity, server.quantity);
  }
  
  return resolveByTimestamp(local, server);
}
```

### 4. Manual Resolution Queue

**Applies to**: Irreconcilable conflicts

```dart
ResolutionResult resolveManually(LocalRecord local, ServerRecord server) {
  // Queue for manual review
  conflictQueue.add(ConflictRecord(
    local: local,
    server: server,
    entityType: 'Invoice',
    timestamp: DateTime.now(),
    autoResolved: false,
  ));
  
  // Use server version as safe default
  return ResolutionResult.useServer(pendingReview: true);
}
```

---

## Implementation

### Sync Queue Structure

```dart
class SyncQueueItem {
  final String id;
  final String entityType;
  final String entityId;
  final SyncOperation operation; // CREATE, UPDATE, DELETE
  final Map<String, dynamic> data;
  final DateTime localTimestamp;
  final int retryCount;
  final SyncStatus status;
}
```

### Conflict Detection

```dart
class ConflictDetector {
  static ConflictType detectConflict(SyncQueueItem local, ServerRecord server) {
    // 1. Check if server version is newer than local base
    if (server.updatedAt > local.baseVersionTimestamp) {
      // Server has changes since local edit started
      
      // 2. Check if same fields modified
      final localFields = local.data.keys.toSet();
      final serverFields = server.modifiedFields.toSet();
      
      if (localFields.intersection(serverFields).isEmpty) {
        return ConflictType.none; // Different fields, can merge
      }
      
      // 3. Check for incompatible states
      if (_isIncompatibleState(local.data, server)) {
        return ConflictType.businessLogic;
      }
      
      return ConflictType.timestamp;
    }
    
    return ConflictType.none;
  }
}
```

### Resolution Engine

```dart
class ConflictResolver {
  static ResolutionResult resolve(Conflict conflict) {
    switch (conflict.type) {
      case ConflictType.none:
        return ResolutionResult.merge(conflict.local, conflict.server);
        
      case ConflictType.timestamp:
        return _resolveByTimestamp(conflict);
        
      case ConflictType.fieldLevel:
        return _resolveByFieldMerge(conflict);
        
      case ConflictType.businessLogic:
        return _resolveByBusinessRules(conflict);
        
      case ConflictType.irreconcilable:
        return _queueForManualResolution(conflict);
    }
  }
}
```

---

## Entity-Specific Strategies

### IMEI/Serial Records

| Conflict Type | Strategy | Notes |
|--------------|----------|-------|
| Status change | Business Logic | SOLD > all other states |
| Customer link | Last-Write-Wins | Assignment can change |
| Warranty dates | Immutable | Never change after set |
| Soft delete | Wins over all | Deleted = gone |

### Service Jobs

| Conflict Type | Strategy | Notes |
|--------------|----------|-------|
| Status workflow | Business Logic | Forward flow only |
| Cost fields | Field-Level Merge | Different costs additive |
| Customer info | Last-Write-Wins | Contact info updates |
| Parts used | Merge | Append new parts |

### Invoices

| Conflict Type | Strategy | Notes |
|--------------|----------|-------|
| Line items | Manual Review | Too complex to auto-merge |
| Void/Delete | Immutable | Cannot un-void |
| Payment status | Last-Write-Wins | Payments appended |

### Exchange Records

| Conflict Type | Strategy | Notes |
|--------------|----------|-------|
| Value changes | Manual Review | Financial impact |
| Status | Last-Write-Wins | Standard workflow |
| Device condition | Last-Write-Wins | Inspection updates |

---

## Conflict Resolution UI

### Automatic Resolutions (Silent)

No UI needed for:
- Field-level merges on non-critical fields
- Timestamp-based resolution with < 1 minute difference
- Stock additions (sum strategy)

### User Notification Required

Show conflict resolution UI when:
- Invoice line items differ
- IMEI status conflict (sold vs returned)
- Delete vs Update conflict
- Stock oversell detected

### Resolution UI Flow

```
1. Detect conflict during sync
2. Attempt auto-resolution
3. If auto-fails:
   a. Pause sync for that entity
   b. Store in conflict queue
   c. Show notification badge
   d. Open resolution screen
4. User chooses:
   - Use My Version
   - Use Server Version  
   - Merge (if applicable)
5. Apply choice and resume sync
```

---

## Best Practices

### 1. Conflict Prevention

- Minimize offline edit window
- Lock records during critical operations
- Use optimistic locking (version numbers)

### 2. Data Integrity

- Never lose financial transactions
- Always log conflict resolutions
- Maintain audit trail

### 3. User Experience

- Explain conflicts in business terms
- Show previews of both versions
- Recommend resolution with reason

### 4. Recovery

- Allow manual override
- Support admin intervention
- Provide rollback capability

---

## Testing Scenarios

| Test Case | Expected Result |
|-----------|-----------------|
| Two devices edit different fields | Field-level merge succeeds |
| Device A deletes, B updates | Delete wins, B notified |
| Both sell last unit | First sync wins, second fails |
| Status conflict (Sold vs In-Service) | Sold wins, conflict logged |
| 50 concurrent offline edits | All resolve within 5 seconds |
| Network drop mid-sync | Resume from checkpoint |

---

## Configuration

```dart
class SyncConfig {
  // Auto-resolve if timestamp difference > threshold
  static const autoResolveThreshold = Duration(minutes: 5);
  
  // Always require manual review for these entities
  static const manualReviewEntities = [
    'Invoice',
    'WarrantyClaim',
    'Exchange',
  ];
  
  // Fields that never auto-merge
  static const protectedFields = [
    'status',
    'amount',
    'quantity',
    'isVoid',
    'deletedAt',
  ];
}
```

---

*Document Version: 1.0*  
*Last Updated: May 2026*  
*Applies to: All DukanX verticals*
