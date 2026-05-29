// ============================================================================
// School ERP — Notifications HTTP Façade (UNS-backed)
// ============================================================================
// Thin compatibility shim that preserves the legacy `/ac/notifications` HTTP
// surface but routes every read/write through the canonical Unified
// Notification System (UNS).
//
// Legacy storage (`PK = NOTIF#<userId>`, raw DDB writes from inside this
// helper) has been removed: the helper now delegates to:
//
//   - `getDefaultNotificationService().createNotification(...)` for emits
//     (the internal `pushNotification` exported below)
//   - `Notification_Store.listByUserStatus(...)` for the GET listing
//   - `getDefaultNotificationService().markAsRead(...)` for the read /
//     read-all routes
//
// The HTTP route signatures and response envelopes are intentionally
// unchanged so existing school clients (`school_admin_app`,
// `school_teacher_app`, `school_student_app`) continue to work without
// any client-side change.
//
// Migration: task 14.7 of `unified-notification-system`. The producer-side
// migration of individual T-SCH-* trigger points (school-admissions.ts,
// school-fees.ts, school-attendance.ts, etc.) lands in task 14.9 — those
// callers will progressively pass canonical `event_name`/`priority`/
// `recipients` through the extended `pushNotification` signature exposed
// here.
//
// Validates: REQ 10.7 (single canonical path for school helper),
//            REQ 10.8 (Trigger_Points wired through the service),
//            REQ 10.9 (recipient/channel/body parity preserved),
//            REQ 19.5 (single active path per Trigger_Point).
// ============================================================================

import { APIGatewayProxyHandlerV2 } from 'aws-lambda';
import {
  getDefaultNotificationService,
  NotificationNotFoundError,
} from '../../../notifications/service';
import { listByUserStatus } from '../../../notifications/store';
import type {
  NotificationCategory,
  NotificationChannel,
  NotificationPriority,
  NotificationRecord,
  NotificationStatus,
} from '../../../notifications/store';
import type {
  Recipient as EventBusRecipient,
  RecipientRole,
  SourceApp,
} from '../../../notifications/event-bus/types';
import { logger } from '../../../utils/logger';

// ---------------------------------------------------------------------------
// HTTP helpers — unchanged response envelope from the legacy handler so
// clients see the same Content-Type / CORS headers / body shape.
// ---------------------------------------------------------------------------

const ok = (body: unknown, status = 200) => ({
  statusCode: status,
  headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
  body: JSON.stringify(body),
});

const err = (msg: string, status = 400) => ({
  statusCode: status,
  headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
  body: JSON.stringify({ message: msg }),
});

// ---------------------------------------------------------------------------
// Constants / mapping helpers
// ---------------------------------------------------------------------------

const SOURCE_MODULE =
  'my-backend/src/handlers/modules/school-erp/school-notifications.ts';
const SOURCE_APP: SourceApp = 'dukanx_backend';

/**
 * The five non-`read` lifecycle states. The `unread` filter in the legacy
 * GET route maps to "any of these statuses" on the new store.
 */
const UNREAD_STATUSES: readonly NotificationStatus[] = [
  'emitted',
  'queued',
  'dispatched',
  'delivered',
  'failed',
] as const;

/**
 * The full lifecycle status set. Used when the caller wants every
 * notification (read + unread).
 */
const ALL_STATUSES: readonly NotificationStatus[] = [
  ...UNREAD_STATUSES,
  'read',
] as const;

const VALID_CATEGORIES: ReadonlySet<NotificationCategory> = new Set([
  'billing',
  'orders',
  'payments',
  'inventory',
  'users',
  'system',
  'delivery',
  'reports',
]);

/**
 * Map the free-form legacy `payload.category` string onto a canonical
 * `NotificationCategory`. Unknown categories collapse to `users` because
 * every school event registered in `phase2-event-registry.md` lives under
 * the `users` (school_*) bucket except fees (`billing.school_fee.*`) and
 * exam reports (`reports.school_exam.*`).
 */
function mapCategory(raw: string | undefined): NotificationCategory {
  if (!raw) return 'users';
  const lower = raw.trim().toLowerCase();
  return VALID_CATEGORIES.has(lower as NotificationCategory)
    ? (lower as NotificationCategory)
    : 'users';
}

/**
 * Build the response shape the legacy clients still expect. The new
 * `NotificationRecord` is richer than the old item; we expose the
 * fields legacy callers actually consumed plus a small set of new
 * canonical fields so school sub-app screens can begin reading them
 * without breaking.
 */
function toLegacyItem(record: NotificationRecord, userId: string) {
  // Find the per-recipient row for this user, if present, so per-user
  // delivered_at / read_at survive the projection.
  const mine = record.recipients.find((r) => r.user_id === userId);
  const isRead = mine ? mine.read_at !== null : record.status === 'read';
  const payload = record.payload ?? {};

  return {
    id: record.notification_id,
    userId,
    title: typeof payload.title === 'string' ? payload.title : '',
    body: typeof payload.body === 'string' ? payload.body : '',
    category: record.category,
    metadata: payload,
    isRead,
    createdAt: record.created_at,
    // New canonical fields — exposed for forward compatibility but optional
    // for legacy consumers.
    eventName: record.event_name,
    priority: record.priority,
    deliveredAt: mine?.delivered_at ?? record.delivered_at,
    readAt: mine?.read_at ?? record.read_at,
  };
}

// ---------------------------------------------------------------------------
// HTTP handler
// ---------------------------------------------------------------------------

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  const method = event.requestContext.http.method;
  const path = event.rawPath;
  const claims = (event.requestContext as any).authorizer?.jwt?.claims ?? {};
  const userId: string = claims.sub ?? '';
  const params = event.queryStringParameters ?? {};

  if (!userId) {
    return err('Unauthenticated', 401);
  }

  try {
    // -------------------------------------------------------------------
    // GET /ac/notifications  (?unread=true&limit=N)
    // -------------------------------------------------------------------
    if (method === 'GET' && path === '/ac/notifications') {
      const unreadOnly = params.unread === 'true';
      const limit = Math.max(1, Math.min(parseInt(params.limit ?? '30', 10) || 30, 100));

      const statuses = unreadOnly ? UNREAD_STATUSES : ALL_STATUSES;

      // The new store partitions by `(user_id, status)`, so we have to
      // walk every status partition the legacy listing covered. We cap
      // the per-status fetch at `limit` and merge — for the typical
      // school client (~30 items) this is one round-trip per status.
      const collected: NotificationRecord[] = [];
      for (const status of statuses) {
        const page = await listByUserStatus({
          user_id: userId,
          status,
          limit,
          scanForward: false, // newest first
        });
        for (const item of page.items) {
          collected.push(item);
        }
      }

      // Newest first, then trim to the requested page size.
      collected.sort((a, b) => b.created_at.localeCompare(a.created_at));
      const items = collected.slice(0, limit).map((r) => toLegacyItem(r, userId));
      const unreadCount = items.filter((i) => !i.isRead).length;

      return ok({ items, unreadCount });
    }

    // -------------------------------------------------------------------
    // PUT /ac/notifications/{notificationId}/read
    // -------------------------------------------------------------------
    if (method === 'PUT' && path.includes('/read') && !path.includes('/read-all')) {
      // Path layout: /ac/notifications/{id}/read
      const segments = path.split('/').filter(Boolean);
      const notifId = segments[2] ?? '';
      if (!notifId) {
        return err('Missing notification id', 400);
      }

      try {
        await getDefaultNotificationService().markAsRead(notifId, userId);
      } catch (e) {
        if (e instanceof NotificationNotFoundError) {
          return err('Notification not found', 404);
        }
        throw e;
      }
      return ok({ message: 'Marked as read' });
    }

    // -------------------------------------------------------------------
    // PUT /ac/notifications/read-all
    // -------------------------------------------------------------------
    if (method === 'PUT' && path === '/ac/notifications/read-all') {
      const service = getDefaultNotificationService();

      // Walk every non-read status partition for the user, paginate
      // through the cursor, and call `markAsRead` for each record.
      let count = 0;
      for (const status of UNREAD_STATUSES) {
        let cursor: string | null | undefined = null;
        // The store caps each page at 50; loop until the partition empties.
        // The school client typically has < 100 unread items, so this is
        // bounded in practice.
        // eslint-disable-next-line no-constant-condition
        while (true) {
          const page = await listByUserStatus({
            user_id: userId,
            status,
            cursor,
            scanForward: false,
          });
          for (const record of page.items) {
            try {
              await service.markAsRead(record.notification_id, userId);
              count += 1;
            } catch (e) {
              if (e instanceof NotificationNotFoundError) {
                // Race: record evicted between list and mark — ignore.
                continue;
              }
              throw e;
            }
          }
          if (!page.next_cursor) break;
          cursor = page.next_cursor;
        }
      }

      return ok({ message: 'All notifications marked as read', count });
    }

    return err('Not found', 404);
  } catch (e: any) {
    logger.error('school-notifications error', {
      method,
      path,
      user_id: userId,
      error: e instanceof Error ? e.message : String(e),
    });
    return err(e?.message ?? 'Internal server error', 500);
  }
};

// ---------------------------------------------------------------------------
// Internal emit helper — backwards-compatible signature
// ---------------------------------------------------------------------------

/**
 * Optional canonical-emit overrides. Producers that have been migrated to
 * the registry-defined `event_name` populate these fields; producers that
 * have not yet been migrated (still on task 14.9 backlog) call the helper
 * with only the legacy `{ title, body, category, metadata }` shape and
 * the helper synthesises sensible defaults.
 */
export interface PushNotificationOverrides {
  /** Canonical event name (`<domain>.<entity>.<action>`). */
  event_name?: string;
  /** Priority tier; defaults to `normal`. */
  priority?: NotificationPriority;
  /** Channels to deliver on; defaults to `['in_app']`. */
  channels?: readonly NotificationChannel[];
  /**
   * Recipient list. Defaults to a single recipient `{ user_id: <userId>,
   * role: 'student', channels: <channels> }` so the legacy single-user
   * push semantics are preserved when the caller does not know the
   * canonical recipient set yet.
   */
  recipients?: readonly EventBusRecipient[];
  /** Sub-category hint (e.g. `attendance`, `homework`). */
  sub_category?: string;
  /** Optional target id (e.g. fee_id, homework_id). */
  target_id?: string | null;
  /** Optional actor id; defaults to `system`. */
  actor_id?: string;
}

export interface PushNotificationPayload {
  title: string;
  body: string;
  category: string;
  metadata?: Record<string, unknown>;
}

/**
 * Push a notification to a user (called internally by other school-erp
 * handlers). This is a compatibility shim for the legacy callers that
 * still emit through this helper; it routes every emit through the
 * canonical Notification_Service so the new store and lifecycle fire
 * unchanged.
 *
 * Producers that have a canonical `event_name` SHOULD pass the third
 * argument; producers that have not yet been migrated continue to
 * pass `(userId, payload)` only and we synthesise a `users.school_legacy.notified`
 * event so the record remains schema-valid.
 */
export async function pushNotification(
  userId: string,
  payload: PushNotificationPayload,
  overrides: PushNotificationOverrides = {},
): Promise<{ notification_id: string }> {
  const service = getDefaultNotificationService();

  const channels: readonly NotificationChannel[] =
    overrides.channels && overrides.channels.length > 0
      ? overrides.channels
      : ['in_app'];

  const recipients: readonly EventBusRecipient[] =
    overrides.recipients && overrides.recipients.length > 0
      ? overrides.recipients
      : [
          {
            user_id: userId,
            role: 'student' as RecipientRole,
            channels: [...channels],
          },
        ];

  const event_name = overrides.event_name ?? 'users.school_legacy.notified';
  const category = mapCategory(payload.category);
  const priority: NotificationPriority = overrides.priority ?? 'normal';
  const actor_id = overrides.actor_id ?? 'system';

  // The service expects payload to be a JSON-serialisable record. We
  // merge the legacy `{title, body}` with any caller-provided metadata
  // so existing renderers (drawer, toast, push templates) keep working.
  const mergedPayload: Record<string, unknown> = {
    title: payload.title,
    body: payload.body,
    ...(payload.metadata ?? {}),
  };

  const result = await service.createNotification(
    {
      event_name,
      category,
      sub_category: overrides.sub_category,
      priority,
      actor_id,
      target_id: overrides.target_id ?? null,
      recipients,
      payload: mergedPayload,
      channels,
      source_module: SOURCE_MODULE,
      source_app: SOURCE_APP,
    },
    {
      // The legacy helper is invoked from internal lambdas that act on
      // behalf of the system — the default caller-authoriser permits the
      // `system` role to emit for itself.
      user_id: actor_id,
      role: actor_id === 'system' ? 'system' : 'staff',
    },
  );

  logger.info('[school-notifications] pushNotification → UNS', {
    notification_id: result.notification_id,
    event_name,
    user_id: userId,
    category,
    priority,
  });

  return { notification_id: result.notification_id };
}
