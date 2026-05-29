import { config } from '../config/environment';
import { Keys, getItem } from '../config/dynamodb.config';
import { getToolsForLLM, getToolDefinition } from './ai-tools.registry';
import { logger } from '../utils/logger';
import { decryptAiKey } from './kms.service';

interface TenantAIConfig {
    execution_mode: 'local' | 'cloud_key' | 'dukanx_cloud';
    provider: string;
    custom_endpoint: string | null;
    api_key: string | null;
}

export class AIService {

    static async getTenantConfig(tenantId: string): Promise<TenantAIConfig> {
        const settings = await getItem<Record<string, any>>(Keys.tenantPK(tenantId), 'AISETTINGS#META');
        if (!settings || !settings.isActive) {
            return { execution_mode: 'local', provider: config.ai.defaultProvider || 'ollama', custom_endpoint: 'http://localhost:11434', api_key: config.ai.apiKey || null };
        }

        let decryptedKey = null;
        if (settings.encryptedApiKey) decryptedKey = await decryptAiKey(settings.encryptedApiKey, tenantId);

        return { execution_mode: settings.executionMode, provider: settings.provider, custom_endpoint: settings.customEndpoint || 'http://localhost:11434', api_key: decryptedKey };
    }

    static async processCommand(tenantId: string, prompt: string, systemPromptOverride?: string, toolsOverride?: any[]): Promise<any> {
        const config = await this.getTenantConfig(tenantId);
        logger.info(`[AI] Processing command for tenant ${tenantId}. Mode: ${config.execution_mode}, Provider: ${config.provider}`);
        const tools = toolsOverride || getToolsForLLM();
        const systemPrompt = systemPromptOverride || "You are a helpful business assistant for DukanX. You help the business owner get data, calculate profits, send reminders, and navigate their ERP software. Use the available tools to answer questions.";

        if (config.execution_mode === 'local' || config.provider === 'ollama') {
            return await this.callOllama(config, systemPrompt, prompt, tools, tenantId);
        } else {
            return await this.callOpenAICompatible(config, systemPrompt, prompt, tools, tenantId);
        }
    }

    private static async callOllama(config: TenantAIConfig, system: string, prompt: string, tools: any, tenantId: string): Promise<any> {
        const endpoint = `${config.custom_endpoint}/api/chat`;
        try {
            const response = await fetch(endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ model: 'llama3', messages: [{ role: 'system', content: system }, { role: 'user', content: prompt }], tools, stream: false }) });
            if (!response.ok) throw new Error(`Ollama API error: ${response.statusText}`);
            const data: any = await response.json();
            const message = data.message;
            if (message.tool_calls && message.tool_calls.length > 0) {
                const results = [];
                for (const tc of message.tool_calls) { results.push({ tool: tc.function.name, result: await this.executeTool(tenantId, tc.function.name, tc.function.arguments) }); }
                return { text: `I have executed the command: ${results.map(r => r.tool).join(', ')}`, tools_executed: results };
            }
            return { text: message.content, tools_executed: [] };
        } catch (error: any) { logger.error('[AI] Ollama Error:', error); throw new Error('Local AI is unreachable.'); }
    }

    private static async callOpenAICompatible(config: TenantAIConfig, system: string, prompt: string, tools: any, tenantId: string): Promise<any> {
        let baseURL = 'https://api.openai.com/v1/chat/completions'; let model = 'gpt-4o-mini';
        if (config.provider === 'groq') { baseURL = 'https://api.groq.com/openai/v1/chat/completions'; model = 'llama-3.1-8b-instant'; }
        else if (config.provider === 'openrouter') { baseURL = 'https://openrouter.ai/api/v1/chat/completions'; model = 'meta-llama/llama-3-8b-instruct:free'; }
        else if (config.provider === 'deepseek') { baseURL = 'https://api.deepseek.com/chat/completions'; model = 'deepseek-chat'; }
        else if (config.provider === 'together') { baseURL = 'https://api.together.xyz/v1/chat/completions'; model = 'meta-llama/Llama-3-8b-chat-hf'; }
        else if (config.provider === 'gemini') { baseURL = 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions'; model = 'gemini-1.5-flash'; }

        if (!config.api_key) throw new Error(`Cloud API Key missing for provider: ${config.provider}`);
        try {
            const response = await fetch(baseURL, { method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${config.api_key}` }, body: JSON.stringify({ model, messages: [{ role: 'system', content: system }, { role: 'user', content: prompt }], tools, tool_choice: 'auto' }) });
            if (!response.ok) { const errBody = await response.text(); throw new Error(`Cloud API error: ${response.statusText} - ${errBody}`); }
            const data: any = await response.json();
            const message = data.choices[0].message;
            if (message.tool_calls && message.tool_calls.length > 0) {
                const results = [];
                for (const tc of message.tool_calls) { let parsedArgs = {}; try { parsedArgs = JSON.parse(tc.function.arguments); } catch {} results.push({ tool: tc.function.name, result: await this.executeTool(tenantId, tc.function.name, parsedArgs) }); }
                return { text: 'I have processed your command. Check the attached data.', tools_executed: results };
            }
            return { text: message.content, tools_executed: [] };
        } catch (error: any) { logger.error('[AI] Cloud API Error:', error); throw new Error(`Cloud AI Error: ${error.message}`); }
    }

    private static async executeTool(tenantId: string, functionName: string, args: any): Promise<any> {
        const tool = getToolDefinition(functionName);
        if (!tool) { logger.warn(`[AI] Unknown tool: ${functionName}`); return { error: `Tool ${functionName} not available.` }; }
        logger.info(`[AI Executing Tool] ${functionName} for tenant ${tenantId}`, args);
        try { return await tool.execute(tenantId, args); } catch (error: any) { logger.error(`[AI Tool Error] ${functionName}:`, error); return { error: `Execution failed: ${error.message}` }; }
    }
}
