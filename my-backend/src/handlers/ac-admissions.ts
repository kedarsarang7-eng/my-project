// ============================================================================
// ACADEMIC COACHING — ADMISSIONS MODULE (Online Application Portal)
// ============================================================================
// Public-facing admission application system with workflow management
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { AuthContext, BusinessType, UserRole } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import { APIGatewayProxyEvent, Context } from 'aws-lambda';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import {
  Keys,
  queryItems,
  putItem,
  getItem,
  updateItem,
  deleteItem,
  queryAllItems,
} from '../config/dynamodb.config';
import { logCreate, logUpdate } from '../services/audit.service';
import crypto from 'crypto';
import { withIdempotency } from '../middleware/idempotency';

// Zod schemas
import {
  AdmissionApplicationSchema,
  UpdateApplicationStatusSchema,
  UploadDocumentSchema,
} from '../schemas/academic-coaching.schema';
import { z } from 'zod';

const AC_ADMISSION_OPTS = {
  requiredBusinessType: BusinessType.SCHOOL_ERP,
  requiredFeature: FeatureKey.AC_STUDENT_MANAGEMENT,
};

function uid(): string {
  return crypto.randomUUID().replace(/-/g, '').substring(0, 16).toUpperCase();
}

function now(): string {
  return new Date().toISOString();
}

function paisaToRupee(paisa: number): number {
  return Math.round(paisa) / 100;
}

function rupeeToPaisa(rupee: number): number {
  return Math.round(rupee * 100);
}

// ============================================================================
// PUBLIC ENDPOINTS (No Auth Required)
// ============================================================================

/**
 * POST /ac/admissions/public/apply
 * Public endpoint for submitting admission applications
 */
export const submitApplication = async (
  event: APIGatewayProxyEvent,
  _context: Context
): Promise<any> => {
  const requestId = uid();
  
  try {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const validated = AdmissionApplicationSchema.parse(body);
    
    // Get tenantId from header (required for public endpoint)
    const tenantId = event.headers?.['x-tenant-id'] || event.headers?.['X-Tenant-Id'];
    if (!tenantId) {
      return response.badRequest('x-tenant-id header is required');
    }

    // SECURITY: Validate tenant exists to prevent arbitrary write injections
    const tenantProfile = await getItem(Keys.tenantPK(tenantId), Keys.tenantProfileSK());
    if (!tenantProfile) {
      return response.notFound('Tenant not found');
    }

    const id = uid();
    const applicationId = `APP-${tenantId.substring(0, 6)}-${Date.now().toString(36).toUpperCase()}`;
    const pk = Keys.tenantPK(tenantId);
    const ts = now();

    // Check for duplicate applications (same phone + course in last 30 days)
    const existingApps = await queryAllItems(
      pk,
      'AC_APPLICATION#',
      {
        filterExpression: 'phone = :phone AND interestedCourseId = :courseId AND createdAt > :thirtyDaysAgo',
        expressionAttributeValues: {
          ':phone': validated.phone,
          ':courseId': validated.interestedCourseId,
          ':thirtyDaysAgo': new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
        },
      }
    );

    if (existingApps.length > 0) {
      return response.success({
        message: 'Application already submitted recently',
        existingApplicationId: (existingApps[0] as any).applicationId,
        status: (existingApps[0] as any).status,
      }, 200);
    }

    const application = {
      PK: pk,
      SK: `AC_APPLICATION#${id}`,
      GSI1PK: `AC_APPLICATION_PHONE#${tenantId}#${validated.phone}`,
      GSI1SK: ts,
      id,
      applicationId,
      status: 'submitted',
      statusHistory: [
        { status: 'submitted', timestamp: ts, remarks: 'Application submitted online' }
      ],
      ...validated,
      submittedAt: ts,
      createdAt: ts,
      updatedAt: ts,
      tenantId,
    };

    await putItem(application);

    // Send confirmation (async, don't block)
    // TODO: Integrate with notification service

    logger.info('Admission application submitted', {
      tenantId,
      applicationId,
      courseId: validated.interestedCourseId,
      requestId,
    });

    return response.success({
      applicationId,
      status: 'submitted',
      message: 'Application submitted successfully. You will receive a confirmation shortly.',
      submittedAt: ts,
    }, 201);

  } catch (error) {
    if (error instanceof z.ZodError) {
      return response.badRequest('Validation failed: ' + error.issues.map((e: any) => e.message).join(', '));
    }
    logger.error('Application submission failed', { error, requestId });
    return response.error(500, 'INTERNAL_ERROR', 'Failed to submit application', { requestId });
  }
};

/**
 * GET /ac/admissions/public/status/{applicationId}
 * Check application status (public, minimal info)
 */
export const checkApplicationStatus = async (
  event: APIGatewayProxyEvent,
  _context: Context
): Promise<any> => {
  try {
    const applicationId = event.pathParameters?.applicationId;
    const phone = event.queryStringParameters?.phone;
    
    if (!applicationId || !phone) {
      return response.badRequest('applicationId and phone are required');
    }

    const tenantId = event.headers?.['x-tenant-id'] || event.headers?.['X-Tenant-Id'];
    if (!tenantId) {
      return response.badRequest('x-tenant-id header is required');
    }

    // SECURITY: Validate tenant exists
    const tenantProfile = await getItem(Keys.tenantPK(tenantId), Keys.tenantProfileSK());
    if (!tenantProfile) {
      return response.notFound('Tenant not found');
    }

    const pk = Keys.tenantPK(tenantId);
    
    // Find by GSI (phone-based lookup)
    const apps = await queryAllItems(
      `AC_APPLICATION_PHONE#${tenantId}#${phone}`,
      '',
      { indexName: 'GSI1' }
    );

    const app = apps.find((a: any) => a.applicationId === applicationId);
    
    if (!app) {
      return response.notFound('Application not found');
    }

    // Return limited info for public endpoint
    return response.success({
      applicationId: app.applicationId,
      status: app.status,
      submittedAt: app.submittedAt,
      updatedAt: app.updatedAt,
      applicantName: `${app.firstName} ${app.lastName}`,
      interestedCourse: app.interestedCourseId,
    });

  } catch (error) {
    logger.error('Status check failed', { error });
    return response.error(500, 'INTERNAL_ERROR', 'Failed to check status');
  }
};

// ============================================================================
// AUTHENTICATED ENDPOINTS (Staff/Admin Only)
// ============================================================================

/**
 * GET /ac/admissions/applications
 * List all applications with filters
 */
export const listApplications = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let applications = await queryAllItems(pk, 'AC_APPLICATION#');

    // Apply filters
    if (p.status) {
      applications = applications.filter((a: any) => a.status === p.status);
    }
    if (p.courseId) {
      applications = applications.filter((a: any) => a.interestedCourseId === p.courseId);
    }
    if (p.fromDate) {
      applications = applications.filter((a: any) => a.createdAt >= (p.fromDate || ''));
    }
    if (p.toDate) {
      applications = applications.filter((a: any) => a.createdAt <= `${p.toDate}T23:59:59`);
    }
    if (p.search) {
      const s = p.search.toLowerCase();
      applications = applications.filter((a: any) =>
        (a.firstName || '').toLowerCase().includes(s) ||
        (a.lastName || '').toLowerCase().includes(s) ||
        (a.phone || '').includes(s) ||
        (a.applicationId || '').toLowerCase().includes(s)
      );
    }

    // Sort by createdAt desc
    applications.sort((a: any, b: any) => 
      (b.createdAt || '').localeCompare(a.createdAt || '')
    );

    // Pagination
    const page = Math.max(1, parseInt(p.page || '1', 10));
    const limit = Math.min(parseInt(p.limit || '20', 10), 100);
    const total = applications.length;
    const paged = applications.slice((page - 1) * limit, page * limit);

    return response.paginated(paged, total, page, limit);
  },
  AC_ADMISSION_OPTS,
);

/**
 * GET /ac/admissions/applications/{id}
 * Get full application details
 */
export const getApplication = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Application ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const app = await getItem(pk, `AC_APPLICATION#${id}`);
    
    if (!app) return response.notFound('Application not found');

    return response.success(app);
  },
  AC_ADMISSION_OPTS,
);

/**
 * POST /ac/admissions/applications/{id}/status
 * Update application status (workflow)
 */
export const updateApplicationStatus = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Application ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const validated = UpdateApplicationStatusSchema.parse(body);

    const pk = Keys.tenantPK(auth.tenantId);
    const existing = await getItem<any>(pk, `AC_APPLICATION#${id}`);
    
    if (!existing) return response.notFound('Application not found');

    const oldStatus = existing.status;
    const ts = now();

    // Update status and add to history
    const statusEntry = {
      status: validated.status,
      timestamp: ts,
      remarks: validated.remarks || '',
      updatedBy: auth.sub,
    };

    await updateItem(pk, `AC_APPLICATION#${id}`, {
      updateExpression: 'SET #status = :status, #updatedAt = :updatedAt, #statusHistory = list_append(if_not_exists(#statusHistory, :empty), :statusEntry)',
      expressionAttributeNames: {
        '#status': 'status',
        '#updatedAt': 'updatedAt',
        '#statusHistory': 'statusHistory',
      },
      expressionAttributeValues: {
        ':status': validated.status,
        ':updatedAt': ts,
        ':statusEntry': [statusEntry],
        ':empty': [],
      },
    });

    // If interview scheduled, update interview details
    if (validated.status === 'interview_scheduled' && validated.interviewDate) {
      await updateItem(pk, `AC_APPLICATION#${id}`, {
        updateExpression: 'SET #interviewDate = :interviewDate, #interviewVenue = :interviewVenue',
        expressionAttributeNames: {
          '#interviewDate': 'interviewDate',
          '#interviewVenue': 'interviewVenue',
        },
        expressionAttributeValues: {
          ':interviewDate': validated.interviewDate,
          ':interviewVenue': validated.interviewVenue || null,
        },
      });
    }

    // If admitted, auto-create student (optional - can be manual)
    if (validated.status === 'admitted') {
      // Create student record from application
      const studentId = uid();
      const student = {
        PK: pk,
        SK: Keys.acStudentSK(studentId),
        id: studentId,
        studentId: `STU-${auth.tenantId.substring(0, 8)}-${new Date().toISOString().slice(0, 7).replace('-', '')}-${studentId.substring(0, 6)}`,
        firstName: existing.firstName,
        lastName: existing.lastName,
        dob: existing.dob,
        gender: existing.gender,
        phone: existing.phone,
        parentPhone: existing.parentPhone,
        parentName: existing.parentName,
        email: existing.email,
        address: existing.address,
        schoolName: existing.previousSchool,
        currentClass: existing.lastClass,
        enrolledCourseIds: [existing.interestedCourseId],
        enrolledBatchIds: [], // Will be assigned later
        photoS3Key: existing.documents?.find((d: any) => d.type === 'photo')?.s3Key,
        status: 'active',
        createdAt: ts,
        updatedAt: ts,
        createdBy: auth.sub,
        sourceApplicationId: existing.id,
      };

      await putItem(student);

      // Update application with student reference
      await updateItem(pk, `AC_APPLICATION#${id}`, {
        updateExpression: 'SET #convertedStudentId = :studentId',
        expressionAttributeNames: { '#convertedStudentId': 'convertedStudentId' },
        expressionAttributeValues: { ':studentId': studentId },
      });

      logger.info('Application converted to student', {
        tenantId: auth.tenantId,
        applicationId: id,
        studentId,
      });
    }

    // Audit log
    await logUpdate(auth.tenantId, 'application', id, { status: oldStatus }, { status: validated.status }, {
      performedBy: auth.sub,
      requestId: (auth as any).requestId || 'unknown',
    });

    return response.success({
      id,
      status: validated.status,
      previousStatus: oldStatus,
      updatedAt: ts,
    });
  },
  AC_ADMISSION_OPTS,
);

/**
 * POST /ac/admissions/applications/{id}/documents
 * Add document to application
 */
export const addApplicationDocument = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Application ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const validated = UploadDocumentSchema.parse({ ...body, entityType: 'application', entityId: id });

    const pk = Keys.tenantPK(auth.tenantId);
    const existing = await getItem<any>(pk, `AC_APPLICATION#${id}`);
    
    if (!existing) return response.notFound('Application not found');

    const ts = now();
    const docId = uid();

    const document = {
      id: docId,
      documentType: validated.documentType,
      s3Key: validated.s3Key,
      originalName: validated.originalName,
      fileSize: validated.fileSize,
      mimeType: validated.mimeType,
      description: validated.description,
      uploadedAt: ts,
      uploadedBy: auth.sub,
    };

    await updateItem(pk, `AC_APPLICATION#${id}`, {
      updateExpression: 'SET #documents = list_append(if_not_exists(#documents, :empty), :doc), #updatedAt = :updatedAt',
      expressionAttributeNames: {
        '#documents': 'documents',
        '#updatedAt': 'updatedAt',
      },
      expressionAttributeValues: {
        ':doc': [document],
        ':empty': [],
        ':updatedAt': ts,
      },
    });

    return response.success({ document, uploadedAt: ts }, 201);
  },
  AC_ADMISSION_OPTS,
);

/**
 * GET /ac/admissions/dashboard
 * Admission dashboard stats
 */
export const getAdmissionsDashboard = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (_event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const apps = await queryAllItems(pk, 'AC_APPLICATION#');

    const stats = {
      totalApplications: apps.length,
      byStatus: {} as Record<string, number>,
      byCourse: {} as Record<string, number>,
      todayApplications: 0,
      thisWeekApplications: 0,
      thisMonthApplications: 0,
      conversionRate: 0,
    };

    const today = new Date().toISOString().split('T')[0];
    const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
    const monthAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();

    let admitted = 0;

    for (const app of apps as any[]) {
      // By status
      stats.byStatus[app.status] = (stats.byStatus[app.status] || 0) + 1;
      
      // By course
      if (app.interestedCourseId) {
        stats.byCourse[app.interestedCourseId] = (stats.byCourse[app.interestedCourseId] || 0) + 1;
      }

      // Time-based
      if (app.createdAt?.startsWith(today)) stats.todayApplications++;
      if (app.createdAt > weekAgo) stats.thisWeekApplications++;
      if (app.createdAt > monthAgo) stats.thisMonthApplications++;

      if (app.status === 'admitted') admitted++;
    }

    stats.conversionRate = apps.length > 0 ? Math.round((admitted / apps.length) * 100) : 0;

    return response.success(stats);
  },
  AC_ADMISSION_OPTS,
);

/**
 * DELETE /ac/admissions/applications/{id}
 * Delete application (soft or hard)
 */
export const deleteApplication = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Application ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const existing = await getItem<any>(pk, `AC_APPLICATION#${id}`);
    
    if (!existing) return response.notFound('Application not found');

    // Soft delete
    await updateItem(pk, `AC_APPLICATION#${id}`, {
      updateExpression: 'SET #status = :status, #isDeleted = :isDeleted, #deletedAt = :deletedAt',
      expressionAttributeNames: {
        '#status': 'status',
        '#isDeleted': 'isDeleted',
        '#deletedAt': 'deletedAt',
      },
      expressionAttributeValues: {
        ':status': 'deleted',
        ':isDeleted': true,
        ':deletedAt': now(),
      },
    });

    return response.success({ id, deleted: true });
  },
  AC_ADMISSION_OPTS,
);
