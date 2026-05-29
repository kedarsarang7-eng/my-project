import { Request, Response } from 'express';
import { AIService } from '../services/ai.service';
import { Keys, getItem, putItem } from '../config/dynamodb.config';
import { z } from 'zod';
import { logger } from '../utils/logger';
import { getTenantId } from '../utils/context';
import { encryptAiKey } from '../services/kms.service';

const chatSchema = z.object({ prompt: z.string().min(1, 'Prompt cannot be empty') });
const settingsSchema = z.object({ execution_mode: z.enum(['local', 'cloud_key', 'dukanx_cloud']), provider: z.string().optional(), custom_endpoint: z.string().optional(), api_key: z.string().optional() });

export const chat = async (req: Request, res: Response): Promise<void> => {
    try {
        const tenantId = getTenantId();
        if (!tenantId) { res.status(401).json({ error: 'Unauthorized' }); return; }
        const { prompt } = chatSchema.parse(req.body);
        const aiResponse = await AIService.processCommand(tenantId, prompt);
        res.status(200).json(aiResponse);
    } catch (error: any) {
        if (error instanceof z.ZodError) { res.status(400).json({ error: 'Validation Error', details: error.issues }); return; }
        logger.error('[AI Handler] Chat Error:', error);
        // SECURITY FIX S-9: Never leak internal error details to client
        logger.error('AI chat error', { error: error.message });
        res.status(500).json({ error: 'An internal error occurred. Please try again.' });
    }
};

export const getSettings = async (req: Request, res: Response): Promise<void> => {
    try {
        const tenantId = getTenantId();
        if (!tenantId) { res.status(401).json({ error: 'Unauthorized' }); return; }
        const config = await AIService.getTenantConfig(tenantId);
        res.status(200).json({ ...config, api_key: config.api_key ? '********' : null });
    } catch (error: any) { logger.error('[AI Handler] Get Settings Error:', error); res.status(500).json({ error: 'Failed to fetch AI config' }); }
};

export const updateSettings = async (req: Request, res: Response): Promise<void> => {
    try {
        const tenantId = getTenantId();
        if (!tenantId) { res.status(401).json({ error: 'Unauthorized' }); return; }
        const data = settingsSchema.parse(req.body);
        let encryptedKey = null;
        if (data.api_key) encryptedKey = await encryptAiKey(data.api_key, tenantId);

        const existing = await getItem<Record<string, any>>(Keys.tenantPK(tenantId), 'AISETTINGS#META');
        await putItem({
            PK: Keys.tenantPK(tenantId), SK: 'AISETTINGS#META',
            entityType: 'AI_SETTINGS', tenantId,
            executionMode: data.execution_mode,
            provider: data.provider || 'ollama',
            customEndpoint: data.custom_endpoint || 'http://localhost:11434',
            encryptedApiKey: encryptedKey || existing?.encryptedApiKey || null,
            isActive: true,
            autonomousMode: existing?.autonomousMode || 'disabled',
            autoNotifyInventory: existing?.autoNotifyInventory || false,
            autoNotifyCredit: existing?.autoNotifyCredit || false,
            autoDailyReport: existing?.autoDailyReport || false,
            updatedAt: new Date().toISOString(),
            createdAt: existing?.createdAt || new Date().toISOString(),
        });

        res.status(200).json({ message: 'AI settings updated successfully' });
    } catch (error: any) {
        if (error instanceof z.ZodError) { res.status(400).json({ error: 'Validation Error', details: error.issues }); return; }
        logger.error('[AI Handler] Update Settings Error:', error);
        res.status(500).json({ error: 'Failed to update AI config' });
    }
};
