// ============================================================================
// Lambda: getImportJobStatus
// ============================================================================
// Route: GET /inventory/import/:jobId
// Auth:  Cognito JWT — tenantId extracted from claims only (never client-supplied)
//
// Returns: ImportJob record with status, counts, and error details.
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import { Keys, getItem } from '../config/dynamodb.config';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import { ImportJob } from '../types/import.types';

export const getJobStatus = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const { tenantId } = auth;
        const jobId = event.pathParameters?.jobId;

        if (!jobId) {
            return response.error(400, 'VALIDATION_ERROR', 'jobId path parameter is required');
        }

        try {
            const job = await getItem<ImportJob>(
                Keys.tenantPK(tenantId),
                Keys.importJobSK(jobId),
            );

            if (!job) {
                return response.error(404, 'NOT_FOUND', `Import job ${jobId} not found`);
            }

            // Rebuild counts from flat DynamoDB attributes (stored as counts_created etc.)
            const jobAny = job as unknown as Record<string, unknown>;
            const counts = {
                total: (jobAny.countsTotal as number) ?? job.counts?.total ?? 0,
                created: (jobAny.counts_created as number) ?? job.counts?.created ?? 0,
                updated: (jobAny.counts_updated as number) ?? job.counts?.updated ?? 0,
                skipped: (jobAny.counts_skipped as number) ?? job.counts?.skipped ?? 0,
                errors: (jobAny.counts_errorsCount as number) ?? job.counts?.errors ?? 0,
                queued: (jobAny.countsQueued as number) ?? job.counts?.queued ?? 0,
            };

            const result = {
                jobId: job.jobId,
                tenantId: job.tenantId,
                status: job.status,
                source: job.source,
                originalFileName: job.originalFileName,
                fileSizeBytes: job.fileSizeBytes,
                businessType: job.businessType,
                counts,
                errors: job.errors ?? [],
                createdAt: job.createdAt,
                updatedAt: job.updatedAt,
                completedAt: job.completedAt,
            };

            logger.info('[GetJobStatus] Returned job', { jobId, status: job.status, tenantId });
            return response.success(result);

        } catch (err) {
            logger.error('[GetJobStatus] Error', {
                error: (err as Error).message,
                jobId,
                tenantId,
            });
            return response.internalError();
        }
    },
);

// ── List recent import jobs for tenant ────────────────────────────────────
// Route: GET /inventory/import  (no jobId → list last 20 jobs)

export const listJobs = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth) => {
        const { tenantId } = auth;

        try {
            const { queryItems } = await import('../config/dynamodb.config');
            const result = await queryItems<ImportJob>(
                Keys.tenantPK(tenantId),
                'IMPORTJOB#',
                {
                    limit: 20,
                    scanIndexForward: false,
                },
            );

            const jobs = result.items.map(job => {
                const jobAny = job as unknown as Record<string, unknown>;
                return {
                    jobId: job.jobId,
                    status: job.status,
                    source: job.source,
                    originalFileName: job.originalFileName,
                    businessType: job.businessType,
                    counts: {
                        total: (jobAny.countsTotal as number) ?? job.counts?.total ?? 0,
                        created: (jobAny.counts_created as number) ?? job.counts?.created ?? 0,
                        updated: (jobAny.counts_updated as number) ?? job.counts?.updated ?? 0,
                        skipped: (jobAny.counts_skipped as number) ?? job.counts?.skipped ?? 0,
                        errors: (jobAny.counts_errorsCount as number) ?? job.counts?.errors ?? 0,
                    },
                    createdAt: job.createdAt,
                    completedAt: job.completedAt,
                };
            });

            return response.success({ jobs, count: jobs.length });

        } catch (err) {
            logger.error('[ListJobs] Error', { error: (err as Error).message, tenantId });
            return response.internalError();
        }
    },
);
