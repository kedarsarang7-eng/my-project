import { BaseAgent } from '../base.agent';

export class StaffMonitoringAgent extends BaseAgent {
    public name = 'Staff Monitoring Agent';
    public role = 'Analyze staff sales, detect suspicious refunds or voids, and track staff productivity.';
    public capabilities = [
        'analyze staff sales',
        'detect suspicious refunds',
        'track productivity'
    ];
    protected tools = ['get_staff_activity', 'get_voided_invoices'];
}
