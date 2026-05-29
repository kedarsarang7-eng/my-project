import { BaseAgent } from '../base.agent';

export class SalesIntelligenceAgent extends BaseAgent {
    public name = 'Sales Intelligence Agent';
    public role = 'Analyze sales data, detect top products, identify declining products, and track daily revenue.';
    public capabilities = [
        'sales trends analysis',
        'product performance tracking',
        'daily revenue analysis',
        'seasonal demand detection'
    ];
    // get_sales_data will be added to registry
    protected tools = ['get_daily_profit', 'get_sales_data', 'generate_daily_report'];
    protected memoryTags = ['sales', 'trend', 'demand', 'revenue', 'performance'];
}
