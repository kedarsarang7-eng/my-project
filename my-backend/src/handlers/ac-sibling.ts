// ============================================================================
// ACADEMIC COACHING — SIBLING LINKING MODULE
// ============================================================================
// Link students as siblings for family management and fee discounts
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

const AC_SIBLING_OPTS = {
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
 * POST /ac/students/{id}/siblings
 * Link siblings to a student
 */
export const linkSiblings = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const primaryStudentId = event.pathParameters?.id;
    if (!primaryStudentId) return response.badRequest('Student ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { siblingStudentIds, relationship } = body;

    if (!siblingStudentIds || !Array.isArray(siblingStudentIds) || siblingStudentIds.length === 0) {
      return response.badRequest('siblingStudentIds array required');
    }

    const pk = Keys.tenantPK(auth.tenantId);

    // Verify primary student exists
    const primaryStudent = await getItem(pk, Keys.acStudentSK(primaryStudentId));
    if (!primaryStudent) return response.notFound('Primary student not found');

    // Generate family group ID
    const familyGroupId = uid();
    const ts = now();

    // Create sibling relationships
    const relationships = [];
    
    // Link primary to all siblings
    for (const siblingId of siblingStudentIds) {
      // Verify sibling exists
      const sibling = await getItem(pk, Keys.acStudentSK(siblingId));
      if (!sibling) {
        return response.notFound(`Sibling student ${siblingId} not found`);
      }

      // Check if already linked
      const existing = await queryAllItems(pk, 'AC_SIBLING_LINK#', {
        filterExpression: '(student1Id = :s1 AND student2Id = :s2) OR (student1Id = :s2 AND student2Id = :s1)',
        expressionAttributeValues: { ':s1': primaryStudentId, ':s2': siblingId },
      });

      if (existing.length === 0) {
        const linkId = uid();
        const link = {
          PK: pk,
          SK: `AC_SIBLING_LINK#${linkId}`,
          GSI1PK: `AC_SIBLINGS#${auth.tenantId}#${familyGroupId}`,
          GSI1SK: ts,
          id: linkId,
          familyGroupId,
          student1Id: primaryStudentId,
          student2Id: siblingId,
          relationship: relationship || 'brother',
          linkedAt: ts,
          linkedBy: auth.sub,
        };
        await putItem(link);
        relationships.push(link);
      }

      // Update student records with family group
      await updateItem(pk, Keys.acStudentSK(siblingId), {
        updateExpression: 'SET #familyGroupId = :familyGroupId, #updatedAt = :updatedAt',
        expressionAttributeNames: { '#familyGroupId': 'familyGroupId', '#updatedAt': 'updatedAt' },
        expressionAttributeValues: { ':familyGroupId': familyGroupId, ':updatedAt': ts },
      });
    }

    // Update primary student
    await updateItem(pk, Keys.acStudentSK(primaryStudentId), {
      updateExpression: 'SET #familyGroupId = :familyGroupId, #updatedAt = :updatedAt',
      expressionAttributeNames: { '#familyGroupId': 'familyGroupId', '#updatedAt': 'updatedAt' },
      expressionAttributeValues: { ':familyGroupId': familyGroupId, ':updatedAt': ts },
    });

    logger.info('Siblings linked', { tenantId: auth.tenantId, primaryStudentId, siblingCount: siblingStudentIds.length });

    return response.success({
      primaryStudentId,
      familyGroupId,
      siblingsLinked: siblingStudentIds.length,
      relationships,
    }, 201);
  },
  AC_SIBLING_OPTS,
);

/**
 * GET /ac/students/{id}/siblings
 * Get siblings of a student
 */
export const getSiblings = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const studentId = event.pathParameters?.id;
    if (!studentId) return response.badRequest('Student ID required');

    const pk = Keys.tenantPK(auth.tenantId);

    // Get student
    const student = await getItem<any>(pk, Keys.acStudentSK(studentId));
    if (!student) return response.notFound('Student not found');

    const familyGroupId = student.familyGroupId;
    if (!familyGroupId) {
      return response.success({ studentId, siblings: [], count: 0 });
    }

    // Get all links in family group
    const links = await queryAllItems(
      `AC_SIBLINGS#${auth.tenantId}#${familyGroupId}`,
      '',
      { indexName: 'GSI1' }
    );

    // Collect all student IDs in family
    const siblingIds = new Set<string>();
    for (const link of links as any[]) {
      siblingIds.add(link.student1Id);
      siblingIds.add(link.student2Id);
    }
    siblingIds.delete(studentId); // Remove self

    // Fetch sibling details
    const siblings = [];
    for (const id of siblingIds) {
      const s = await getItem(pk, Keys.acStudentSK(id));
      if (s) {
        siblings.push({
          id: (s as any).id,
          studentId: (s as any).studentId,
          name: `${(s as any).firstName} ${(s as any).lastName}`,
          class: (s as any).currentClass,
          status: (s as any).status,
        });
      }
    }

    return response.success({
      studentId,
      familyGroupId,
      siblings,
      count: siblings.length,
    });
  },
  AC_SIBLING_OPTS,
);

/**
 * GET /ac/families/{familyGroupId}
 * Get all members of a family
 */
export const getFamilyMembers = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const familyGroupId = event.pathParameters?.familyGroupId;
    if (!familyGroupId) return response.badRequest('Family Group ID required');

    const pk = Keys.tenantPK(auth.tenantId);

    // Get all links
    const links = await queryAllItems(
      `AC_SIBLINGS#${auth.tenantId}#${familyGroupId}`,
      '',
      { indexName: 'GSI1' }
    );

    // Collect all student IDs
    const studentIds = new Set<string>();
    for (const link of links as any[]) {
      studentIds.add(link.student1Id);
      studentIds.add(link.student2Id);
    }

    // Fetch all students
    const members = [];
    for (const id of studentIds) {
      const s = await getItem(pk, Keys.acStudentSK(id));
      if (s) {
        members.push(s);
      }
    }

    // Calculate total fees and discounts
    const totalFees = members.reduce((sum: number, m: any) => sum + (m.totalFees || 0), 0);

    return response.success({
      familyGroupId,
      members,
      memberCount: members.length,
      totalFees,
      potentialDiscount: members.length >= 2 ? totalFees * 0.05 : 0, // 5% sibling discount
    });
  },
  AC_SIBLING_OPTS,
);

/**
 * DELETE /ac/students/{id}/siblings/{siblingId}
 * Remove sibling link
 */
export const unlinkSibling = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const { id: studentId, siblingId } = event.pathParameters || {};
    if (!studentId || !siblingId) return response.badRequest('Both student IDs required');

    const pk = Keys.tenantPK(auth.tenantId);

    // Find the link
    const links = await queryAllItems(pk, 'AC_SIBLING_LINK#', {
      filterExpression: '(student1Id = :s1 AND student2Id = :s2) OR (student1Id = :s2 AND student2Id = :s1)',
      expressionAttributeValues: { ':s1': studentId, ':s2': siblingId },
    });

    if (links.length === 0) {
      return response.notFound('Sibling link not found');
    }

    // Delete the link
    for (const link of links as any[]) {
      await deleteItem(pk, `AC_SIBLING_LINK#${link.id}`);
    }

    logger.info('Siblings unlinked', { tenantId: auth.tenantId, studentId, siblingId });

    return response.success({ studentId, siblingId, unlinked: true });
  },
  AC_SIBLING_OPTS,
);

/**
 * GET /ac/families
 * List all families with multiple students
 */
export const listFamilies = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);

    // Get all sibling links
    const links = await queryAllItems(pk, 'AC_SIBLING_LINK#');

    // Group by family group ID
    const families: Record<string, Set<string>> = {};
    for (const link of links as any[]) {
      if (!families[link.familyGroupId]) {
        families[link.familyGroupId] = new Set();
      }
      families[link.familyGroupId].add(link.student1Id);
      families[link.familyGroupId].add(link.student2Id);
    }

    // Build family summaries
    const result = [];
    for (const [familyGroupId, studentIds] of Object.entries(families)) {
      const members = [];
      for (const id of studentIds) {
        const s = await getItem(pk, Keys.acStudentSK(id));
        if (s) {
          members.push({
            id: (s as any).id,
            name: `${(s as any).firstName} ${(s as any).lastName}`,
            class: (s as any).currentClass,
          });
        }
      }

      result.push({
        familyGroupId,
        memberCount: members.length,
        members,
      });
    }

    // Sort by member count desc
    result.sort((a, b) => b.memberCount - a.memberCount);

    return response.success(result);
  },
  AC_SIBLING_OPTS,
);
