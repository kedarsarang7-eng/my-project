// ============================================================================
// WebSocket Types — Real-Time Event System
// ============================================================================
// Type definitions for WebSocket connections, events, and broadcasting.
// Used by websocket.service.ts and websocket handler (Lambda).
// ============================================================================

/**
 * Client types that can connect to the WebSocket API.
 */
export enum ClientType {
    STAFF_APP = 'staff_app',
    CUSTOMER_APP = 'customer_app',
    RESTAURANT_STAFF_APP = 'restaurant_staff_app',
    RESTAURANT_KDS = 'restaurant_kds',
    ADMIN_PANEL = 'admin_panel',
    DESKTOP_APP = 'desktop_app',
}

/**
 * All supported real-time event names.
 */
export enum WSEventName {
    // Orders
    ORDER_CREATED = 'order_created',
    ORDER_UPDATED = 'order_updated',
    ORDER_COMPLETED = 'order_completed',

    // Restaurant (KOT)
    KOT_CREATED = 'kot_created',
    KOT_STATUS_UPDATED = 'kot_status_updated',
    KOT_ITEM_CANCELLED = 'kot_item_cancelled',
    CHECKOUT_REQUESTED = 'checkout_requested',

    // Payments
    PAYMENT_SUCCESS = 'payment_success',
    PAYMENT_FAILED = 'payment_failed',

    // Billing
    BILL_CREATED = 'bill_created',
    BILL_UPDATED = 'bill_updated',

    // Inventory
    INVENTORY_UPDATED = 'inventory_updated',
    STOCK_UPDATED = 'stock_updated',
    LOW_STOCK_ALERT = 'low_stock_alert',
    LOW_STOCK_RESOLVED = 'low_stock_resolved',
    EXPIRY_ALERT = 'expiry_alert',

    // Invoice lifecycle
    INVOICE_CREATED = 'invoice_created',

    // Staff
    STAFF_ACTIVITY = 'staff_activity',
    STAFF_SALE_CREATED = 'staff_sale_created',
    STAFF_LOGIN = 'staff_login',
    STAFF_LOGOUT = 'staff_logout',
    STAFF_ASSIGNED = 'staff_assigned',

    // Petrol pump
    PETROL_SALE_UPDATE = 'petrol_sale_update',
    DIESEL_SALE_UPDATE = 'diesel_sale_update',
    SHIFT_OPENED = 'shift_opened',
    SHIFT_CLOSED = 'shift_closed',
    VEHICLE_LINKED = 'vehicle_linked',

    // Clinic
    APPOINTMENT_CREATED = 'appointment_created',
    QUEUE_UPDATED = 'queue_updated',
    PRESCRIPTION_CREATED = 'prescription_created',

    // Service Business
    SERVICE_JOB_CREATED = 'service_job_created',
    SERVICE_STATUS_UPDATED = 'service_status_updated',

    // Pricing
    PRICE_UPDATED = 'price_updated',

    // Dashboard
    DASHBOARD_UPDATED = 'dashboard_updated',

    // Admin
    ADMIN_ACTION = 'admin_action',

    // Notifications
    NOTIFICATION = 'notification',

    // Sync
    SYNC_COMPLETED = 'sync_completed',
    DEVICE_SYNC = 'device_sync',
    CONNECTION_STATUS = 'connection_status',

    // Plan Feature System v2
    MANIFEST_INVALIDATED = 'manifest_invalidated',

    // Smart Inventory Import
    IMPORT_PROGRESS = 'import_progress',
    IMPORT_COMPLETED = 'import_completed',
    IMPORT_FAILED = 'import_failed',

    // In-Store Self Scan & Checkout
    IN_STORE_SESSION_STARTED = 'in_store_session_started',
    IN_STORE_CART_UPDATED = 'in_store_cart_updated',
    IN_STORE_PAYMENT_SUCCESS = 'in_store_payment_success',
    IN_STORE_EXIT_QR_READY = 'in_store_exit_qr_ready',
    IN_STORE_ORDER_VERIFIED = 'in_store_order_verified',

    // Decoration & Catering (DC)
    DC_EVENT_CREATED = 'dc_event_created',
    DC_EVENT_UPDATED = 'dc_event_updated',
    DC_EVENT_STATUS_CHANGED = 'dc_event_status_changed',
    DC_INVOICE_CREATED = 'dc_invoice_created',
    DC_PAYMENT_RECEIVED = 'dc_payment_received',
    DC_EXPENSE_ADDED = 'dc_expense_added',
    DC_STAFF_ASSIGNED = 'dc_staff_assigned',
    DC_INVENTORY_LOW_STOCK = 'dc_inventory_low_stock',
    DC_QUOTE_CONVERTED = 'dc_quote_converted',
    DC_KOT_CREATED = 'dc_kot_created',
    DC_KOT_UPDATED = 'dc_kot_updated',

    // Academic Coaching (AC)
    AC_STUDENT_ENROLLED = 'ac_student_enrolled',
    AC_STUDENT_TRANSFERRED = 'ac_student_transferred',
    AC_FEE_COLLECTED = 'ac_fee_collected',
    AC_INVOICE_GENERATED = 'ac_invoice_generated',
    AC_INVOICE_PAID = 'ac_invoice_paid',
    AC_FEE_OVERDUE = 'ac_fee_overdue',
    AC_ATTENDANCE_MARKED = 'ac_attendance_marked',
    AC_LOW_ATTENDANCE_ALERT = 'ac_low_attendance_alert',
    AC_RESULTS_PUBLISHED = 'ac_results_published',
    AC_EXAM_SCHEDULED = 'ac_exam_scheduled',
    AC_BATCH_FULL = 'ac_batch_full',
    AC_TIMETABLE_UPDATED = 'ac_timetable_updated',
    AC_MATERIAL_UPLOADED = 'ac_material_uploaded',
}

/**
 * Structure of a WebSocket event payload sent to clients.
 */
export interface WSEvent {
    event: WSEventName;
    businessId: string;
    timestamp: string;
    data: Record<string, unknown>;
    /** Replay sequence number for missed-event recovery (Phase 4) */
    seq?: number;
}

/**
 * Metadata stored for each active WebSocket connection in DynamoDB.
 */
export interface WSConnectionRecord {
    connectionId: string;
    clientType: ClientType;
    businessId: string;
    userId: string;
    staffId?: string;
    deviceId?: string;
    connectedAt: string;
    ttl: number;
    /** Events this connection is interested in (Phase 2: server-side filtering) */
    subscribedEvents?: WSEventName[];
    /** Whether this connection/user is currently online (Phase 4: Presence) */
    isOnline?: boolean;
    /** Last activity timestamp for presence tracking (Phase 4) */
    lastSeenAt?: string;
}

/**
 * Query parameters expected on the WebSocket $connect request.
 */
export interface WSConnectParams {
    authToken: string;
    clientType: ClientType;
    businessId: string;
    staffId?: string;
    deviceId?: string;
}

/**
 * Incoming WebSocket message from a connected client.
 */
export interface WSClientMessage {
    action: 'subscribe' | 'unsubscribe' | 'ping' | 'presence';
    events?: WSEventName[];
    /** Presence status update (Phase 4) */
    status?: 'online' | 'away' | 'offline';
}

/**
 * EventBridge event detail structure (Phase 2).
 * REST handlers emit events to EventBridge with this shape.
 */
export interface WSEventBridgeDetail {
    businessId: string;
    event: WSEventName;
    data: Record<string, unknown>;
    targetAudience: 'business' | 'staff' | 'customer' | 'owner' | 'client_type';
    targetClientType?: ClientType;
    targetUserId?: string;
}

/**
 * Offline message queued for disconnected clients (Phase 4).
 */
export interface WSOfflineMessage {
    messageId: string;
    businessId: string;
    userId: string;
    event: WSEventName;
    data: Record<string, unknown>;
    createdAt: string;
    ttl: number;
    delivered: boolean;
}

/**
 * Presence record for online/offline tracking (Phase 4).
 */
export interface WSPresenceRecord {
    userId: string;
    businessId: string;
    status: 'online' | 'away' | 'offline';
    lastSeenAt: string;
    activeConnections: number;
    clientTypes: ClientType[];
}
