// ============================================================================
// Payment Gateway Factory
// ============================================================================
// Returns the correct PaymentGateway implementation based on gateway type.
// Uses the Strategy pattern — new gateways can be added with a single import.
// ============================================================================

import { GatewayType } from '../../types/payment.types';
import { PaymentGateway } from './gateway.interface';
import { PhonePeGateway } from './phonepe.gateway';
import { RazorpayGateway } from './razorpay.gateway';

// Singleton instances (stateless, reusable across invocations)
const gatewayInstances: Record<GatewayType, PaymentGateway> = {
    [GatewayType.PHONEPE]: new PhonePeGateway(),
    [GatewayType.RAZORPAY]: new RazorpayGateway(),
};

/**
 * Get the payment gateway implementation for the given type.
 * Throws if the gateway type is not supported.
 *
 * @param type - The gateway type enum value
 * @returns PaymentGateway instance
 */
export function getGateway(type: GatewayType): PaymentGateway {
    const gateway = gatewayInstances[type];
    if (!gateway) {
        throw new Error(`Unsupported payment gateway: ${type}`);
    }
    return gateway;
}

/**
 * Check if a gateway type is supported.
 */
export function isGatewaySupported(type: string): type is GatewayType {
    return Object.values(GatewayType).includes(type as GatewayType);
}

/**
 * Get list of all supported gateway types.
 */
export function getSupportedGateways(): GatewayType[] {
    return Object.values(GatewayType);
}
