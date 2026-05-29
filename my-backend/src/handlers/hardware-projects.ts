import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { parseBody } from '../middleware/validation';
import { createHardwareProjectSchema, createHardwareIndentSchema } from '../schemas';
import { FeatureKey } from '../config/plan-feature-registry';
import { BusinessType, UserRole } from '../types/tenant.types';
import { Keys, putItem, getItem, queryItems, updateItem } from '../config/dynamodb.config';
import * as response from '../utils/response';
import { logAudit } from '../middleware/audit';
import { recordRevision } from '../services/revision-history.service';

const HW_PROJECT_OPTS = {
    requiredBusinessType: BusinessType.HARDWARE,
    requiredFeature: FeatureKey.HARDWARE_CONTRACTOR_CREDIT,
};

export const createProject = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(createHardwareProjectSchema, event);
        if (!parsed.success) return parsed.error;

        const now = new Date().toISOString();
        const id = uuidv4();
        await putItem({
            PK: Keys.tenantPK(auth.tenantId),
            SK: `HWPROJECT#${id}`,
            entityType: 'HARDWARE_PROJECT',
            id,
            tenantId: auth.tenantId,
            projectName: parsed.data.projectName,
            contractorName: parsed.data.contractorName || null,
            customerId: parsed.data.customerId || null,
            siteAddress: parsed.data.siteAddress || null,
            notes: parsed.data.notes || null,
            status: 'active',
            createdBy: auth.sub,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
        }, 'attribute_not_exists(PK)');
        await recordRevision(
            auth.tenantId,
            'hardware_projects',
            id,
            'create',
            auth.sub,
            null,
            {
                projectName: parsed.data.projectName,
                contractorName: parsed.data.contractorName || null,
                customerId: parsed.data.customerId || null,
                status: 'active',
            },
            { source: 'hardware-projects.createProject' },
        );

        logAudit({
            action: 'HW_PROJECT_CREATED',
            resource: 'hardware_project',
            resourceId: id,
            metadata: { projectName: parsed.data.projectName },
        }).catch(() => { });

        return response.success({ id, status: 'active' }, 201);
    },
    HW_PROJECT_OPTS,
);

export const listProjects = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.ACCOUNTANT],
    async (_event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'HWPROJECT#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            scanIndexForward: false,
            limit: 200,
        });
        return response.success({ items: result.items });
    },
    HW_PROJECT_OPTS,
);

export const closeProject = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const projectId = event.pathParameters?.id;
        if (!projectId) return response.badRequest('Missing project id');

        const existing = await getItem<Record<string, any>>(Keys.tenantPK(auth.tenantId), `HWPROJECT#${projectId}`);
        if (!existing || existing.isDeleted) {
            return response.error(404, 'PROJECT_NOT_FOUND', 'Project not found');
        }
        if (existing.status === 'closed') {
            return response.success({ id: projectId, status: 'closed' });
        }

        const now = new Date().toISOString();
        await updateItem(Keys.tenantPK(auth.tenantId), `HWPROJECT#${projectId}`, {
            updateExpression: 'SET #s = :closed, updatedAt = :now',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':closed': 'closed', ':now': now },
            conditionExpression: 'attribute_exists(PK)',
        });
        await recordRevision(
            auth.tenantId,
            'hardware_projects',
            projectId,
            'status_change',
            auth.sub,
            { status: existing.status || 'active' },
            { status: 'closed' },
            { source: 'hardware-projects.closeProject' },
        );

        logAudit({
            action: 'HW_PROJECT_CLOSED',
            resource: 'hardware_project',
            resourceId: projectId,
        }).catch(() => { });

        return response.success({ id: projectId, status: 'closed' });
    },
    HW_PROJECT_OPTS,
);

export const createIndent = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const parsed = parseBody(createHardwareIndentSchema, event);
        if (!parsed.success) return parsed.error;

        const project = await getItem<Record<string, any>>(
            Keys.tenantPK(auth.tenantId),
            `HWPROJECT#${parsed.data.projectId}`,
        );
        if (!project || project.isDeleted) {
            return response.error(404, 'PROJECT_NOT_FOUND', 'Project not found');
        }

        const id = uuidv4();
        const now = new Date().toISOString();
        await putItem({
            PK: Keys.tenantPK(auth.tenantId),
            SK: `HWINDENT#${id}`,
            entityType: 'HARDWARE_INDENT',
            id,
            tenantId: auth.tenantId,
            projectId: parsed.data.projectId,
            requestedBy: parsed.data.requestedBy,
            priority: parsed.data.priority,
            items: parsed.data.items,
            notes: parsed.data.notes || null,
            status: 'open',
            createdBy: auth.sub,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
        }, 'attribute_not_exists(PK)');
        await recordRevision(
            auth.tenantId,
            'hardware_indents',
            id,
            'create',
            auth.sub,
            null,
            {
                projectId: parsed.data.projectId,
                requestedBy: parsed.data.requestedBy,
                priority: parsed.data.priority,
                itemCount: parsed.data.items.length,
                status: 'open',
            },
            { source: 'hardware-projects.createIndent' },
        );

        logAudit({
            action: 'HW_INDENT_CREATED',
            resource: 'hardware_indent',
            resourceId: id,
            metadata: { projectId: parsed.data.projectId, itemCount: parsed.data.items.length },
        }).catch(() => { });

        return response.success({ id, status: 'open' }, 201);
    },
    HW_PROJECT_OPTS,
);

export const listIndents = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const projectId = (event.queryStringParameters || {}).projectId;
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(auth.tenantId), 'HWINDENT#', {
            filterExpression: projectId
                ? '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND projectId = :pid'
                : '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: projectId
                ? { ':false': false, ':pid': projectId }
                : { ':false': false },
            scanIndexForward: false,
            limit: 200,
        });
        return response.success({ items: result.items });
    },
    HW_PROJECT_OPTS,
);

export const closeIndent = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const indentId = event.pathParameters?.id;
        if (!indentId) return response.badRequest('Missing indent id');

        const now = new Date().toISOString();
        await updateItem(Keys.tenantPK(auth.tenantId), `HWINDENT#${indentId}`, {
            updateExpression: 'SET #s = :closed, updatedAt = :now',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':closed': 'closed', ':now': now },
            conditionExpression: 'attribute_exists(PK)',
        });
        await recordRevision(
            auth.tenantId,
            'hardware_indents',
            indentId,
            'status_change',
            auth.sub,
            { status: 'open' },
            { status: 'closed' },
            { source: 'hardware-projects.closeIndent' },
        );
        return response.success({ id: indentId, status: 'closed' });
    },
    HW_PROJECT_OPTS,
);
