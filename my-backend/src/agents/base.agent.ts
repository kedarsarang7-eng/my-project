import { AIService } from '../services/ai.service';
import { getToolDefinition } from '../services/ai-tools.registry';
import { AiMemoryService } from '../services/ai-memory.service';
import { logger } from '../utils/logger';

export abstract class BaseAgent {
    public abstract name: string;
    public abstract role: string;
    public abstract capabilities: string[];
    protected abstract tools: string[]; // List of tool names this agent is allowed to use
    protected memoryTags?: string[];    // Optional tags to fetch specific long-term memory

    /**
     * Execute a specific task using the agent's specialized prompt and tools.
     */
    async executeTask(tenantId: string, prompt: string): Promise<any> {
        logger.info(`[Agent:${this.name}] Executing task for tenant ${tenantId}`);

        // Fetch specialized memory for this agent
        let memoryContext = '';
        try {
            const memoryList = await AiMemoryService.getMemoryContext(tenantId, this.memoryTags, 5);
            if (memoryList.length > 0) {
                memoryContext = '\nBusiness Insights & Memory Patterns:\n' +
                    memoryList.map(m => `- ${m.content} (Confidence: ${m.confidence_score}%)`).join('\n') + '\n';
            }
        } catch (err: any) {
            logger.warn(`[Agent:${this.name}] Failed to fetch memory: ${err.message}`);
        }

        const systemPrompt = `You are ${this.name}, a specialized AI agent for the DukanX ERP system.
Role: ${this.role}
Capabilities:
${this.capabilities.map(c => '- ' + c).join('\n')}
${memoryContext}
INSTRUCTIONS:
You must answer the user's query or perform the background analysis using only your specialized knowledge and available tools.
If a requested action falls outside your capabilities or tools, state clearly that you cannot perform it.
Be concise, analytical, and professional. Return clear insights.`;

        // Filter only the tools assigned to this agent
        const agentTools = this.tools
            .map(t => getToolDefinition(t))
            .filter(t => t !== undefined)
            .map(tool => ({
                type: 'function',
                function: {
                    name: tool!.name,
                    description: tool!.description,
                    parameters: tool!.parameters
                }
            }));

        try {
            const response = await AIService.processCommand(tenantId, prompt, systemPrompt, agentTools);
            return response;
        } catch (error: any) {
            logger.error(`[Agent:${this.name}] Task execution failed: ${error.message}`);
            throw error;
        }
    }
}
