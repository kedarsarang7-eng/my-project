// ============================================================================
// Storage Errors — the failure-reporting contract to the service layer
// ============================================================================
// Requirement 4.7: if a local-equivalent store/retrieve/enqueue/dequeue
// operation fails, the Local_Backend SHALL report the failure to the service
// layer AND SHALL NOT leave a partially written object or message behind.
//
// This module defines the "report to the service layer" half of that contract.
// The Object_Store (S3 equivalent, task 8.1) and the Local_Queue (SQS/SNS
// equivalent, task 8.2) already roll back partial state at their seams — the
// Object_Store via temp-file + atomic rename, the Local_Queue via a SQLite
// transaction that rolls back on throw. Task 8.3 surfaces those failures as a
// single, typed, catchable error family so the calling service layer can react
// uniformly instead of guessing at raw `fs`/`better-sqlite3` error shapes.
//
// Contract:
//   - Expected, non-failure outcomes are NEVER thrown here:
//       * Object_Store "key not found"      → ObjectNotFoundError / get throws it
//       * Object_Store delete of missing key → returns false
//       * Local_Queue dequeue of empty topic → returns null
//   - Genuine operation failures (I/O error, rename failure, SQL/transaction
//     failure, etc.) are reported as a StorageError subclass AFTER the
//     operation has rolled back any partial state.
// ============================================================================

/** The local-equivalent operations covered by Requirement 4.7. */
export type StorageOperation = 'put' | 'get' | 'delete' | 'enqueue' | 'dequeue';

/**
 * Base class for every storage failure reported to the service layer. Carries
 * the failed {@link StorageOperation}, a stable machine-readable {@link code}
 * (parity with the AWS error envelope), and the originating cause.
 */
export class StorageError extends Error {
    /** Which local-equivalent operation failed. */
    public readonly operation: StorageOperation;
    /** Stable machine-readable error code for the service layer to branch on. */
    public readonly code: string;

    constructor(
        message: string,
        operation: StorageOperation,
        code: string,
        cause?: unknown,
    ) {
        super(message, cause !== undefined ? { cause } : undefined);
        this.name = 'StorageError';
        this.operation = operation;
        this.code = code;
        // Preserve the instanceof chain across compiled targets.
        Object.setPrototypeOf(this, new.target.prototype);
    }
}

/**
 * Reported when an Object_Store put/get/delete fails. By the time this is
 * thrown the store has already cleaned up any temp file, so no partial object
 * remains on disk (Req 4.7).
 */
export class StoreError extends StorageError {
    /** Code shared by all Object_Store failures. */
    static readonly CODE = 'OBJECT_STORE_FAILED';
    /** The object key whose operation failed. */
    public readonly key: string;

    constructor(operation: 'put' | 'get' | 'delete', key: string, cause?: unknown) {
        super(
            `Object_Store ${operation} failed for key "${key}"`,
            operation,
            StoreError.CODE,
            cause,
        );
        this.name = 'StoreError';
        this.key = key;
        Object.setPrototypeOf(this, StoreError.prototype);
    }
}

/**
 * Reported when a Local_Queue enqueue/dequeue fails. By the time this is thrown
 * the surrounding SQLite transaction has rolled back, so no message was left
 * half-enqueued and none was removed without being returned (Req 4.7).
 */
export class QueueError extends StorageError {
    /** Code shared by all Local_Queue failures. */
    static readonly CODE = 'LOCAL_QUEUE_FAILED';
    /** The topic whose operation failed. */
    public readonly topic: string;

    constructor(operation: 'enqueue' | 'dequeue', topic: string, cause?: unknown) {
        super(
            `Local_Queue ${operation} failed for topic "${topic}"`,
            operation,
            QueueError.CODE,
            cause,
        );
        this.name = 'QueueError';
        this.topic = topic;
        Object.setPrototypeOf(this, QueueError.prototype);
    }
}

/** Safely extract a human-readable message from an unknown thrown value. */
export function describeError(err: unknown): string {
    if (err instanceof Error) return err.message;
    return String(err);
}
