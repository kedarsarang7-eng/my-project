// =============================================================================
// NotificationTemplates — Localized push / WhatsApp / SMS messages
// =============================================================================
// All message content is pulled from locale JSON files.
// Template functions enforce typed parameters so no placeholder is missed.
//
// Usage:
//   const msg = NotificationTemplates.billCreated('hi', {
//     customerName: 'रमेश', invoiceNo: 'INV-042',
//     amount: '1,234.50', shopName: 'राम किराना'
//   });
// =============================================================================

import { i18n, t } from './i18n.service';
import { formatCurrencyINR, formatDateForLocale } from './i18n.middleware';

// ---------------------------------------------------------------------------
// Typed parameter interfaces
// ---------------------------------------------------------------------------

export interface BillCreatedParams {
    customerName: string;
    invoiceNo: string;
    amount: string;
    shopName: string;
    link?: string;
}

export interface PaymentReceivedParams {
    customerName: string;
    amount: string;
    balance: string;
    shopName: string;
    date?: string;
}

export interface PaymentReminderParams {
    customerName: string;
    amount: string;
    dueDate: string;
    phone: string;
    shopName: string;
}

export interface LowStockParams {
    productName: string;
    quantity: number;
    unit: string;
}

export interface ExpiryWarningParams {
    productName: string;
    date: string;
}

export interface PlanExpiringParams {
    days: number;
}

export interface NewOrderParams {
    customerName: string;
    orderNo?: string;
}

export interface DailySummaryParams {
    sales: string;
    bills: number;
    customers: number;
}

// ---------------------------------------------------------------------------
// Push notification payloads
// ---------------------------------------------------------------------------

export interface PushNotification {
    title: string;
    body: string;
    data?: Record<string, string>;
}

// ---------------------------------------------------------------------------
// NotificationTemplates
// ---------------------------------------------------------------------------

export const NotificationTemplates = {

    // ── Push Notifications ─────────────────────────────────────────────────

    billCreatedPush(locale: string, p: BillCreatedParams): PushNotification {
        return {
            title: t('billing.invoiceCreated', locale, { invoiceNo: p.invoiceNo }),
            body: t('notifications.billCreated', locale, {
                customerName: p.customerName,
                invoiceNo: p.invoiceNo,
            }),
            data: { type: 'bill', invoiceNo: p.invoiceNo },
        };
    },

    paymentReceivedPush(locale: string, p: PaymentReceivedParams): PushNotification {
        return {
            title: t('billing.paymentRecorded', locale, { amount: p.amount }),
            body: t('notifications.paymentReceived', locale, {
                customerName: p.customerName,
                amount: p.amount,
            }),
            data: { type: 'payment' },
        };
    },

    lowStockPush(locale: string, p: LowStockParams): PushNotification {
        return {
            title: t('inventory.lowStockAlert', locale, {
                productName: p.productName,
                quantity: String(p.quantity),
                unit: p.unit,
            }),
            body: t('notifications.lowStock', locale, {
                productName: p.productName,
                quantity: String(p.quantity),
                unit: p.unit,
            }),
            data: { type: 'low_stock' },
        };
    },

    expiryWarningPush(locale: string, p: ExpiryWarningParams): PushNotification {
        return {
            title: t('inventory.expiryWarning', locale, {
                productName: p.productName,
                date: p.date,
            }),
            body: t('notifications.expiryWarning', locale, {
                productName: p.productName,
                date: p.date,
            }),
            data: { type: 'expiry' },
        };
    },

    planExpiringPush(locale: string, p: PlanExpiringParams): PushNotification {
        return {
            title: 'DukanX',
            body: t('notifications.planExpiring', locale, { days: String(p.days) }),
            data: { type: 'plan_expiry' },
        };
    },

    newOrderPush(locale: string, p: NewOrderParams): PushNotification {
        return {
            title: 'DukanX',
            body: t('notifications.newOrder', locale, { customerName: p.customerName }),
            data: { type: 'new_order', orderNo: p.orderNo ?? '' },
        };
    },

    dailySummaryPush(locale: string, p: DailySummaryParams): PushNotification {
        return {
            title: 'DukanX',
            body: t('notifications.dailySummary', locale, {
                sales: p.sales,
                bills: String(p.bills),
                customers: String(p.customers),
            }),
            data: { type: 'daily_summary' },
        };
    },

    // ── WhatsApp Messages ──────────────────────────────────────────────────

    whatsappBill(locale: string, p: BillCreatedParams): string {
        return t('whatsapp.billCreated', locale, {
            customerName: p.customerName,
            invoiceNo: p.invoiceNo,
            amount: p.amount,
            shopName: p.shopName,
            link: p.link ?? '',
        });
    },

    whatsappPayment(locale: string, p: PaymentReceivedParams): string {
        return t('whatsapp.paymentReceived', locale, {
            customerName: p.customerName,
            amount: p.amount,
            balance: p.balance,
            shopName: p.shopName,
            date: p.date ?? new Date().toLocaleDateString('en-IN'),
        });
    },

    whatsappReminder(locale: string, p: PaymentReminderParams): string {
        return t('whatsapp.paymentReminder', locale, {
            customerName: p.customerName,
            amount: p.amount,
            dueDate: p.dueDate,
            phone: p.phone,
            shopName: p.shopName,
        });
    },

    whatsappOrderConfirmation(
        locale: string,
        params: {
            customerName: string;
            orderNo: string;
            date: string;
            shopName: string;
        },
    ): string {
        return t('whatsapp.orderConfirmation', locale, params);
    },

    // ── SMS Messages (160 char limit) ──────────────────────────────────────

    smsBill(locale: string, params: {
        shopName: string;
        invoiceNo: string;
        amount: string;
    }): string {
        return t('sms.billCreated', locale, params);
    },

    smsPayment(locale: string, params: {
        shopName: string;
        amount: string;
        balance: string;
    }): string {
        return t('sms.paymentReceived', locale, params);
    },

    smsReminder(locale: string, params: {
        shopName: string;
        amount: string;
        phone: string;
    }): string {
        return t('sms.paymentReminder', locale, params);
    },

    smsOtp(locale: string, otp: string, minutes = 10): string {
        return i18n.smsOtp(locale, otp, minutes);
    },

    // ── PDF Labels ─────────────────────────────────────────────────────────

    pdfLabels(locale: string): Record<string, string> {
        const keys = [
            'invoiceTitle', 'billTo', 'shipTo', 'description', 'qty', 'rate',
            'amount', 'taxableAmount', 'cgst', 'sgst', 'igst', 'grandTotal',
            'amountInWords', 'authorizedSignatory', 'thankYou', 'termsConditions',
            'notes', 'originalForRecipient', 'duplicateForSupplier',
            'computerGeneratedInvoice',
        ];
        return Object.fromEntries(
            keys.map((key) => [key, t(`pdf.${key}`, locale)]),
        );
    },
};
