// ============================================================================
// ACADEMIC COACHING — DOCUMENT VAULT MODULE
// ============================================================================
// Secure document storage and management for students, faculty, applications
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
  deleteItem,
  queryAllItems,
} from '../config/dynamodb.config';
import { StorageService } from '../services/storage.service';

const storageService = new StorageService();

const AC_DOCUMENT_OPTS = {
  requiredBusinessType: BusinessType.SCHOOL_ERP,
  requiredFeature: FeatureKey.AC_STUDENT_MANAGEMENT,
};

function uid(): string {
  return Math.random().toString(36).substring(2, 18).toUpperCase();
}

function now(): string {
  return new Date().toISOString();
}

/**
 * POST /ac/documents/upload
 * Upload a document (metadata + presigned URL)
 */
export const uploadDocument = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const {
      entityType,      // 'student', 'faculty', 'application'
      entityId,
      documentType,  // 'photo', 'birth_certificate', 'marksheet', etc.
      fileName,
      fileSize,
      mimeType,
      description,
      tags,
      expiryDate,
      isConfidential,
    } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const ts = now();
    const id = uid();

    // Generate S3 key
    const s3Key = `tenants/${auth.tenantId}/documents/${entityType}/${entityId}/${documentType}/${id}-${fileName}`;

    // Generate presigned upload URL
    const uploadUrl = await storageService.getUploadUrl(s3Key, mimeType || 'application/octet-stream');

    // Store metadata
    const document = {
      PK: pk,
      SK: `AC_DOCUMENT#${id}`,
      GSI1PK: `AC_DOCUMENTS_BY_ENTITY#${auth.tenantId}#${entityType}#${entityId}`,
      GSI1SK: ts,
      id,
      entityType,
      entityId,
      documentType,
      s3Key,
      fileName,
      fileSize,
      mimeType,
      description,
      tags: tags || [],
      expiryDate,
      isConfidential: isConfidential || false,
      uploadedBy: auth.sub,
      uploadedAt: ts,
      status: 'pending_upload', // pending_upload, uploaded, verified, rejected
    };

    await putItem(document);

    logger.info('Document upload initiated', {
      tenantId: auth.tenantId,
      documentId: id,
      entityType,
      entityId,
    });

    return response.success({
      documentId: id,
      uploadUrl,
      s3Key,
      expiresIn: 900, // 15 minutes
    }, 201);
  },
  AC_DOCUMENT_OPTS,
);

/**
 * POST /ac/documents/{id}/confirm
 * Confirm document upload completion
 */
export const confirmUpload = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Document ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const document = await getItem<any>(pk, `AC_DOCUMENT#${id}`);
    
    if (!document) return response.notFound('Document not found');

    const ts = now();

    // Update status to uploaded
    await updateItem(pk, `AC_DOCUMENT#${id}`, {
      updateExpression: 'SET #status = :status, #uploadedAt = :uploadedAt, #updatedAt = :updatedAt',
      expressionAttributeNames: {
        '#status': 'status',
        '#uploadedAt': 'uploadedAt',
        '#updatedAt': 'updatedAt',
      },
      expressionAttributeValues: {
        ':status': 'uploaded',
        ':uploadedAt': ts,
        ':updatedAt': ts,
      },
    });

    // Generate download URL
    const downloadUrl = await storageService.getDownloadUrl(document.s3Key);

    return response.success({
      documentId: id,
      status: 'uploaded',
      downloadUrl,
      expiresIn: 3600,
    });
  },
  AC_DOCUMENT_OPTS,
);

/**
 * GET /ac/documents/{id}
 * Get document metadata and download URL
 */
export const getDocument = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Document ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const document = await getItem<any>(pk, `AC_DOCUMENT#${id}`);
    
    if (!document) return response.notFound('Document not found');

    // Generate fresh download URL
    const downloadUrl = await storageService.getDownloadUrl(document.s3Key);

    return response.success({
      ...document,
      downloadUrl,
      expiresIn: 3600,
    });
  },
  AC_DOCUMENT_OPTS,
);

/**
 * GET /ac/documents
 * List documents with filters
 */
export const listDocuments = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let documents = [];

    if (p.entityType && p.entityId) {
      // Get documents for specific entity
      documents = await queryAllItems(
        `AC_DOCUMENTS_BY_ENTITY#${auth.tenantId}#${p.entityType}#${p.entityId}`,
        '',
        { indexName: 'GSI1' }
      );
    } else {
      documents = await queryAllItems(pk, 'AC_DOCUMENT#');
    }

    // Apply filters
    if (p.documentType) {
      documents = documents.filter((d: any) => d.documentType === p.documentType);
    }
    if (p.status) {
      documents = documents.filter((d: any) => d.status === p.status);
    }
    if (p.tag) {
      documents = documents.filter((d: any) => (d.tags || []).includes(p.tag));
    }

    // Sort by upload date desc
    documents.sort((a: any, b: any) => (b.uploadedAt || '').localeCompare(a.uploadedAt || ''));

    // Pagination
    const page = Math.max(1, parseInt(p.page || '1', 10));
    const limit = Math.min(parseInt(p.limit || '20', 10), 100);
    const total = documents.length;
    const paged = documents.slice((page - 1) * limit, page * limit);

    return response.paginated(paged, total, page, limit);
  },
  AC_DOCUMENT_OPTS,
);

/**
 * PUT /ac/documents/{id}/verify
 * Verify/reject a document (admin)
 */
export const verifyDocument = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Document ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { status, remarks } = body; // status: 'verified' or 'rejected'

    const pk = Keys.tenantPK(auth.tenantId);
    const document = await getItem<any>(pk, `AC_DOCUMENT#${id}`);
    
    if (!document) return response.notFound('Document not found');

    const ts = now();

    await updateItem(pk, `AC_DOCUMENT#${id}`, {
      updateExpression: 'SET #status = :status, #verifiedBy = :verifiedBy, #verifiedAt = :verifiedAt, #remarks = :remarks, #updatedAt = :updatedAt',
      expressionAttributeNames: {
        '#status': 'status',
        '#verifiedBy': 'verifiedBy',
        '#verifiedAt': 'verifiedAt',
        '#remarks': 'remarks',
        '#updatedAt': 'updatedAt',
      },
      expressionAttributeValues: {
        ':status': status,
        ':verifiedBy': auth.sub,
        ':verifiedAt': ts,
        ':remarks': remarks || '',
        ':updatedAt': ts,
      },
    });

    logger.info('Document verified', { tenantId: auth.tenantId, documentId: id, status, verifiedBy: auth.sub });

    return response.success({ documentId: id, status, verifiedAt: ts });
  },
  AC_DOCUMENT_OPTS,
);

/**
 * DELETE /ac/documents/{id}
 * Delete a document
 */
export const deleteDocument = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Document ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const document = await getItem<any>(pk, `AC_DOCUMENT#${id}`);
    
    if (!document) return response.notFound('Document not found');

    // Delete from S3 (optional - could be async)
    // await storageService.deleteObject(document.s3Key);

    // Soft delete in DynamoDB
    const ts = now();
    await updateItem(pk, `AC_DOCUMENT#${id}`, {
      updateExpression: 'SET #status = :status, #deletedAt = :deletedAt, #deletedBy = :deletedBy, #updatedAt = :updatedAt',
      expressionAttributeNames: {
        '#status': 'status',
        '#deletedAt': 'deletedAt',
        '#deletedBy': 'deletedBy',
        '#updatedAt': 'updatedAt',
      },
      expressionAttributeValues: {
        ':status': 'deleted',
        ':deletedAt': ts,
        ':deletedBy': auth.sub,
        ':updatedAt': ts,
      },
    });

    return response.success({ documentId: id, deleted: true });
  },
  AC_DOCUMENT_OPTS,
);

/**
 * GET /ac/documents/stats
 * Document statistics
 */
export const getDocumentStats = authorizedHandler(
  [],
  async (_event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);

    const documents = await queryAllItems(pk, 'AC_DOCUMENT#');

    const stats = {
      totalDocuments: documents.length,
      byStatus: {} as Record<string, number>,
      byType: {} as Record<string, number>,
      byEntityType: {} as Record<string, number>,
      pendingVerification: 0,
      totalStorageUsed: documents.reduce((sum: number, d: any) => sum + (d.fileSize || 0), 0),
    };

    for (const doc of documents as any[]) {
      stats.byStatus[doc.status] = (stats.byStatus[doc.status] || 0) + 1;
      stats.byType[doc.documentType] = (stats.byType[doc.documentType] || 0) + 1;
      stats.byEntityType[doc.entityType] = (stats.byEntityType[doc.entityType] || 0) + 1;
      if (doc.status === 'uploaded') stats.pendingVerification++;
    }

    return response.success(stats);
  },
  AC_DOCUMENT_OPTS,
);

/**
 * GET /ac/documents/types
 * List document type categories
 */
export const getDocumentTypes = authorizedHandler(
  [],
  async (_event, _ctx, auth) => {
    const types = [
      { value: 'photo', label: 'Photo', icon: 'camera' },
      { value: 'birth_certificate', label: 'Birth Certificate', icon: 'document' },
      { value: 'marksheet', label: 'Marksheet', icon: 'grade' },
      { value: 'tc', label: 'Transfer Certificate', icon: 'school' },
      { value: 'id_proof', label: 'ID Proof', icon: 'badge' },
      { value: 'address_proof', label: 'Address Proof', icon: 'home' },
      { value: 'medical_record', label: 'Medical Record', icon: 'medical' },
      { value: 'achievement', label: 'Achievement Certificate', icon: 'trophy' },
      { value: 'fee_receipt', label: 'Fee Receipt', icon: 'receipt' },
      { value: 'other', label: 'Other', icon: 'file' },
    ];

    return response.success(types);
  },
  AC_DOCUMENT_OPTS,
);
