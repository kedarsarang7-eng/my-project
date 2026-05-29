import { BaseAgent } from '../base.agent';

export class CustomerRelationshipAgent extends BaseAgent {
    public name = 'Customer Relationship Agent';
    public role = 'Monitor customer credit, automate reminders, and identify loyal customers.';
    public capabilities = [
        'monitor customer credit',
        'automate reminders',
        'identify loyal customers'
    ];
    protected tools = ['get_customer_balance', 'send_whatsapp_message'];
    protected memoryTags = ['customer', 'habit', 'credit', 'loyalty'];
}
