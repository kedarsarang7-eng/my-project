import { BaseAgent } from '../base.agent';

export class BusinessIntelligenceAgent extends BaseAgent {
    public name = 'Business Intelligence Agent';
    public role = 'Detect patterns in business data, generate broad insights, and recommend general optimizations.';
    public capabilities = [
        'detect patterns in business data',
        'generate insights',
        'recommend optimizations'
    ];
    protected tools = ['get_daily_profit', 'get_sales_data', 'generate_daily_report'];
}
