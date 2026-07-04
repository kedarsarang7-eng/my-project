import { config } from '../config/environment';
// ============================================================================
// WhatsApp Service — Business Cloud API Integration (LEGACY)
// ============================================================================
// LEGACY PATH — Gated behind WA_LEGACY_CLOUD feature flag (default OFF).
// When the flag is OFF, all Meta Cloud API calls are blocked and callers
// receive a no-op response. New WhatsApp traffic MUST route through the
// canonical WhatsAppDispatchService (OpenWA gateway) instead.
//
// See: Req 10.6, 10.8 — consolidate all WhatsApp traffic onto OpenWA.
// ============================================================================

import { logger } from '../utils/logger';

const WHATSAPP_API_URL = config.whatsapp.apiUrl || 'https://graph.facebook.com/v17.0';
const PHONE_NUMBER_ID = config.whatsapp.phoneNumberId;
const ACCESS_TOKEN = config.whatsapp.accessToken;
const TEMPLATE_NAME = config.whatsapp.templateName || 'invoice_share';

interface PaymentConfirmationParams {
    customerPhone: string;
    customerName: string;
    amount: string;         // Formatted amount (e.g. "₹1,500.00")
    transactionId: string;
    invoiceNumber: string;
    invoicePdfUrl?: string;
}

/**
 * Send a payment confirmation message via WhatsApp.
 * Uses a pre-approved template message with dynamic parameters.
 *
 * LEGACY: Gated behind WA_LEGACY_CLOUD flag (default OFF).
 * When OFF, returns { success: false } without making any API call.
 */
export async function sendPaymentConfirmation(
    params: PaymentConfirmationParams
): Promise<{ success: boolean; messageId?: string }> {
    // ── WA_LEGACY_CLOUD gate (Req 10.6, 10.8) ──────────────────────────
    if (!config.whatsapp.legacyCloudEnabled) {
        logger.info('WhatsApp Meta Cloud API blocked — WA_LEGACY_CLOUD is OFF', {
            customerPhone: params.customerPhone,
            invoiceNumber: params.invoiceNumber,
        });
        return { success: false };
    }

    if (!PHONE_NUMBER_ID || !ACCESS_TOKEN) {
        logger.warn('WhatsApp not configured — skipping notification', {
            customerPhone: params.customerPhone,
        });
        return { success: false };
    }

    try {
        // Format phone number (ensure +91 prefix for India)
        const phone = formatPhoneNumber(params.customerPhone);

        const payload: Record<string, any> = {
            messaging_product: 'whatsapp',
            recipient_type: 'individual',
            to: phone,
            type: 'template',
            template: {
                name: TEMPLATE_NAME,
                language: { code: 'en' },
                components: [
                    {
                        type: 'body',
                        parameters: [
                            { type: 'text', text: params.customerName },
                            { type: 'text', text: params.amount },
                            { type: 'text', text: params.invoiceNumber },
                            { type: 'text', text: params.transactionId },
                        ],
                    },
                ],
            },
        };

        // Add document attachment if invoice PDF URL is available
        if (params.invoicePdfUrl) {
            payload.template.components.push({
                type: 'header',
                parameters: [
                    {
                        type: 'document',
                        document: {
                            link: params.invoicePdfUrl,
                            filename: `Invoice_${params.invoiceNumber}.pdf`,
                        },
                    },
                ],
            });
        }

        const response = await fetch(
            `${WHATSAPP_API_URL}/${PHONE_NUMBER_ID}/messages`,
            {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${ACCESS_TOKEN}`,
                },
                body: JSON.stringify(payload),
            }
        );

        const data = await response.json() as Record<string, any>;

        if (!response.ok) {
            logger.error('WhatsApp API error', {
                status: response.status,
                error: data.error,
                phone,
            });
            return { success: false };
        }

        const messageId = data.messages?.[0]?.id;
        logger.info('WhatsApp message sent', {
            phone,
            messageId,
            invoiceNumber: params.invoiceNumber,
        });

        return { success: true, messageId };

    } catch (err) {
        logger.error('WhatsApp send failed', {
            error: (err as Error).message,
            phone: params.customerPhone,
        });
        return { success: false };
    }
}

/**
 * Send a simple text message (non-template) for notifications.
 *
 * LEGACY: Gated behind WA_LEGACY_CLOUD flag (default OFF).
 * When OFF, returns false without making any API call.
 */
export async function sendTextMessage(
    phone: string,
    message: string
): Promise<boolean> {
    // ── WA_LEGACY_CLOUD gate (Req 10.6, 10.8) ──────────────────────────
    if (!config.whatsapp.legacyCloudEnabled) {
        logger.info('WhatsApp Meta Cloud API blocked — WA_LEGACY_CLOUD is OFF', {
            phone,
        });
        return false;
    }

    if (!PHONE_NUMBER_ID || !ACCESS_TOKEN) return false;

    try {
        const formattedPhone = formatPhoneNumber(phone);

        const response = await fetch(
            `${WHATSAPP_API_URL}/${PHONE_NUMBER_ID}/messages`,
            {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${ACCESS_TOKEN}`,
                },
                body: JSON.stringify({
                    messaging_product: 'whatsapp',
                    to: formattedPhone,
                    type: 'text',
                    text: { body: message },
                }),
            }
        );

        return response.ok;
    } catch {
        return false;
    }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

function formatPhoneNumber(phone: string): string {
    // Remove all non-digit characters
    let digits = phone.replace(/[^\d]/g, '');

    // Add India country code if not present
    if (digits.length === 10) {
        digits = '91' + digits;
    }

    return digits;
}
