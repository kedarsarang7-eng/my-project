import { BaseAgent } from '../base.agent';

export class InventoryManagementAgent extends BaseAgent {
    public name = 'Inventory Management Agent';
    public role = 'Monitor inventory levels, detect low stock, find fast moving products, and recommend reorders.';
    public capabilities = [
        'monitor inventory levels',
        'detect low stock',
        'detect fast-moving products',
        'recommend reorders',
        'auto-create purchase orders (if permitted)'
    ];
    protected tools = ['get_out_of_stock_products', 'get_inventory_levels', 'create_purchase_order'];
    protected memoryTags = ['inventory', 'stock', 'product', 'demand', 'reorder'];
}
