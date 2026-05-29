import { OrchestratorAgent } from '../agents/orchestrator.agent';
import { logger } from '../utils/logger';

/**
 * Handle AWS EventBridge triggers containing business events for AI processing
 */
export const handleEvent = async (event: any): Promise<void> => {
    try {
        logger.info('[AI Event Processor] Received EventBridge event', { id: event.id, source: event.source });

        // Extract detail from EventBridge event
        const detail = event.detail;
        if (!detail || !detail.businessId) {
            logger.warn('[AI Event Processor] Missing detail or businessId in event', event);
            return;
        }

        const tenantId = detail.businessId;
        const eventName = detail.event;
        const eventData = detail.data;

        // Convert the raw event into a natural language analysis prompt for the Orchestrator
        const analysisPrompt = `A critical business event has occurred in the system.
Event Type: ${eventName}
Event Data: ${JSON.stringify(eventData)}

Please analyze this event across relevant dimensions. For example:
- If it is a low stock alert, have the Inventory agent evaluate it and Purchase agent suggest reorders.
- If it's a large sale, have the Finance and Sales agents assess impact.
- If it's suspicious staff activity, have the Staff agent monitor.
Use your tools or notify the owner if necessary.`;

        // Process through orchestrator asynchronously
        await OrchestratorAgent.handleUserQuery(tenantId, analysisPrompt);

        logger.info(`[AI Event Processor] Successfully processed event ${eventName} for tenant ${tenantId}`);
    } catch (error: any) {
        logger.error('[AI Event Processor] Error handling event:', error);
    }
};
