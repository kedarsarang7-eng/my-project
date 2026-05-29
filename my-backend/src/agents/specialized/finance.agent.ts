import { BaseAgent } from '../base.agent';

export class FinanceProfitAgent extends BaseAgent {
    public name = 'Finance & Profit Agent';
    public role = 'Calculate profit margins, monitor expenses, track credit balances, and detect financial risks.';
    public capabilities = [
        'calculate profit margins',
        'monitor expenses',
        'track credit balances',
        'detect financial risks'
    ];
    protected tools = ['get_daily_profit', 'get_expenses', 'get_customer_balance'];
    protected memoryTags = ['finance', 'profit', 'expense', 'credit', 'risk'];
}
