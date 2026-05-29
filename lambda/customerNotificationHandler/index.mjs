/**
 * customerNotificationHandler/index.mjs
 * Customer-facing notification routes:
 *   GET   /customer/v1/notifications              - list notifications
 *   PATCH /customer/v1/notifications/:id/read     - mark one as read
 *   PATCH /customer/v1/notifications/read-all     - mark all as read
 */

import {
  success,
  error,
  extractUserContext,
  queryItems,
  updateItem,
} from '../shared/utils.mjs';

const NOTIFICATIONS_TABLE =
  process.env.NOTIFICATIONS_TABLE || process.env.AUDIT_LOGS_TABLE;

export const handler = async (event) => {
  const method = event.requestContext.http.method;
  const path = event.requestContext.http.path;
  const ctx = await extractUserContext(event);

  if (!ctx || ctx.role !== 'customer') {
    return error(403, 'Forbidden', 'FORBIDDEN');
  }

  try {
    // PATCH /customer/v1/notifications/read-all
    if (method === 'PATCH' && path.endsWith('/read-all')) {
      return markAllRead(ctx);
    }

    // PATCH /customer/v1/notifications/:id/read
    const readMatch = path.match(/\/notifications\/([^/]+)\/read$/);
    if (method === 'PATCH' && readMatch) {
      return markRead(ctx, readMatch[1]);
    }

    // GET /customer/v1/notifications
    if (method === 'GET' && path.endsWith('/notifications')) {
      return listNotifications(ctx);
    }

    return error(404, 'Route not found', 'NOT_FOUND');
  } catch (e) {
    console.error('customerNotificationHandler error:', e);
    return error(500, 'Internal server error', 'INTERNAL_ERROR');
  }
};

async function listNotifications(ctx) {
  const items = await queryItems(
    NOTIFICATIONS_TABLE,
    'PK = :pk',
    { ':pk': `NOTIF#${ctx.userId}` },
    { ScanIndexForward: false, Limit: 50 },
  );

  const notifications = items.map(mapNotification);
  return success({ notifications });
}

async function markRead(ctx, notificationId) {
  const now = new Date().toISOString();

  await updateItem(
    NOTIFICATIONS_TABLE,
    {
      PK: `NOTIF#${ctx.userId}`,
      SK: `NOTIF#${notificationId}`,
    },
    'SET #isRead = :true, #readAt = :now',
    { '#isRead': 'isRead', '#readAt': 'readAt' },
    { ':true': true, ':now': now },
  );

  return success({ message: 'Marked as read' });
}

async function markAllRead(ctx) {
  const items = await queryItems(
    NOTIFICATIONS_TABLE,
    'PK = :pk',
    { ':pk': `NOTIF#${ctx.userId}` },
    {
      FilterExpression: 'isRead = :unread',
      ExpressionAttributeValues: { ':unread': false },
    },
  );

  const unread = items.filter((i) => !i.isRead);
  const now = new Date().toISOString();

  await Promise.all(
    unread.map((item) =>
      updateItem(
        NOTIFICATIONS_TABLE,
        { PK: item.PK, SK: item.SK },
        'SET #isRead = :true, #readAt = :now',
        { '#isRead': 'isRead', '#readAt': 'readAt' },
        { ':true': true, ':now': now },
      ),
    ),
  );

  return success({ updated: unread.length });
}

function mapNotification(item) {
  return {
    id: item.notificationId,
    customerId: item.customerId,
    vendorId: item.vendorId || null,
    vendorName: item.vendorName || null,
    category: item.category || 'system',
    title: item.title,
    body: item.body,
    payload: item.payload || null,
    isRead: item.isRead || false,
    createdAt: item.createdAt,
    readAt: item.readAt || null,
  };
}
