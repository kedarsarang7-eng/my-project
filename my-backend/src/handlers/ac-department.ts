// ============================================================================
// ACADEMIC COACHING — DEPARTMENT SETUP MODULE
// ============================================================================
// Manage school departments and staff assignments
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

const AC_DEPT_OPTS = {
  requiredBusinessType: BusinessType.SCHOOL_ERP,
  requiredFeature: FeatureKey.AC_FACULTY_MANAGEMENT,
};

function uid(): string {
  return Math.random().toString(36).substring(2, 18).toUpperCase();
}

function now(): string {
  return new Date().toISOString();
}

/**
 * GET /ac/departments
 * List all departments
 */
export const listDepartments = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let departments = await queryAllItems(pk, 'AC_DEPARTMENT#');

    if (p.isActive) {
      departments = departments.filter((d: any) => d.isActive === (p.isActive === 'true'));
    }

    // Sort by name
    departments.sort((a: any, b: any) => (a.name || '').localeCompare(b.name || ''));

    // Get staff count for each department
    for (const dept of departments as any[]) {
      const staff = await queryAllItems(pk, 'AC_FACULTY#', {
        filterExpression: 'departmentId = :deptId AND isActive = :active',
        expressionAttributeValues: { ':deptId': dept.id, ':active': true },
      });
      dept.staffCount = staff.length;
    }

    return response.success(departments);
  },
  AC_DEPT_OPTS,
);

/**
 * POST /ac/departments
 * Create department
 */
export const createDepartment = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { code, name, description, headId, subjects } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const id = uid();
    const ts = now();

    const department = {
      PK: pk,
      SK: `AC_DEPARTMENT#${id}`,
      GSI1PK: `AC_DEPARTMENT_CODE#${auth.tenantId}#${code}`,
      GSI1SK: ts,
      id,
      code,
      name,
      description,
      headId,
      subjects: subjects || [],
      isActive: true,
      createdAt: ts,
      updatedAt: ts,
    };

    await putItem(department);

    logger.info('Department created', { tenantId: auth.tenantId, departmentId: id, name });

    return response.success(department, 201);
  },
  AC_DEPT_OPTS,
);

/**
 * PUT /ac/departments/{id}
 * Update department
 */
export const updateDepartment = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Department ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const pk = Keys.tenantPK(auth.tenantId);

    const ts = now();

    await updateItem(pk, `AC_DEPARTMENT#${id}`, {
      updateExpression: 'SET #updates = :updates, #updatedAt = :updatedAt',
      expressionAttributeNames: { '#updates': 'updates', '#updatedAt': 'updatedAt' },
      expressionAttributeValues: { ':updates': body, ':updatedAt': ts },
    });

    return response.success({ id, ...body, updatedAt: ts });
  },
  AC_DEPT_OPTS,
);

/**
 * DELETE /ac/departments/{id}
 * Delete/soft-delete department
 */
export const deleteDepartment = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Department ID required');

    const pk = Keys.tenantPK(auth.tenantId);

    // Check if staff assigned
    const staff = await queryAllItems(pk, 'AC_FACULTY#', {
      filterExpression: 'departmentId = :deptId',
      expressionAttributeValues: { ':deptId': id },
    });

    if (staff.length > 0) {
      return response.error(400, 'DEPT_HAS_STAFF', 'Cannot delete department with assigned staff');
    }

    await deleteItem(pk, `AC_DEPARTMENT#${id}`);

    return response.success({ id, deleted: true });
  },
  AC_DEPT_OPTS,
);

/**
 * GET /ac/departments/{id}/staff
 * Get staff in department
 */
export const getDepartmentStaff = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const departmentId = event.pathParameters?.id;
    if (!departmentId) return response.badRequest('Department ID required');

    const pk = Keys.tenantPK(auth.tenantId);

    const staff = await queryAllItems(pk, 'AC_FACULTY#', {
      filterExpression: 'departmentId = :deptId',
      expressionAttributeValues: { ':deptId': departmentId },
    });

    // Sort by name
    staff.sort((a: any, b: any) => `${a.firstName} ${a.lastName}`.localeCompare(`${b.firstName} ${b.lastName}`));

    return response.success(staff);
  },
  AC_DEPT_OPTS,
);

/**
 * POST /ac/departments/{id}/assign-head
 * Assign department head
 */
export const assignDepartmentHead = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN],
  async (event, _ctx, auth) => {
    const departmentId = event.pathParameters?.id;
    if (!departmentId) return response.badRequest('Department ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { facultyId } = body;

    const pk = Keys.tenantPK(auth.tenantId);

    // Verify department exists
    const dept = await getItem(pk, `AC_DEPARTMENT#${departmentId}`);
    if (!dept) return response.notFound('Department not found');

    // Verify faculty exists
    const faculty = await getItem(pk, `AC_FACULTY#${facultyId}`);
    if (!faculty) return response.notFound('Faculty not found');

    const ts = now();

    // Update department head
    await updateItem(pk, `AC_DEPARTMENT#${departmentId}`, {
      updateExpression: 'SET #headId = :headId, #updatedAt = :updatedAt',
      expressionAttributeNames: { '#headId': 'headId', '#updatedAt': 'updatedAt' },
      expressionAttributeValues: { ':headId': facultyId, ':updatedAt': ts },
    });

    // Update faculty as department head
    await updateItem(pk, `AC_FACULTY#${facultyId}`, {
      updateExpression: 'SET #isDepartmentHead = :isHead, #departmentId = :deptId, #updatedAt = :updatedAt',
      expressionAttributeNames: { '#isDepartmentHead': 'isDepartmentHead', '#departmentId': 'departmentId', '#updatedAt': 'updatedAt' },
      expressionAttributeValues: { ':isHead': true, ':deptId': departmentId, ':updatedAt': ts },
    });

    return response.success({ departmentId, headId: facultyId, assignedAt: ts });
  },
  AC_DEPT_OPTS,
);

/**
 * POST /ac/faculty/{id}/assign-department
 * Assign faculty to department
 */
export const assignFacultyToDepartment = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const facultyId = event.pathParameters?.id;
    if (!facultyId) return response.badRequest('Faculty ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { departmentId } = body;

    const pk = Keys.tenantPK(auth.tenantId);

    // Verify department exists
    const dept = await getItem(pk, `AC_DEPARTMENT#${departmentId}`);
    if (!dept) return response.notFound('Department not found');

    const ts = now();

    await updateItem(pk, `AC_FACULTY#${facultyId}`, {
      updateExpression: 'SET #departmentId = :deptId, #updatedAt = :updatedAt',
      expressionAttributeNames: { '#departmentId': 'departmentId', '#updatedAt': 'updatedAt' },
      expressionAttributeValues: { ':deptId': departmentId, ':updatedAt': ts },
    });

    return response.success({ facultyId, departmentId, assignedAt: ts });
  },
  AC_DEPT_OPTS,
);

/**
 * GET /ac/departments/summary
 * Department summary statistics
 */
export const getDepartmentSummary = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (_event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);

    const departments = await queryAllItems(pk, 'AC_DEPARTMENT#');

    const summary = [];
    for (const dept of departments as any[]) {
      const staff = await queryAllItems(pk, 'AC_FACULTY#', {
        filterExpression: 'departmentId = :deptId',
        expressionAttributeValues: { ':deptId': dept.id },
      });

      summary.push({
        id: dept.id,
        code: dept.code,
        name: dept.name,
        staffCount: staff.length,
        activeStaff: staff.filter((s: any) => s.isActive).length,
        hasHead: !!dept.headId,
        headName: null, // Could be enriched
      });
    }

    return response.success({
      totalDepartments: summary.length,
      departments: summary,
    });
  },
  AC_DEPT_OPTS,
);
