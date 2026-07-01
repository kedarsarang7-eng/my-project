// ============================================================================
// Session_Registry — per-user active session tracking (offline, in-process)
// ============================================================================
// Requirement 9.6: when a user's role changes, EXACTLY that user's active
// sessions are invalidated (no other user's sessions are touched) and that user
// must re-authenticate before any further action.
//
// The Offline_Auth_Service issues an RS256 local JWT that carries `sub` (the
// user id) and an optional `sessionId` claim — the design explicitly reserves
// that `sessionId` for "targeted session invalidation" by this task. This
// registry is the authority the verify path consults: a token is only honoured
// while its (userId, sessionId) pair is still registered as active.
//
// Implementation: a registry keyed by userId so revocation is surgically scoped
// to a single user. Each user maps to the set of its currently-active session
// ids. Invalidating a user clears ONLY that user's entry, leaving every other
// user's sessions intact (Req 9.6). This is the "session registry keyed by
// userId" option from the design.
//
// In-process and synchronous: the Local_Backend is a single packaged process,
// so an in-memory registry is sufficient and keeps the verify path allocation-
// free and deterministic for property testing (Property 19, task 9.6).
// ============================================================================

import { randomUUID } from 'crypto';

/** A minted session — the identity the auth token is bound to. */
export interface SessionRecord {
    /** The user this session belongs to. */
    userId: string;
    /** Opaque session id placed into the JWT `sessionId` claim. */
    sessionId: string;
    /** The role captured at session creation (informational/auditing). */
    role: string;
    /** Tenant the session belongs to. */
    tenantId: string;
    /** Creation time, ms since epoch. */
    createdAt: number;
}

/**
 * Session_Registry — tracks active sessions per user and supports targeted,
 * per-user invalidation. All operations are O(1) on the user key.
 */
export class SessionRegistry {
    /** userId → (sessionId → SessionRecord). */
    private readonly byUser = new Map<string, Map<string, SessionRecord>>();

    /**
     * Create and register a new active session for a user, returning the record
     * (whose `sessionId` the caller embeds in the issued JWT). A fresh random
     * session id is generated unless one is supplied (supplying one is useful in
     * tests for determinism).
     */
    createSession(
        userId: string,
        tenantId: string,
        role: string,
        sessionId: string = randomUUID(),
    ): SessionRecord {
        if (!userId || !tenantId) {
            throw new Error('userId and tenantId are required to create a session.');
        }
        const record: SessionRecord = {
            userId,
            sessionId,
            role,
            tenantId,
            createdAt: Date.now(),
        };
        let sessions = this.byUser.get(userId);
        if (!sessions) {
            sessions = new Map<string, SessionRecord>();
            this.byUser.set(userId, sessions);
        }
        sessions.set(sessionId, record);
        return record;
    }

    /**
     * Is the (userId, sessionId) pair currently active? The verify path calls
     * this AFTER cryptographically verifying the token: a structurally valid but
     * revoked session (e.g. after a role change) returns false and forces
     * re-authentication (Req 9.6).
     */
    isSessionActive(userId: string, sessionId: string | undefined): boolean {
        if (!userId || !sessionId) return false;
        return this.byUser.get(userId)?.has(sessionId) ?? false;
    }

    /**
     * Invalidate EXACTLY one user's active sessions (Req 9.6). Returns the count
     * of sessions revoked. Other users' sessions are never affected — the method
     * only ever deletes the single keyed entry.
     */
    invalidateUserSessions(userId: string): number {
        const sessions = this.byUser.get(userId);
        if (!sessions) return 0;
        const revoked = sessions.size;
        this.byUser.delete(userId);
        return revoked;
    }

    /**
     * Invalidate a single session (e.g. on explicit logout) without touching the
     * user's other sessions. Returns true if a session was removed.
     */
    invalidateSession(userId: string, sessionId: string): boolean {
        const sessions = this.byUser.get(userId);
        if (!sessions) return false;
        const removed = sessions.delete(sessionId);
        if (removed && sessions.size === 0) {
            this.byUser.delete(userId);
        }
        return removed;
    }

    /** Number of active sessions for a user (0 if none). */
    activeSessionCount(userId: string): number {
        return this.byUser.get(userId)?.size ?? 0;
    }

    /** Snapshot of a user's active session ids (empty if none). */
    activeSessionIds(userId: string): string[] {
        const sessions = this.byUser.get(userId);
        return sessions ? Array.from(sessions.keys()) : [];
    }
}
