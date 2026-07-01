# Sync Algorithm Documentation

## Overview
The synchronization system allows the Desktop App (Offline-First) and the Cloud Backend (AWS) to stay consistent. It uses a **Delta Sync** approach with a **Last-Write-Wins** conflict resolution strategy based on timestamps.

## 1. Push Strategy (Desktop -> Cloud)
**Objective**: Send local changes to the cloud.

### Trigger
- Background Timer (e.g., every 5 minutes).
- Event-based (e.g., immediately after saving a bill if online).
- Manual "Sync Now" button.

### Payload Structure
The client sends a JSON payload containing lists of modified entities.
```json
{
  "business_id": "UUID",
  "customers": [
    {
      "id": "UUID",
      "name": "John Doe",
      "updated_at": "2023-10-27T10:00:00Z",
      "is_deleted": false
    }
  ],
  "bills": [ ... ]
}
```

### Server Logic (Upsert)
For each received entity:
1.  **Check**: Does the record exist in DB?
2.  **Compare**:
    *   If `New`: Insert.
    *   If `Existing`: Compare `incoming.updated_at` vs `db.updated_at`.
    *   **Action**: Update ONLY if `incoming.updated_at > db.updated_at`.
3.  **Commit**: Save changes transactionally.

## 2. Pull Strategy (Cloud -> Desktop)
**Objective**: Fetch changes made by other devices (Mobile) or other Desktop instances.

### Request
The client requests changes that happened *after* its last successful sync.
```http
POST /api/v1/sync/pull
{
  "business_id": "UUID",
  "last_sync_timestamp": "2023-10-27T09:00:00Z"
}
```

### Server Logic
1.  Query DB for all records where:
    *   `business_id` == Requester Business.
    *   `updated_at` > `last_sync_timestamp`.
2.  Return lists of changed entities.

### Client Logic (Merge)
1.  Receive payload.
2.  For each entity:
    *   Update local DB.
    *   **Conflict Handling**: If local record has unsynced changes (dirty flag), Client can opt to:
        *   Keep local (ignore server).
        *   Overwrite local (accept server).
        *   Duplicate/Merge (User intervention).
    *   *Recommended default*: Overwrite if not currently being edited by user, otherwise warn.
3.  Update `last_sync_timestamp` to `server_timestamp` from response.

## 3. Conflict Resolution
**Strategy**: Last-Write-Wins (LWW).
-   We rely on `updated_at` precision.
-   The "Truth" is defined by the latest timestamp.
-   Deleted records are handled via `is_deleted` flag (Soft Delete) so deletions propagate.

## 4. Edge Cases
-   **Clock Drift**: Server timestamp is the authority for "Pull". Clients should sync their clocks or rely on relative time if possible, but standard UTC IS08601 is used here.
-   **Network Fail**: Sync is atomic per request. If fails, retry later. No partial data corruption on server (Acid Trans).
