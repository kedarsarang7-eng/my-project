// ============================================================================
// ACADEMIC COACHING — HOMEWORK/ASSIGNMENT MODULE
// ============================================================================
// Homework creation, submission, and grading
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole, BusinessType } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
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
import { z } from 'zod';
import {
  CreateHomeworkSchema,
  SubmitHomeworkSchema,
  GradeHomeworkSchema,
} from '../schemas/academic-coaching.schema';

const AC_HOMEWORK_OPTS = {
  requiredBusinessType: BusinessType.SCHOOL_ERP,
  requiredFeature: FeatureKey.AC_MATERIAL_MANAGEMENT,
};

function uid(): string {
  return Math.random().toString(36).substring(2, 18).toUpperCase();
}

function now(): string {
  return new Date().toISOString();
}

// ============================================================================
// HOMEWORK MANAGEMENT
// ============================================================================

/**
 * GET /ac/homework
 * List homework assignments
 */
export const listHomework = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let homework = await queryAllItems(pk, 'AC_HOMEWORK#');

    if (p.batchId) homework = homework.filter((h: any) => h.batchId === p.batchId);
    if (p.facultyId) homework = homework.filter((h: any) => h.facultyId === p.facultyId);
    if (p.subject) homework = homework.filter((h: any) => h.subject === p.subject);
    if (p.status) homework = homework.filter((h: any) => h.status === p.status);

    // Sort by due date
    homework.sort((a: any, b: any) => (a.dueDate || '').localeCompare(b.dueDate || ''));

    const page = Math.max(1, parseInt(p.page || '1', 10));
    const limit = Math.min(parseInt(p.limit || '20', 10), 100);
    const total = homework.length;
    const paged = homework.slice((page - 1) * limit, page * limit);

    return response.paginated(paged, total, page, limit);
  },
  AC_HOMEWORK_OPTS,
);

/**
 * GET /ac/homework/{id}
 * Get homework details with submissions
 */
export const getHomework = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Homework ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const homework = await getItem(pk, `AC_HOMEWORK#${id}`);
    
    if (!homework) return response.notFound('Homework not found');

    // Get submissions
    const submissions = await queryAllItems(
      pk,
      'AC_HOMEWORK_SUBMISSION#',
      {
        filterExpression: 'homeworkId = :homeworkId',
        expressionAttributeValues: { ':homeworkId': id },
      }
    );

    return response.success({ ...homework, submissions });
  },
  AC_HOMEWORK_OPTS,
);

/**
 * POST /ac/homework
 * Create homework assignment
 */
export const createHomework = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const validated = CreateHomeworkSchema.parse(body);

    const id = uid();
    const pk = Keys.tenantPK(auth.tenantId);
    const ts = now();

    const homework = {
      PK: pk,
      SK: `AC_HOMEWORK#${id}`,
      GSI1PK: `AC_HOMEWORK_BY_BATCH#${auth.tenantId}#${validated.batchId}`,
      GSI1SK: validated.dueDate,
      id,
      ...validated,
      status: 'active',
      submissionCount: 0,
      gradedCount: 0,
      createdBy: auth.sub,
      createdAt: ts,
      updatedAt: ts,
    };

    await putItem(homework);

    logger.info('Homework created', { tenantId: auth.tenantId, homeworkId: id });

    return response.success(homework, 201);
  },
  AC_HOMEWORK_OPTS,
);

/**
 * PUT /ac/homework/{id}
 * Update homework
 */
export const updateHomework = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Homework ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const updates = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const existing = await getItem<any>(pk, `AC_HOMEWORK#${id}`);
    
    if (!existing) return response.notFound('Homework not found');

    if (existing.createdBy !== auth.sub && !['OWNER', 'ADMIN'].includes(auth.role)) {
      return response.error(403, 'FORBIDDEN', 'Can only edit own homework');
    }

    const ts = now();
    await updateItem(pk, `AC_HOMEWORK#${id}`, {
      updateExpression: 'SET #updates = :updates, #updatedAt = :updatedAt',
      expressionAttributeNames: { '#updates': 'updates', '#updatedAt': 'updatedAt' },
      expressionAttributeValues: { ':updates': updates, ':updatedAt': ts },
    });

    return response.success({ id, ...updates, updatedAt: ts });
  },
  AC_HOMEWORK_OPTS,
);

/**
 * DELETE /ac/homework/{id}
 * Delete homework
 */
export const deleteHomework = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Homework ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const existing = await getItem<any>(pk, `AC_HOMEWORK#${id}`);
    
    if (!existing) return response.notFound('Homework not found');

    if (existing.createdBy !== auth.sub && !['OWNER', 'ADMIN'].includes(auth.role)) {
      return response.error(403, 'FORBIDDEN', 'Can only delete own homework');
    }

    await deleteItem(pk, `AC_HOMEWORK#${id}`);

    return response.success({ id, deleted: true });
  },
  AC_HOMEWORK_OPTS,
);

// ============================================================================
// SUBMISSIONS
// ============================================================================

/**
 * POST /ac/homework/{id}/submit
 * Submit homework (student)
 */
export const submitHomework = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const homeworkId = event.pathParameters?.id;
    if (!homeworkId) return response.badRequest('Homework ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const validated = SubmitHomeworkSchema.parse({ ...body, homeworkId });

    const pk = Keys.tenantPK(auth.tenantId);
    
    // Check homework exists
    const homework = await getItem<any>(pk, `AC_HOMEWORK#${homeworkId}`);
    if (!homework) return response.notFound('Homework not found');

    // Check if already submitted
    const existingSubmissions = await queryAllItems(
      pk,
      'AC_HOMEWORK_SUBMISSION#',
      {
        filterExpression: 'homeworkId = :hwId AND studentId = :studentId',
        expressionAttributeValues: { ':hwId': homeworkId, ':studentId': validated.studentId },
      }
    );

    const isLate = new Date().toISOString() > homework.dueDate + 'T23:59:59';
    const ts = now();

    if (existingSubmissions.length > 0) {
      // Update existing submission
      const submissionId = (existingSubmissions[0] as any).id;
      await updateItem(pk, `AC_HOMEWORK_SUBMISSION#${submissionId}`, {
        updateExpression: 'SET #submissionText = :text, #attachments = :attachments, #submittedAt = :submittedAt, #isLate = :isLate, #version = if_not_exists(#version, :zero) + :one',
        expressionAttributeNames: {
          '#submissionText': 'submissionText',
          '#attachments': 'attachments',
          '#submittedAt': 'submittedAt',
          '#isLate': 'isLate',
          '#version': 'version',
        },
        expressionAttributeValues: {
          ':text': validated.submissionText,
          ':attachments': validated.attachments || [],
          ':submittedAt': validated.submittedAt || ts,
          ':isLate': isLate,
          ':zero': 0,
          ':one': 1,
        },
      });

      return response.success({ id: submissionId, updated: true, isLate });
    }

    // Create new submission
    const id = uid();
    const submission = {
      PK: pk,
      SK: `AC_HOMEWORK_SUBMISSION#${id}`,
      GSI1PK: `AC_SUBMISSION_BY_STUDENT#${auth.tenantId}#${validated.studentId}`,
      GSI1SK: ts,
      id,
      ...validated,
      isLate,
      status: 'submitted',
      createdAt: ts,
    };

    await putItem(submission);

    // Update homework submission count
    await updateItem(pk, `AC_HOMEWORK#${homeworkId}`, {
      updateExpression: 'SET #submissionCount = if_not_exists(#submissionCount, :zero) + :one',
      expressionAttributeNames: { '#submissionCount': 'submissionCount' },
      expressionAttributeValues: { ':zero': 0, ':one': 1 },
    });

    return response.success(submission, 201);
  },
  AC_HOMEWORK_OPTS,
);

/**
 * POST /ac/homework/submissions/{id}/grade
 * Grade a submission
 */
export const gradeSubmission = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const submissionId = event.pathParameters?.id;
    if (!submissionId) return response.badRequest('Submission ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const validated = GradeHomeworkSchema.omit({ submissionId: true }).parse(body);

    const pk = Keys.tenantPK(auth.tenantId);
    const submission = await getItem<any>(pk, `AC_HOMEWORK_SUBMISSION#${submissionId}`);
    
    if (!submission) return response.notFound('Submission not found');

    const ts = now();
    await updateItem(pk, `AC_HOMEWORK_SUBMISSION#${submissionId}`, {
      updateExpression: 'SET #marksObtained = :marks, #grade = :grade, #feedback = :feedback, #status = :status, #gradedBy = :gradedBy, #gradedAt = :gradedAt',
      expressionAttributeNames: {
        '#marksObtained': 'marksObtained',
        '#grade': 'grade',
        '#feedback': 'feedback',
        '#status': 'status',
        '#gradedBy': 'gradedBy',
        '#gradedAt': 'gradedAt',
      },
      expressionAttributeValues: {
        ':marks': validated.marksObtained,
        ':grade': validated.grade || null,
        ':feedback': validated.feedback || '',
        ':status': validated.status,
        ':gradedBy': auth.sub,
        ':gradedAt': ts,
      },
    });

    // Update homework graded count
    await updateItem(pk, `AC_HOMEWORK#${submission.homeworkId}`, {
      updateExpression: 'SET #gradedCount = if_not_exists(#gradedCount, :zero) + :one',
      expressionAttributeNames: { '#gradedCount': 'gradedCount' },
      expressionAttributeValues: { ':zero': 0, ':one': 1 },
    });

    return response.success({ submissionId, ...validated, gradedBy: auth.sub, gradedAt: ts });
  },
  AC_HOMEWORK_OPTS,
);

/**
 * GET /ac/homework/submissions
 * List submissions for a homework
 */
export const listSubmissions = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const { homeworkId, studentId, status } = p;

    if (!homeworkId && !studentId) {
      return response.badRequest('homeworkId or studentId required');
    }

    const pk = Keys.tenantPK(auth.tenantId);
    let submissions: any[] = [];

    if (studentId) {
      submissions = await queryAllItems(
        `AC_SUBMISSION_BY_STUDENT#${auth.tenantId}#${studentId}`,
        '',
        { indexName: 'GSI1' }
      );
    } else {
      submissions = await queryAllItems(
        pk,
        'AC_HOMEWORK_SUBMISSION#',
        {
          filterExpression: 'homeworkId = :homeworkId',
          expressionAttributeValues: { ':homeworkId': homeworkId },
        }
      );
    }

    if (status) {
      submissions = submissions.filter((s: any) => s.status === status);
    }

    return response.success(submissions);
  },
  AC_HOMEWORK_OPTS,
);

/**
 * GET /ac/homework/student/{studentId}
 * Get all homework for a student with submission status
 */
export const getStudentHomework = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const studentId = event.pathParameters?.studentId;
    if (!studentId) return response.badRequest('Student ID required');

    const pk = Keys.tenantPK(auth.tenantId);

    // Get student to find batch
    const student = await getItem(pk, Keys.acStudentSK(studentId));
    if (!student) return response.notFound('Student not found');

    const batchIds = (student as any).enrolledBatchIds || [];
    if (batchIds.length === 0) return response.success([]);

    // Get all homework for these batches
    let allHomework: any[] = [];
    for (const batchId of batchIds) {
      const batchHomework = await queryAllItems(
        `AC_HOMEWORK_BY_BATCH#${auth.tenantId}#${batchId}`,
        '',
        { indexName: 'GSI1' }
      );
      allHomework.push(...batchHomework);
    }

    // Get student's submissions
    const submissions = await queryAllItems(
      `AC_SUBMISSION_BY_STUDENT#${auth.tenantId}#${studentId}`,
      '',
      { indexName: 'GSI1' }
    );

    const submissionMap = new Map((submissions as any[]).map(s => [s.homeworkId, s]));

    // Merge homework with submission status
    const result = allHomework.map((hw: any) => ({
      ...hw,
      submission: submissionMap.get(hw.id) || null,
    }));

    return response.success(result);
  },
  AC_HOMEWORK_OPTS,
);
