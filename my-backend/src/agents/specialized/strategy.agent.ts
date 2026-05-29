import { BaseAgent } from '../base.agent';

export class AIStrategyAgent extends BaseAgent {
    public name = 'AI Strategy Agent';
    public role = 'Highest-level intelligence. Combine insights from all agents to generate holistic business strategy suggestions.';
    public capabilities = [
        'combine cross-domain insights',
        'generate business strategy suggestions',
        'notify the owner'
    ];
    protected tools = ['notify_owner', 'generate_daily_report'];
}
