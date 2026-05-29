import { BaseAgent } from '../base.agent';

export class PurchaseOptimizationAgent extends BaseAgent {
    public name = 'Purchase Optimization Agent';
    public role = 'Analyze supplier purchases, recommend optimal buying quantities, and reduce overstock.';
    public capabilities = [
        'analyze supplier purchases',
        'recommend optimal buying quantities',
        'reduce overstock'
    ];
    protected tools = ['get_inventory_levels', 'create_purchase_order'];
}
