// ============================================================================
// Object_Store — S3 equivalent (Requirement 4.5)
// ============================================================================
// Content-addressed binary store that is the offline equivalent of Amazon S3.
// It stores, retrieves, and deletes binary objects addressed by a unique object
// key inside a structured local filesystem location under the DukanX data dir,
// and returns stored content BYTE-FOR-BYTE unchanged (Req 4.5, Property 18).
//
// Design notes:
//   - Objects are addressed by an opaque string key. The on-disk path is always
//     derived from SHA-256(key) and sharded (objects/<aa>/<bb>/<hash>), so:
//       * arbitrary key strings can never escape the store root (no path
//         traversal — keys are never used as raw path segments), and
//       * the layout is fixed-width and evenly distributed.
//   - `putContentAddressed` derives the key from SHA-256(content) for true
//     content addressing; callers that already own a unique key use `put`.
//   - Writes go through a temp file in the destination directory followed by an
//     atomic rename, so a successful `put` is all-or-nothing at the filesystem
//     level and never leaves a half-written object. On failure the temp file is
//     rolled back and the failure is reported to the service layer as a typed
//     `StoreError` (Req 4.7, task 8.3). Reads/deletes that genuinely fail are
//     likewise reported, while expected outcomes (missing key on get → throws
//     `ObjectNotFoundError`; delete of a missing key → returns false) are not
//     treated as failures.
// ============================================================================

import { createHash } from 'crypto';
import { promises as fs } from 'fs';
import { join } from 'path';
import {
    OBJECT_STORE_DIR_NAME,
    resolveDukanxDataDir,
} from '../config/constants';
import { logger, maskKey } from '../utils/logger';
import { StoreError, describeError } from './storage-errors';

/** Result of a store operation. */
export interface PutResult {
    /** The key under which the object can be retrieved. */
    key: string;
    /** Number of bytes written. */
    size: number;
}

/** Thrown when a requested object key does not exist in the store. */
export class ObjectNotFoundError extends Error {
    constructor(public readonly key: string) {
        super(`Object not found for key: ${key}`);
        this.name = 'ObjectNotFoundError';
    }
}

/** Thrown when an operation is called with an invalid key or payload. */
export class InvalidObjectError extends Error {
    constructor(message: string) {
        super(message);
        this.name = 'InvalidObjectError';
    }
}

/**
 * Content-addressed binary Object_Store.
 *
 * Instances are cheap; the root directory is resolved once at construction and
 * created lazily on first write. Pass an explicit `rootDir` for tests or custom
 * install locations; otherwise the OS-specific DukanX data dir is used.
 */
export class ObjectStore {
    /** Absolute path to the directory that holds all stored objects. */
    public readonly rootDir: string;

    constructor(rootDir?: string) {
        this.rootDir = rootDir ?? join(resolveDukanxDataDir(), OBJECT_STORE_DIR_NAME);
    }

    // ── Public API ──────────────────────────────────────────────────────────

    /**
     * Store `data` under the supplied unique `key`. If an object already exists
     * for the key it is overwritten atomically. Returns the key and byte count.
     *
     * On any I/O failure the temp file is rolled back (no partial object remains)
     * and the failure is reported to the service layer as a {@link StoreError}
     * (Req 4.7). Invalid arguments still surface as {@link InvalidObjectError}.
     */
    async put(key: string, data: Buffer): Promise<PutResult> {
        this.assertValidKey(key);
        this.assertValidData(data);

        const objectPath = this.pathForKey(key);
        try {
            await this.writeAtomic(objectPath, data);
        } catch (err) {
            // writeAtomic already removed the temp file, so nothing partial is
            // left on disk. Report the failure to the service layer.
            throw this.report('put', key, err);
        }
        return { key, size: data.length };
    }

    /**
     * Store `data` under a key derived from its content (SHA-256 hex). Identical
     * content always yields the same key, making this a true content-addressed
     * write. Returns the derived key and byte count.
     */
    async putContentAddressed(data: Buffer): Promise<PutResult> {
        this.assertValidData(data);
        const key = createHash('sha256').update(data).digest('hex');
        return this.put(key, data);
    }

    /**
     * Retrieve the object stored under `key`, returning its bytes byte-for-byte
     * unchanged. Throws {@link ObjectNotFoundError} if no such object exists
     * (an expected outcome, not a failure). Any other I/O failure is reported to
     * the service layer as a {@link StoreError} (Req 4.7).
     */
    async get(key: string): Promise<Buffer> {
        this.assertValidKey(key);
        const objectPath = this.pathForKey(key);
        try {
            return await fs.readFile(objectPath);
        } catch (err) {
            if (isNotFound(err)) {
                throw new ObjectNotFoundError(key);
            }
            // A genuine read failure (permissions, corruption, etc.). A read
            // mutates nothing, so there is no partial state to roll back; just
            // report it to the service layer.
            throw this.report('get', key, err);
        }
    }

    /** Returns true if an object is stored under `key`. */
    async has(key: string): Promise<boolean> {
        this.assertValidKey(key);
        try {
            await fs.access(this.pathForKey(key));
            return true;
        } catch (err) {
            if (isNotFound(err)) {
                return false;
            }
            throw err;
        }
    }

    /**
     * Delete the object stored under `key`. Idempotent: returns true if an
     * object was removed, false if there was nothing to remove (an expected
     * outcome, not a failure). Any other I/O failure is reported to the service
     * layer as a {@link StoreError}; a failed unlink leaves the existing object
     * intact, so no partial state results (Req 4.7).
     */
    async delete(key: string): Promise<boolean> {
        this.assertValidKey(key);
        const objectPath = this.pathForKey(key);
        try {
            await fs.unlink(objectPath);
            return true;
        } catch (err) {
            if (isNotFound(err)) {
                return false;
            }
            throw this.report('delete', key, err);
        }
    }

    // ── Internals ─────────────────────────────────────────────────────────────

    /**
     * Map an opaque key to a safe, structured on-disk path. The filename is
     * SHA-256(key) sharded by its first two byte-pairs, guaranteeing the key can
     * never traverse outside the store root regardless of its contents.
     */
    private pathForKey(key: string): string {
        const hash = createHash('sha256').update(key, 'utf8').digest('hex');
        return join(this.rootDir, hash.slice(0, 2), hash.slice(2, 4), hash);
    }

    /**
     * Write `data` to `destPath` atomically: stream into a unique temp file in
     * the same directory, then rename over the destination. On any failure the
     * temp file is removed so NO partial object remains on disk — this is the
     * rollback half of Requirement 4.7. The thrown cause is re-raised for
     * {@link put} to translate into a service-layer {@link StoreError}.
     */
    private async writeAtomic(destPath: string, data: Buffer): Promise<void> {
        const dir = join(destPath, '..');
        await fs.mkdir(dir, { recursive: true });

        const tempPath = `${destPath}.${process.pid}.${Date.now()}.${randomSuffix()}.tmp`;
        try {
            await fs.writeFile(tempPath, data, { flag: 'w' });
            await fs.rename(tempPath, destPath);
        } catch (err) {
            // Roll back: remove the temp file so a failed write leaves nothing
            // partial behind. Cleanup is best-effort and must not mask the
            // original cause, which is propagated to the caller.
            await fs.rm(tempPath, { force: true }).catch((cleanupErr) => {
                logger.warn('Object_Store temp-file rollback could not remove temp file', {
                    cleanupError: describeError(cleanupErr),
                });
            });
            throw err;
        }
    }

    /**
     * Translate a raw failure into the service-layer {@link StoreError} contract
     * (Req 4.7). Logs through the secret-scrubbing logger so keys/paths never
     * leak, then returns the typed error for the caller to throw.
     */
    private report(operation: 'put' | 'get' | 'delete', key: string, cause: unknown): StoreError {
        logger.error('Object_Store operation failed', {
            operation,
            // Never log the raw object key — it may encode caller-sensitive
            // identifiers. Mask it the same way secrets are masked elsewhere.
            key: maskKey(key),
            cause: describeError(cause),
        });
        return new StoreError(operation, key, cause);
    }

    private assertValidKey(key: string): void {
        if (typeof key !== 'string' || key.length === 0) {
            throw new InvalidObjectError('Object key must be a non-empty string');
        }
    }

    private assertValidData(data: Buffer): void {
        if (!Buffer.isBuffer(data)) {
            throw new InvalidObjectError('Object data must be a Buffer');
        }
    }
}

// ── Module helpers ──────────────────────────────────────────────────────────

/** Narrowing helper for ENOENT (missing file) errors from fs. */
function isNotFound(err: unknown): boolean {
    return (
        typeof err === 'object' &&
        err !== null &&
        (err as NodeJS.ErrnoException).code === 'ENOENT'
    );
}

/** Short random suffix to keep concurrent temp filenames unique. */
function randomSuffix(): string {
    return Math.random().toString(36).slice(2, 10);
}
