// ============================================================================
// PHARMACY WEBSOCKET EVENT HANDLER
// ============================================================================
// Handles real-time WebSocket events for pharmacy dashboard
// Integrates with pharmacy dashboard service for live updates
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import { logger } from '../utils/logger';
import { PharmacyDashboardService } from '../services/pharmacy-dashboard.service';

interface WebSocketClient {
    id: string;
    tenantId: string;
    businessType: string;
    socket: any; // WebSocket instance
    subscribedEvents: Set<string>;
}

interface WSEvent {
    name: string;
    data: any;
    tenantId: string;
    timestamp: string;
}

export class PharmacyWebSocketHandler {
    private pharmacyService: PharmacyDashboardService;
    private clients: Map<string, WebSocketClient> = new Map();

    constructor() {
        this.pharmacyService = new PharmacyDashboardService();
    }

    // ── CLIENT MANAGEMENT ─────────────────────────────────────────────────────

    addClient(clientId: string, tenantId: string, businessType: string, socket: any): void {
        if (businessType !== 'pharmacy') {
            return; // Only handle pharmacy clients
        }

        const client: WebSocketClient = {
            id: clientId,
            tenantId,
            businessType,
            socket,
            subscribedEvents: new Set([
                'inventory.stock.updated',
                'prescription.dispensed',
                'activity.new',
                'stock.threshold.breach',
            ]),
        };

        this.clients.set(clientId, client);
        logger.info(`Pharmacy WebSocket client connected: ${clientId} for tenant: ${tenantId}`);

        // Send initial connection confirmation
        this.sendToClient(clientId, {
            type: 'connection',
            status: 'connected',
            timestamp: new Date().toISOString(),
        });
    }

    removeClient(clientId: string): void {
        const client = this.clients.get(clientId);
        if (client) {
            this.clients.delete(clientId);
            logger.info(`Pharmacy WebSocket client disconnected: ${clientId}`);
        }
    }

    // ── EVENT HANDLING ─────────────────────────────────────────────────────

    async handleEvent(event: WSEvent): Promise<void> {
        const relevantClients = Array.from(this.clients.values())
            .filter(client => client.tenantId === event.tenantId);

        if (relevantClients.length === 0) {
            return; // No relevant clients for this tenant
        }

        logger.info(`Broadcasting pharmacy event ${event.name} to ${relevantClients.length} clients`);

        switch (event.name) {
            case 'inventory.stock.updated':
                await this.handleInventoryUpdate(event, relevantClients);
                break;
            case 'prescription.dispensed':
                await this.handlePrescriptionDispensed(event, relevantClients);
                break;
            case 'activity.new':
                await this.handleNewActivity(event, relevantClients);
                break;
            case 'stock.threshold.breach':
                await this.handleStockThresholdBreach(event, relevantClients);
                break;
            default:
                logger.warn(`Unknown pharmacy event: ${event.name}`);
        }
    }

    private async handleInventoryUpdate(event: WSEvent, clients: WebSocketClient[]): Promise<void> {
        // Clear relevant caches
        const cacheKeys = [
            `pharmacy-inventory-status:${event.tenantId}`,
            `pharmacy-lowstock:${event.tenantId}`,
            `pharmacy-lowstock-alerts:${event.tenantId}`,
        ];

        // Clear caches (this would integrate with your cache implementation)
        for (const key of cacheKeys) {
            // await clearCache(key);
        }

        // Broadcast to subscribed clients
        const payload = {
            type: 'inventory.update',
            data: event.data,
            timestamp: event.timestamp,
        };

        clients.forEach(client => {
            if (client.subscribedEvents.has('inventory.stock.updated')) {
                this.sendToClient(client.id, payload);
            }
        });
    }

    private async handlePrescriptionDispensed(event: WSEvent, clients: WebSocketClient[]): Promise<void> {
        // Clear relevant caches
        const cacheKeys = [
            `pharmacy-prescriptions:${event.tenantId}:last30days`,
            `pharmacy-activity:${event.tenantId}:20`,
        ];

        // Clear caches
        for (const key of cacheKeys) {
            // await clearCache(key);
        }

        // Broadcast to subscribed clients
        const payload = {
            type: 'prescription.dispensed',
            data: event.data,
            timestamp: event.timestamp,
        };

        clients.forEach(client => {
            if (client.subscribedEvents.has('prescription.dispensed')) {
                this.sendToClient(client.id, payload);
            }
        });
    }

    private async handleNewActivity(event: WSEvent, clients: WebSocketClient[]): Promise<void> {
        // Clear activity cache
        // await clearCache(`pharmacy-activity:${event.tenantId}:20`);

        // Broadcast to subscribed clients
        const payload = {
            type: 'activity.new',
            data: event.data,
            timestamp: event.timestamp,
        };

        clients.forEach(client => {
            if (client.subscribedEvents.has('activity.new')) {
                this.sendToClient(client.id, payload);
            }
        });
    }

    private async handleStockThresholdBreach(event: WSEvent, clients: WebSocketClient[]): Promise<void> {
        // Clear low stock caches
        const cacheKeys = [
            `pharmacy-lowstock:${event.tenantId}`,
            `pharmacy-lowstock-alerts:${event.tenantId}`,
        ];

        // Clear caches
        for (const key of cacheKeys) {
            // await clearCache(key);
        }

        // Broadcast to subscribed clients with high priority
        const payload = {
            type: 'stock.alert',
            data: event.data,
            timestamp: event.timestamp,
            priority: 'high',
        };

        clients.forEach(client => {
            if (client.subscribedEvents.has('stock.threshold.breach')) {
                this.sendToClient(client.id, payload);
            }
        });

        // Also send browser notification if supported
        clients.forEach(client => {
            this.sendToClient(client.id, {
                type: 'notification',
                title: 'Stock Alert',
                message: `${event.data.productName} is running low (${event.data.currentStock} units remaining)`,
                data: event.data,
                timestamp: event.timestamp,
            });
        });
    }

    // ── CLIENT COMMUNICATION ─────────────────────────────────────────────────

    private sendToClient(clientId: string, payload: any): void {
        const client = this.clients.get(clientId);
        if (client && client.socket.readyState === 1) { // WebSocket.OPEN
            try {
                client.socket.send(JSON.stringify(payload));
            } catch (error) {
                logger.error(`Error sending message to client ${clientId}:`, { 
                    message: error instanceof Error ? error.message : String(error),
                    stack: error instanceof Error ? error.stack : undefined 
                });
                // Remove problematic client
                this.removeClient(clientId);
            }
        }
    }

    // ── EVENT TRIGGERS ─────────────────────────────────────────────────────

    // These methods would be called from other parts of your application
    // when relevant events occur

    triggerInventoryUpdate(tenantId: string, productId: string, newQuantity: number, productName: string): void {
        const event: WSEvent = {
            name: 'inventory.stock.updated',
            data: {
                productId,
                productName,
                newQuantity,
                timestamp: new Date().toISOString(),
            },
            tenantId,
            timestamp: new Date().toISOString(),
        };

        this.handleEvent(event);
    }

    triggerPrescriptionDispensed(tenantId: string, prescriptionId: string, patientName: string, medication: string): void {
        const event: WSEvent = {
            name: 'prescription.dispensed',
            data: {
                prescriptionId,
                patientName,
                medication,
                timestamp: new Date().toISOString(),
            },
            tenantId,
            timestamp: new Date().toISOString(),
        };

        this.handleEvent(event);
    }

    triggerNewActivity(tenantId: string, activityType: string, description: string, actor: string): void {
        const event: WSEvent = {
            name: 'activity.new',
            data: {
                type: activityType,
                description,
                actor,
                timestamp: new Date().toISOString(),
            },
            tenantId,
            timestamp: new Date().toISOString(),
        };

        this.handleEvent(event);
    }

    triggerStockThresholdBreach(tenantId: string, productId: string, productName: string, currentStock: number, reorderPoint: number): void {
        const event: WSEvent = {
            name: 'stock.threshold.breach',
            data: {
                productId,
                productName,
                currentStock,
                reorderPoint,
                severity: currentStock <= 10 ? 'critical' : 'warning',
                timestamp: new Date().toISOString(),
            },
            tenantId,
            timestamp: new Date().toISOString(),
        };

        this.handleEvent(event);
    }

    // ── UTILITY METHODS ─────────────────────────────────────────────────────

    getClientCount(): number {
        return this.clients.size;
    }

    getTenantClientCount(tenantId: string): number {
        return Array.from(this.clients.values())
            .filter(client => client.tenantId === tenantId)
            .length;
    }

    // Health check method
    async healthCheck(): Promise<{ status: string; clientCount: number }> {
        return {
            status: 'healthy',
            clientCount: this.clients.size,
        };
    }
}

// Singleton instance
export const pharmacyWebSocketHandler = new PharmacyWebSocketHandler();
