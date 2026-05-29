import { v4 as uuidv4 } from 'uuid';
import { Keys, putItem, queryItems, updateItem } from '../config/dynamodb.config';
import { logger } from '../utils/logger';

export interface AIMemory { id: string; tenant_id: string; memory_type: string; content: string; context_tags: string[]; confidence_score: number; }

export class AiMemoryService {

    static async addMemory(tenantId: string, memoryType: string, content: string, tags: string[] = []): Promise<void> {
        logger.debug(`[AIMemory] Adding memory for tenant ${tenantId}: ${memoryType}`);
        const memId = uuidv4();
        await putItem({
            PK: Keys.tenantPK(tenantId), SK: `AIMEMORY#${memId}`,
            entityType: 'AI_MEMORY', id: memId, tenantId,
            memoryType, content, contextTags: tags, confidenceScore: 50,
            createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
        });
    }

    static async getMemoryContext(tenantId: string, tagsFilter?: string[], limit = 20): Promise<AIMemory[]> {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'AIMEMORY#');
        let items = result.items;
        if (tagsFilter && tagsFilter.length > 0) {
            items = items.filter(m => {
                const tags = m.contextTags || [];
                return tagsFilter.some(t => tags.includes(t));
            });
        }
        items.sort((a, b) => (b.confidenceScore || 0) - (a.confidenceScore || 0));
        return items.slice(0, limit).map(m => ({
            id: m.id, tenant_id: m.tenantId, memory_type: m.memoryType,
            content: m.content, context_tags: m.contextTags || [], confidence_score: m.confidenceScore || 0,
        }));
    }

    static async adjustConfidence(tenantId: string, memoryId: string, feedbackScore: number): Promise<void> {
        const adjustment = feedbackScore > 0 ? 5 : -5;
        const item = await import('../config/dynamodb.config').then(m => m.getItem<Record<string, any>>(Keys.tenantPK(tenantId), `AIMEMORY#${memoryId}`));
        if (!item) return;
        const newScore = Math.max(0, Math.min(100, (item.confidenceScore || 50) + adjustment));
        await updateItem(Keys.tenantPK(tenantId), `AIMEMORY#${memoryId}`, {
            updateExpression: 'SET confidenceScore = :score, lastReinforcedAt = :now',
            expressionAttributeValues: { ':score': newScore, ':now': new Date().toISOString() },
        });
    }
}
