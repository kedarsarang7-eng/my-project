import { AIService } from '../services/ai.service';
import { logger } from '../utils/logger';

import { SalesIntelligenceAgent } from './specialized/sales.agent';
import { InventoryManagementAgent } from './specialized/inventory.agent';
import { FinanceProfitAgent } from './specialized/finance.agent';
import { StaffMonitoringAgent } from './specialized/staff.agent';
import { BusinessIntelligenceAgent } from './specialized/bi.agent';
import { CustomerRelationshipAgent } from './specialized/customer.agent';
import { PurchaseOptimizationAgent } from './specialized/purchase.agent';
import { AIStrategyAgent } from './specialized/strategy.agent';

export class OrchestratorAgent {

    /**
     * Routes an incoming user query to the appropriate specialized agents,
     * executes their tasks, and merges the results.
     */
    static async handleUserQuery(tenantId: string, query: string): Promise<any> {
        logger.info(`[Orchestrator] Analyzing query for routing: "${query}" (Tenant: ${tenantId})`);

        // Phase 1: Ask the LLM (Orchestrator role) to identify which agents are needed.
        const routingPrompt = `You are the AI Orchestrator Agent for DukanX.
Your job is to analyze the user's request and decide which specialized agents should handle it.

Available Agents:
- sales: Sales Intelligence (sales data, top products, trends)
- inventory: Inventory Management (stock levels, out of stock, reorders)
- finance: Finance & Profit (margins, expenses, daily profit)
- staff: Staff Monitoring (productivity, analysis)
- bi: Business Intelligence (patterns, general overview)
- customer: Customer Relationship (credit balance, reminders)
- purchase: Purchase Optimization (supplier quantities)
- strategy: AI Strategy (high-level business strategy)

User Request: "${query}"

Return ONLY a JSON array of agent IDs that are required to fulfill this request. 
Example output: ["sales", "inventory"]
If the query is generic and doesn't map to a specific function, return ["bi"].`;

        let requiredAgents: string[] = [];
        try {
            // We use processCommand without tools to get a pure JSON response if possible.
            // But we must parse it carefully.
            const routeResponse = await AIService.processCommand(tenantId, routingPrompt, "You output strictly valid JSON.", []);
            let routeText = routeResponse.text.trim();
            // Handle markdown code blocks
            if (routeText.startsWith('\`\`\`json')) {
                routeText = routeText.replace('\`\`\`json', '').replace('\`\`\`', '').trim();
            } else if (routeText.startsWith('\`\`\`')) {
                routeText = routeText.replace('\`\`\`', '').replace('\`\`\`', '').trim();
            }

            requiredAgents = JSON.parse(routeText);

            if (!Array.isArray(requiredAgents) || requiredAgents.length === 0) {
                requiredAgents = ["bi"]; // fallback
            }
        } catch (error) {
            logger.warn(`[Orchestrator] Failed to parse routing JSON. Fallback to BI agent. Error: ${error}`);
            requiredAgents = ["bi"];
        }

        logger.info(`[Orchestrator] Routing query to agents: ${requiredAgents.join(', ')}`);

        // Phase 2: Execute tasks across selected agents
        const agentResults: any[] = [];

        for (const agentId of requiredAgents) {
            let agentInstance;
            switch (agentId) {
                case 'sales': agentInstance = new SalesIntelligenceAgent(); break;
                case 'inventory': agentInstance = new InventoryManagementAgent(); break;
                case 'finance': agentInstance = new FinanceProfitAgent(); break;
                case 'staff': agentInstance = new StaffMonitoringAgent(); break;
                case 'customer': agentInstance = new CustomerRelationshipAgent(); break;
                case 'purchase': agentInstance = new PurchaseOptimizationAgent(); break;
                case 'strategy': agentInstance = new AIStrategyAgent(); break;
                case 'bi':
                default:
                    agentInstance = new BusinessIntelligenceAgent(); break;
            }

            try {
                const res = await agentInstance.executeTask(tenantId, query);
                agentResults.push({ agent: agentInstance.name, result: res });
            } catch (err: any) {
                logger.error(`[Orchestrator] Failed executing ${agentId}: ${err.message}`);
                agentResults.push({ agent: agentId, result: { error: err.message } });
            }
        }

        // Phase 3: Combine outputs (for now, simply append. A more advanced implemention would pass it back to LLM for final synthesis)
        const synthesizePrompt = `You are the Orchestrator Agent. Merge the following agent reports into a single, cohesive, and professional response to the user.
User Query: "${query}"
Agent Reports: ${JSON.stringify(agentResults)}
`;
        const finalResponse = await AIService.processCommand(tenantId, synthesizePrompt, "You are a helpful synthesizing assistant.", []);

        return {
            text: finalResponse.text,
            routed_agents: requiredAgents,
            raw_reports: agentResults
        };
    }
}
