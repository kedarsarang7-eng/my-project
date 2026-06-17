// ============================================================================
// ACADEMIC COACHING — INTERNAL MESSAGING MODULE
// ============================================================================
// Staff/faculty communication system
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole, BusinessType } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import {
  Keys,
  putItem,
  getItem,
  updateItem,
  queryAllItems,
} from '../config/dynamodb.config';
import { broadcastToStaff } from '../services/websocket.service';
import { WSEventName } from '../types/websocket.types';

const AC_MESSAGING_OPTS = {
  requiredBusinessType: BusinessType.SCHOOL_ERP,
  requiredFeature: FeatureKey.AC_COMMUNICATION,
};

function uid(): string {
  return Math.random().toString(36).substring(2, 18).toUpperCase();
}

function now(): string {
  return new Date().toISOString();
}

/**
 * POST /ac/messages
 * Send a message
 */
export const sendMessage = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { recipientId, subject, content, priority, attachments } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const id = uid();
    const ts = now();

    const message = {
      PK: pk,
      SK: `AC_MESSAGE#${id}`,
      GSI1PK: `AC_MESSAGES_SENT#${auth.tenantId}#${auth.sub}`,
      GSI1SK: ts,
      GSI2PK: `AC_MESSAGES_INBOX#${auth.tenantId}#${recipientId}`,
      GSI2SK: ts,
      id,
      senderId: auth.sub,
      senderName: (auth as any).name || 'Unknown',
      recipientId,
      subject,
      content,
      priority: priority || 'normal', // normal, high, urgent
      attachments: attachments || [],
      isRead: false,
      readAt: null,
      createdAt: ts,
    };

    await putItem(message);

    // Send WebSocket notification
    broadcastToStaff(
      auth.tenantId,
      WSEventName.AC_MESSAGE_RECEIVED,
      {
        messageId: id,
        senderId: auth.sub,
        recipientId,
        subject,
        priority,
      }
    ).catch(() => { /* non-critical */ });

    return response.success(message, 201);
  },
  AC_MESSAGING_OPTS,
);

/**
 * POST /ac/messages/broadcast
 * Broadcast message to multiple recipients
 */
export const broadcastMessage = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { recipientIds, subject, content, recipientType } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const ts = now();

    let targetIds = recipientIds || [];

    // If recipientType specified, get all users of that type
    if (recipientType) {
      if (recipientType === 'all_staff') {
        const staff = await queryAllItems(pk, 'AC_FACULTY#', {
          filterExpression: 'isActive = :active',
          expressionAttributeValues: { ':active': true },
        });
        targetIds = staff.map((s: any) => s.id);
      } else if (recipientType === 'all_students') {
        const students = await queryAllItems(pk, 'AC_STUDENT#', {
          filterExpression: '#status = :status',
          expressionAttributeNames: { '#status': 'status' },
          expressionAttributeValues: { ':status': 'active' },
        });
        targetIds = students.map((s: any) => s.id);
      }
    }

    const sent = [];
    for (const recipientId of targetIds) {
      const id = uid();
      const message = {
        PK: pk,
        SK: `AC_MESSAGE#${id}`,
        GSI1PK: `AC_MESSAGES_SENT#${auth.tenantId}#${auth.sub}`,
        GSI1SK: ts,
        GSI2PK: `AC_MESSAGES_INBOX#${auth.tenantId}#${recipientId}`,
        GSI2SK: ts,
        id,
        senderId: auth.sub,
        senderName: (auth as any).name || 'Unknown',
        recipientId,
        subject,
        content,
        priority: 'normal',
        isRead: false,
        isBroadcast: true,
        createdAt: ts,
      };

      await putItem(message);
      sent.push({ recipientId, messageId: id });
    }

    return response.success({
      broadcastId: uid(),
      recipients: sent.length,
      sent,
    }, 201);
  },
  AC_MESSAGING_OPTS,
);

/**
 * GET /ac/messages/inbox
 * Get inbox messages
 */
export const getInbox = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};

    const inbox = await queryAllItems(
      `AC_MESSAGES_INBOX#${auth.tenantId}#${auth.sub}`,
      '',
      { indexName: 'GSI2' }
    );

    // Filter unread if requested
    let filtered = inbox;
    if (p.unreadOnly === 'true') {
      filtered = inbox.filter((m: any) => !m.isRead);
    }

    // Sort by date desc
    filtered.sort((a: any, b: any) => (b.createdAt || '').localeCompare(a.createdAt || ''));

    const page = Math.max(1, parseInt(p.page || '1', 10));
    const limit = Math.min(parseInt(p.limit || '20', 10), 100);
    const total = filtered.length;
    const paged = filtered.slice((page - 1) * limit, page * limit);

    return response.paginated(paged, total, page, limit);
  },
  AC_MESSAGING_OPTS,
);

/**
 * GET /ac/messages/sent
 * Get sent messages
 */
export const getSentMessages = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};

    const sent = await queryAllItems(
      `AC_MESSAGES_SENT#${auth.tenantId}#${auth.sub}`,
      '',
      { indexName: 'GSI1' }
    );

    // Sort by date desc
    sent.sort((a: any, b: any) => (b.createdAt || '').localeCompare(a.createdAt || ''));

    const page = Math.max(1, parseInt(p.page || '1', 10));
    const limit = Math.min(parseInt(p.limit || '20', 10), 100);
    const total = sent.length;
    const paged = sent.slice((page - 1) * limit, page * limit);

    return response.paginated(paged, total, page, limit);
  },
  AC_MESSAGING_OPTS,
);

/**
 * GET /ac/messages/{id}
 * Get message details and mark as read
 */
export const getMessage = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Message ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const message = await getItem<any>(pk, `AC_MESSAGE#${id}`);
    
    if (!message) return response.notFound('Message not found');

    // Mark as read if recipient viewing
    if (message.recipientId === auth.sub && !message.isRead) {
      await updateItem(pk, `AC_MESSAGE#${id}`, {
        updateExpression: 'SET #isRead = :isRead, #readAt = :readAt',
        expressionAttributeNames: { '#isRead': 'isRead', '#readAt': 'readAt' },
        expressionAttributeValues: { ':isRead': true, ':readAt': now() },
      });
    }

    return response.success(message);
  },
  AC_MESSAGING_OPTS,
);

/**
 * POST /ac/messages/{id}/reply
 * Reply to a message
 */
export const replyToMessage = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const parentId = event.pathParameters?.id;
    if (!parentId) return response.badRequest('Message ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { content } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const parent = await getItem<any>(pk, `AC_MESSAGE#${parentId}`);
    if (!parent) return response.notFound('Parent message not found');

    // Determine recipient (sender of parent)
    const recipientId = parent.senderId === auth.sub ? parent.recipientId : parent.senderId;

    const id = uid();
    const ts = now();

    const reply = {
      PK: pk,
      SK: `AC_MESSAGE#${id}`,
      GSI1PK: `AC_MESSAGES_SENT#${auth.tenantId}#${auth.sub}`,
      GSI1SK: ts,
      GSI2PK: `AC_MESSAGES_INBOX#${auth.tenantId}#${recipientId}`,
      GSI2SK: ts,
      id,
      parentId,
      senderId: auth.sub,
      senderName: (auth as any).name || 'Unknown',
      recipientId,
      subject: `Re: ${parent.subject}`,
      content,
      isRead: false,
      createdAt: ts,
    };

    await putItem(reply);

    return response.success(reply, 201);
  },
  AC_MESSAGING_OPTS,
);

/**
 * DELETE /ac/messages/{id}
 * Delete/archive message
 */
export const deleteMessage = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Message ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const message = await getItem<any>(pk, `AC_MESSAGE#${id}`);
    
    if (!message) return response.notFound('Message not found');

    // Only sender or recipient can delete
    if (message.senderId !== auth.sub && message.recipientId !== auth.sub) {
      return response.error(403, 'FORBIDDEN', 'Not authorized to delete this message');
    }

    await updateItem(pk, `AC_MESSAGE#${id}`, {
      updateExpression: 'SET #isDeleted = :isDeleted, #deletedBy = :deletedBy, #deletedAt = :deletedAt',
      expressionAttributeNames: { '#isDeleted': 'isDeleted', '#deletedBy': 'deletedBy', '#deletedAt': 'deletedAt' },
      expressionAttributeValues: { ':isDeleted': true, ':deletedBy': auth.sub, ':deletedAt': now() },
    });

    return response.success({ id, deleted: true });
  },
  AC_MESSAGING_OPTS,
);

/**
 * GET /ac/messages/unread-count
 * Get unread message count
 */
export const getUnreadCount = authorizedHandler(
  [],
  async (_event, _ctx, auth) => {
    const inbox = await queryAllItems(
      `AC_MESSAGES_INBOX#${auth.tenantId}#${auth.sub}`,
      '',
      { indexName: 'GSI2' }
    );

    const unread = inbox.filter((m: any) => !m.isRead && !m.isDeleted);

    return response.success({
      unreadCount: unread.length,
      hasUrgent: unread.some((m: any) => m.priority === 'urgent'),
    });
  },
  AC_MESSAGING_OPTS,
);
