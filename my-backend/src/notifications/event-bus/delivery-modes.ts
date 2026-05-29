// ============================================================================
// UNS Event_Bus — Delivery Modes
// ============================================================================
// Maps a notification's `priority` to the bus-level delivery semantics:
//   - `critical` / `high`  → `at_least_once`
//   - `normal`   / `low`   → `at_most_once_with_dedup`
//
// Important: the *Event_Bus* applies the at-least-once vs. at-most-once
// transport guarantee. The deduplication step that turns at_most_once into
// effective once-per-recipient is performed by the Notification_Service via
// the `by-dedup-key` GSI lookup on the Notification_Store, NOT by this
// module. See `phase3-architecture.md` §6.2 ("Effective-exactly-once at the
// recipient") and §7.3 ("Deduplication step") for the divided
// responsibility.
//
// Validates: REQ 3.7 (at_least_once for critical/high),
//            REQ 3.8 (at_most_once_with_dedup for normal/low),
//            REQ 9.1, 9.2.
// ============================================================================

import type { DeliveryMode, Priority } from './types';

/**
 * Pure function returning the delivery mode for a given priority tier.
 *
 * The mapping is exhaustive over the four-element `Priority` union, which is
 * why the function returns a non-nullable `DeliveryMode`. If a future
 * priority literal is introduced, TypeScript's exhaustiveness check on the
 * `default` branch will surface the gap at compile time.
 */
export function getDeliveryMode(priority: Priority): DeliveryMode {
    switch (priority) {
        case 'critical':
        case 'high':
            return 'at_least_once';
        case 'normal':
        case 'low':
            return 'at_most_once_with_dedup';
        default: {
            // Exhaustiveness guard: unreachable when `Priority` is up to date.
            const _exhaustive: never = priority;
            void _exhaustive;
            return 'at_least_once';
        }
    }
}

/**
 * SQS `MessageDeduplicationId` is only honored by FIFO queues. The bus uses
 * standard queues, so dedup is performed at the Notification_Service layer.
 * This helper is exported to make the contract explicit at call sites and to
 * give future FIFO migrations a single place to flip the behavior.
 */
export function shouldUseFifoDedup(_priority: Priority): boolean {
    // Standard SQS today; no FIFO dedup. Notification_Service handles dedup.
    return false;
}
