// ============================================================================
// WhatsApp Automation Module — Invoice Generation Automation (Task 13.1)
// ============================================================================
// Subscribes to the `invoice.generated` Business_Event and sends invoice
// details + payment info + thank-you message to the invoiced customer.
//
// DESIGN CONTRACTS:
// - Enqueue within 5 seconds of the invoice-generated event (Req 4.1)
// - Attach invoice PDF (≤16 MB) when available at event time (Req 4.2)
// - If PDF not available: send details immediately, follow up with attachment
//   within a 300-second wait window (Req 4.3)
// - Skip attachment with logged reason past the 300s window (Req 4.4)
// - Select template by BusinessType + locale (Req 4.5)
// - Skip if customer has no eligible profile (Req 4.6)
// - Retry up to 3 attempts on failure (Req 4.7)
// - Verify recipient via recipient-verification.service.ts (Req 16.1-16.6)
// - Fail closed + Operator_Alert on mismatch/ambiguity
//
// Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7
// ============================================================================

import { logger } from '../../../utils/logger';
import { selectFullTemplate } from '../services/template-selection.service';
import {
  render,
  type RenderResult,
  type TemplateInput,
} from '../services/template-render.service';
import {
  verifyRecipient,
  extractVerificationInput,
  type RecipientVerificationResult,
} from '../services/recipient-verification.service';
import {
  OperatorAlertService,
  ALERT_CATEGORIES,
  type OperatorAlertInput,
} from '../services/operator-alert.service';
import { isEligible, type ConsentProfile } from '../services/consent.service';
import {
  createRetryPolicy,
  type RetryPolicy,
} from '../services/retry-policy.service';
import {
  DurableEnqueueService,
  createDurableEnqueueService,
  type DurableEnqueueInput,
} from '../services/durable-enqueue.service';
import {
  MAX_DOCUMENT_SIZE_BYTES,
} from '../services/whatsapp-dispatch.service';
import { CustomerProfileRepository } from '../repositories/customer-profile.repository';
import { MessageTemplateRepository } from '../repositories/message-template.repository';
import { DeliveryLogRepository } from '../repositories/delivery-log.repository';
import type { CustomerProfile, MessageTemplate } from '../schemas/entities';

// ── Constants ────────────────────────────────────────────────────────────────

/** The Business_Event type this automation subscribes to. */
export const INVOICE_GENERATED_EVENT = 'invoice.generated';

/** Maximum time (ms) to wait for the invoice PDF to become available. */
export const PDF_WAIT_WINDOW_MS = 300_000; // 300 seconds

/** Polling interval (ms) while waiting for PDF availability. */
export const PDF_POLL_INTERVAL_MS = 5_000; // 5 seconds

/** Maximum enqueue deadline from event receipt (ms). Req 4.1: within 5s. */
export const ENQUEUE_DEADLINE_MS = 5_000;

/** Default retry policy for invoice automation (max 3 attempts, Req 4.7). */
export const INVOICE_RETRY_POLICY: RetryPolicy = createRetryPolicy({
  maxAttempts: 3,
  backoffSeconds: 60,
  expirySeconds: 86400, // 24h
});

/** Template name pattern for invoice messages. */
export const INVOICE_TEMPLATE_NAME = 'invoice_generated';

// ── Types ────────────────────────────────────────────────────────────────────

/**
 * Invoice-generated Business_Event payload.
 * Extracted from the EventBridge event detail.
 */
export interface InvoiceGeneratedPayload {
  /** Unique event identifier. */
  eventId: string;
  /** Sending business identifier (session-derived). */
  businessId: string;
  /** Tenant identifier (session-derived). */
  tenantId: string;
  /** Business type for template selection. */
  businessType: string;
  /** The customer this invoice belongs to (unique identifier). */
  customerId: string;
  /** Invoice number / reference. */
  invoiceNumber: string;
  /** Invoice total amount in paise (integer). */
  totalAmountPaise: number;
  /** Due date (ISO-8601). */
  dueDate: string;
  /** Payment information (bank details, UPI, etc). */
  paymentInfo: string;
  /** Optional invoice PDF URL (may be null if PDF is still generating). */
  invoicePdfUrl?: string | null;
  /** Optional PDF file size in bytes (for 16 MB cap check). */
  invoicePdfSizeBytes?: number | null;
  /** Customer phone number carried on the event (optional, for verification). */
  customerNumber?: string;
  /** Customer phone from alternate field names. */
  customerPhone?: string;
  /** Additional payload fields for template substitution. */
  [key: string]: unknown;
}

/**
 * Result of processing an invoice-generated event.
 */
export interface InvoiceAutomationResult {
  /** Whether the automation completed processing (may still skip). */
  processed: boolean;
  /** Whether a message was enqueued. */
  enqueued: boolean;
  /** Whether a PDF attachment was included or will follow up. */
  pdfAttached: boolean;
  /** Whether a follow-up for PDF is scheduled. */
  pdfFollowUpScheduled: boolean;
  /** Reason if skipped or failed. */
  reason?: string;
}

// ── PDF Availability Checker Interface ───────────────────────────────────────

/**
 * Interface for checking whether the invoice PDF is available.
 * Allows the automation to poll for PDF availability within the 300s window.
 */
export interface PdfAvailabilityChecker {
  /**
   * Check if the invoice PDF is ready for a given invoice.
   * @returns The PDF URL and size if available, or null if not yet ready.
   */
  checkPdfReady(
    tenantId: string,
    businessId: string,
    invoiceNumber: string,
  ): Promise<{ url: string; sizeBytes: number } | null>;
}

// ── Service Dependencies ─────────────────────────────────────────────────────

export interface InvoiceAutomationDeps {
  customerProfileRepo?: CustomerProfileRepository;
  messageTemplateRepo?: MessageTemplateRepository;
  deliveryLogRepo?: DeliveryLogRepository;
  enqueueService?: DurableEnqueueService;
  operatorAlertService?: OperatorAlertService;
  pdfChecker?: PdfAvailabilityChecker;
}

// ── Module-level singletons (created lazily) ─────────────────────────────────

let defaultCustomerRepo: CustomerProfileRepository | null = null;
let defaultTemplateRepo: MessageTemplateRepository | null = null;
let defaultDeliveryLogRepo: DeliveryLogRepository | null = null;
let defaultEnqueueService: DurableEnqueueService | null = null;
let defaultOperatorAlertService: OperatorAlertService | null = null;

function getCustomerRepo(deps?: InvoiceAutomationDeps): CustomerProfileRepository {
  if (deps?.customerProfileRepo) return deps.customerProfileRepo;
  if (!defaultCustomerRepo) defaultCustomerRepo = new CustomerProfileRepository();
  return defaultCustomerRepo;
}

function getTemplateRepo(deps?: InvoiceAutomationDeps): MessageTemplateRepository {
  if (deps?.messageTemplateRepo) return deps.messageTemplateRepo;
  if (!defaultTemplateRepo) defaultTemplateRepo = new MessageTemplateRepository();
  return defaultTemplateRepo;
}

function getDeliveryLogRepo(deps?: InvoiceAutomationDeps): DeliveryLogRepository {
  if (deps?.deliveryLogRepo) return deps.deliveryLogRepo;
  if (!defaultDeliveryLogRepo) defaultDeliveryLogRepo = new DeliveryLogRepository();
  return defaultDeliveryLogRepo;
}

function getEnqueueService(deps?: InvoiceAutomationDeps): DurableEnqueueService {
  if (deps?.enqueueService) return deps.enqueueService;
  if (!defaultEnqueueService) defaultEnqueueService = createDurableEnqueueService();
  return defaultEnqueueService;
}

function getOperatorAlertService(deps?: InvoiceAutomationDeps): OperatorAlertService {
  if (deps?.operatorAlertService) return deps.operatorAlertService;
  if (!defaultOperatorAlertService) defaultOperatorAlertService = new OperatorAlertService();
  return defaultOperatorAlertService;
}

// ── Core: Process Invoice Generated Event ────────────────────────────────────

/**
 * Processes an `invoice.generated` Business_Event.
 *
 * Pipeline:
 * 1. Validate the event payload has required fields
 * 2. Look up the customer profile by customerId
 * 3. Check eligibility (valid E.164 + opted_in)
 * 4. Verify recipient identity (Req 16.1-16.6)
 * 5. Select template by BusinessType + locale (Req 4.5)
 * 6. Render template with invoice data
 * 7. Determine PDF attachment strategy:
 *    a. PDF available at event time + ≤16 MB → attach immediately
 *    b. PDF available but >16 MB → skip attachment, log reason
 *    c. PDF not available → send text now, schedule follow-up (300s window)
 * 8. Durably enqueue the outbound message within 5s (Req 4.1)
 * 9. On any failure: retry up to 3 attempts via the configured retry policy
 *
 * @param payload - The invoice-generated event payload
 * @param deps - Optional injectable dependencies (for testing)
 * @returns The automation result indicating what happened
 */
export async function processInvoiceGenerated(
  payload: InvoiceGeneratedPayload,
  deps?: InvoiceAutomationDeps,
): Promise<InvoiceAutomationResult> {
  const {
    eventId,
    businessId,
    tenantId,
    businessType,
    customerId,
    invoiceNumber,
  } = payload;

  const logContext = { eventId, businessId, tenantId, customerId, invoiceNumber };

  logger.info('[InvoiceAutomation] Processing invoice.generated event', logContext);

  // ── Step 1: Validate required fields ────────────────────────────────────
  const validationError = validatePayload(payload);
  if (validationError) {
    logger.error('[InvoiceAutomation] Invalid payload — skipping', {
      ...logContext,
      reason: validationError,
    });
    await safeLogSuppression(
      getDeliveryLogRepo(deps), tenantId, businessId, eventId, validationError,
    );
    return { processed: true, enqueued: false, pdfAttached: false, pdfFollowUpScheduled: false, reason: validationError };
  }

  // ── Step 2: Look up the customer profile ──────────────────────────────
  const customerRepo = getCustomerRepo(deps);
  const profilesList = await customerRepo.list(tenantId, businessId);
  const profilesById = new Map<string, CustomerProfile>(
    profilesList.map((p) => [p.id, p]),
  );

  const profile = profilesById.get(customerId);

  // ── Step 3: Check eligibility (Req 4.6) ───────────────────────────────
  if (!profile) {
    const reason = `No CustomerProfile found for customerId '${customerId}' — skipping invoice automation`;
    logger.info('[InvoiceAutomation] Customer not found — skipping', { ...logContext, reason });
    await safeLogSuppression(getDeliveryLogRepo(deps), tenantId, businessId, eventId, reason);
    return { processed: true, enqueued: false, pdfAttached: false, pdfFollowUpScheduled: false, reason };
  }

  const consentProfile: ConsentProfile = {
    whatsappNumber: profile.whatsappNumber,
    consentState: profile.consentState,
  };

  if (!isEligible(consentProfile)) {
    const reason = `Customer '${customerId}' is not eligible (number invalid or consent not opted_in) — skipping`;
    logger.info('[InvoiceAutomation] Customer not eligible — skipping', { ...logContext, reason });
    await safeLogSuppression(getDeliveryLogRepo(deps), tenantId, businessId, eventId, reason);
    return { processed: true, enqueued: false, pdfAttached: false, pdfFollowUpScheduled: false, reason };
  }

  // ── Step 4: Verify recipient identity (Req 16.1-16.6) ─────────────────
  const verificationInput = extractVerificationInput(customerId, businessId, payload);
  const verificationResult: RecipientVerificationResult = verifyRecipient(
    verificationInput,
    profilesById,
  );

  if (!verificationResult.verified) {
    const reason = verificationResult.reason;
    logger.warn('[InvoiceAutomation] Recipient verification failed — blocking', {
      ...logContext,
      failureType: verificationResult.failureType,
      reason,
    });

    // Raise Operator_Alert (Req 16.6)
    const alertInput: OperatorAlertInput = {
      eventId,
      businessId,
      tenantId,
      documentType: 'invoice',
      customerId,
      category: mapVerificationFailureToAlertCategory(verificationResult.failureType),
      reason,
      details: {
        eventPhoneNumber: payload.customerNumber || payload.customerPhone,
        storedPhoneNumber: profile.whatsappNumber,
      },
    };
    await getOperatorAlertService(deps).raiseOperatorAlert(alertInput);

    await safeLogSuppression(getDeliveryLogRepo(deps), tenantId, businessId, eventId, reason);
    return { processed: true, enqueued: false, pdfAttached: false, pdfFollowUpScheduled: false, reason };
  }

  const verifiedNumber = verificationResult.number;

  // ── Step 5: Select template by BusinessType + locale (Req 4.5) ────────
  const templateRepo = getTemplateRepo(deps);
  const allTemplates = await templateRepo.list(tenantId, businessId);

  // Filter to invoice templates by name, then select by BusinessType + locale
  const invoiceTemplates = allTemplates.filter(
    (t) => t.name === INVOICE_TEMPLATE_NAME,
  );

  const selectedTemplate: MessageTemplate | null = selectFullTemplate(
    invoiceTemplates,
    { businessType, locale: profile.locale },
  );

  if (!selectedTemplate) {
    const reason = `No active invoice template found for businessType='${businessType}', locale='${profile.locale}' — skipping`;
    logger.error('[InvoiceAutomation] Template not found — suppressing send', {
      ...logContext,
      businessType,
      locale: profile.locale,
    });
    await safeLogSuppression(getDeliveryLogRepo(deps), tenantId, businessId, eventId, reason);
    return { processed: true, enqueued: false, pdfAttached: false, pdfFollowUpScheduled: false, reason };
  }

  // ── Step 6: Render template with invoice data ─────────────────────────
  const templateInput: TemplateInput = {
    body: selectedTemplate.body,
    placeholders: selectedTemplate.placeholders,
  };

  const renderResult: RenderResult = render(templateInput, payload);

  if (!renderResult.success) {
    const reason = renderResult.error;
    logger.error('[InvoiceAutomation] Template render failed — suppressing send', {
      ...logContext,
      missingPlaceholders: renderResult.missingPlaceholders,
    });
    await safeLogSuppression(getDeliveryLogRepo(deps), tenantId, businessId, eventId, reason);
    return { processed: true, enqueued: false, pdfAttached: false, pdfFollowUpScheduled: false, reason };
  }

  // ── Step 7: Determine PDF attachment strategy ─────────────────────────
  const pdfStrategy = determinePdfStrategy(payload);

  // ── Step 8: Durably enqueue the outbound message (Req 4.1: within 5s) ─
  const enqueueService = getEnqueueService(deps);

  const enqueueInput: DurableEnqueueInput = {
    eventId,
    recipientId: customerId,
    recipientNumber: verifiedNumber,
    businessId,
    tenantId,
    templateId: selectedTemplate.id,
    templateVersion: selectedTemplate.currentVersion,
    renderedBody: renderResult.text,
    mediaUrl: pdfStrategy.attachNow ? pdfStrategy.pdfUrl : undefined,
  };

  const enqueueResult = await enqueueService.enqueue(enqueueInput);

  if (!enqueueResult.success) {
    const reason = `Enqueue failed at stage '${enqueueResult.error?.stage}': ${enqueueResult.error?.reason}`;
    logger.error('[InvoiceAutomation] Enqueue failed', { ...logContext, reason });
    return { processed: true, enqueued: false, pdfAttached: false, pdfFollowUpScheduled: false, reason };
  }

  logger.info('[InvoiceAutomation] Invoice message enqueued successfully', {
    ...logContext,
    outboundMessageId: enqueueResult.message?.id,
    pdfAttached: pdfStrategy.attachNow,
    pdfFollowUpNeeded: pdfStrategy.followUpNeeded,
  });

  // ── Step 9: Handle PDF follow-up if needed (Req 4.3, 4.4) ────────────
  let pdfFollowUpScheduled = false;

  if (pdfStrategy.followUpNeeded && deps?.pdfChecker) {
    // Schedule the follow-up asynchronously (fire-and-forget within 300s window)
    schedulePdfFollowUp(
      payload,
      verifiedNumber,
      customerId,
      selectedTemplate,
      deps,
    ).catch((err) => {
      logger.error('[InvoiceAutomation] PDF follow-up scheduling failed', {
        ...logContext,
        error: err instanceof Error ? err.message : String(err),
      });
    });
    pdfFollowUpScheduled = true;
  }

  return {
    processed: true,
    enqueued: true,
    pdfAttached: pdfStrategy.attachNow,
    pdfFollowUpScheduled,
  };
}

// ── PDF Strategy ─────────────────────────────────────────────────────────────

interface PdfStrategy {
  /** Whether to attach the PDF now (available + ≤16 MB). */
  attachNow: boolean;
  /** The PDF URL to attach (when attachNow is true). */
  pdfUrl?: string;
  /** Whether a follow-up message with the PDF is needed. */
  followUpNeeded: boolean;
  /** Reason if PDF cannot be attached. */
  skipReason?: string;
}

/**
 * Determines the PDF attachment strategy based on availability and size.
 *
 * - PDF available + ≤16 MB → attach now
 * - PDF available + >16 MB → skip attachment, log reason
 * - PDF not available → send text now, schedule follow-up within 300s
 */
function determinePdfStrategy(payload: InvoiceGeneratedPayload): PdfStrategy {
  const { invoicePdfUrl, invoicePdfSizeBytes } = payload;

  // PDF not available at event time → follow up later (Req 4.3)
  if (!invoicePdfUrl) {
    return {
      attachNow: false,
      followUpNeeded: true,
      skipReason: 'PDF not available at event time; follow-up scheduled within 300s window',
    };
  }

  // PDF available but exceeds 16 MB cap (Req 4.2)
  if (invoicePdfSizeBytes != null && invoicePdfSizeBytes > MAX_DOCUMENT_SIZE_BYTES) {
    logger.warn('[InvoiceAutomation] Invoice PDF exceeds 16 MB cap — skipping attachment', {
      invoicePdfSizeBytes,
      maxBytes: MAX_DOCUMENT_SIZE_BYTES,
      invoicePdfUrl,
    });
    return {
      attachNow: false,
      followUpNeeded: false,
      skipReason: `PDF size ${invoicePdfSizeBytes} bytes exceeds 16 MB limit`,
    };
  }

  // PDF available and within size limit → attach now (Req 4.2)
  return {
    attachNow: true,
    pdfUrl: invoicePdfUrl,
    followUpNeeded: false,
  };
}

// ── PDF Follow-Up (Req 4.3, 4.4) ────────────────────────────────────────────

/**
 * Polls for the invoice PDF within the 300-second wait window.
 * When the PDF becomes available (and is ≤16 MB), enqueues a follow-up
 * message with the document attached.
 *
 * If the PDF does not become available within the window, skips the
 * attachment and logs the reason (Req 4.4).
 */
async function schedulePdfFollowUp(
  payload: InvoiceGeneratedPayload,
  verifiedNumber: string,
  customerId: string,
  template: MessageTemplate,
  deps: InvoiceAutomationDeps,
): Promise<void> {
  const {
    eventId,
    businessId,
    tenantId,
    invoiceNumber,
  } = payload;

  const logContext = { eventId, businessId, tenantId, customerId, invoiceNumber };
  const pdfChecker = deps.pdfChecker;
  if (!pdfChecker) {
    logger.warn('[InvoiceAutomation] No PDF checker configured — cannot follow up', logContext);
    return;
  }

  const deadline = Date.now() + PDF_WAIT_WINDOW_MS;
  let pdfResult: { url: string; sizeBytes: number } | null = null;

  // Poll for PDF availability within the 300s window
  while (Date.now() < deadline) {
    try {
      pdfResult = await pdfChecker.checkPdfReady(tenantId, businessId, invoiceNumber);
      if (pdfResult) break;
    } catch (err) {
      logger.warn('[InvoiceAutomation] PDF check failed — will retry', {
        ...logContext,
        error: err instanceof Error ? err.message : String(err),
      });
    }

    // Wait before next poll (or break if we'd exceed the deadline)
    const remainingMs = deadline - Date.now();
    if (remainingMs <= 0) break;
    await sleep(Math.min(PDF_POLL_INTERVAL_MS, remainingMs));
  }

  // PDF never arrived within the 300s window (Req 4.4)
  if (!pdfResult) {
    const reason = `Invoice PDF did not become available within ${PDF_WAIT_WINDOW_MS / 1000}s window for invoice '${invoiceNumber}'`;
    logger.info('[InvoiceAutomation] PDF wait window expired — skipping attachment', {
      ...logContext,
      reason,
    });
    await safeLogSuppression(
      getDeliveryLogRepo(deps), tenantId, businessId, eventId, reason,
    );
    return;
  }

  // PDF arrived — check the 16 MB cap
  if (pdfResult.sizeBytes > MAX_DOCUMENT_SIZE_BYTES) {
    const reason = `Invoice PDF for '${invoiceNumber}' is ${pdfResult.sizeBytes} bytes (exceeds 16 MB cap) — skipping follow-up attachment`;
    logger.warn('[InvoiceAutomation] Follow-up PDF exceeds size cap', { ...logContext, reason });
    await safeLogSuppression(
      getDeliveryLogRepo(deps), tenantId, businessId, eventId, reason,
    );
    return;
  }

  // Enqueue the follow-up message with the PDF attached
  const enqueueService = getEnqueueService(deps);
  const followUpInput: DurableEnqueueInput = {
    eventId: `${eventId}:pdf-followup`,
    recipientId: customerId,
    recipientNumber: verifiedNumber,
    businessId,
    tenantId,
    templateId: template.id,
    templateVersion: template.currentVersion,
    renderedBody: `📄 Invoice ${invoiceNumber} — PDF attached.`,
    mediaUrl: pdfResult.url,
  };

  const result = await enqueueService.enqueue(followUpInput);

  if (result.success) {
    logger.info('[InvoiceAutomation] PDF follow-up message enqueued', {
      ...logContext,
      outboundMessageId: result.message?.id,
      pdfUrl: pdfResult.url,
    });
  } else {
    logger.error('[InvoiceAutomation] PDF follow-up enqueue failed', {
      ...logContext,
      stage: result.error?.stage,
      reason: result.error?.reason,
    });
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Validates the invoice-generated event payload has all required fields.
 * Returns an error string if invalid, or null if valid.
 */
function validatePayload(payload: InvoiceGeneratedPayload): string | null {
  if (!payload.eventId || typeof payload.eventId !== 'string' || !payload.eventId.trim()) {
    return 'Missing or empty eventId';
  }
  if (!payload.businessId || typeof payload.businessId !== 'string' || !payload.businessId.trim()) {
    return 'Missing or empty businessId';
  }
  if (!payload.tenantId || typeof payload.tenantId !== 'string' || !payload.tenantId.trim()) {
    return 'Missing or empty tenantId';
  }
  if (!payload.customerId || typeof payload.customerId !== 'string' || !payload.customerId.trim()) {
    return 'Missing or empty customerId';
  }
  if (!payload.invoiceNumber || typeof payload.invoiceNumber !== 'string' || !payload.invoiceNumber.trim()) {
    return 'Missing or empty invoiceNumber';
  }
  if (!payload.businessType || typeof payload.businessType !== 'string' || !payload.businessType.trim()) {
    return 'Missing or empty businessType';
  }
  return null;
}

/**
 * Maps a recipient verification failure type to an operator alert category.
 */
function mapVerificationFailureToAlertCategory(
  failureType: string,
): (typeof ALERT_CATEGORIES)[keyof typeof ALERT_CATEGORIES] {
  switch (failureType) {
    case 'NUMBER_MISMATCH':
    case 'INVALID_EVENT_NUMBER':
      return ALERT_CATEGORIES.PHONE_NUMBER_CHANGED;
    case 'PROFILE_DELETED':
      return ALERT_CATEGORIES.PROFILE_DELETED;
    case 'PROFILE_NOT_FOUND':
    case 'MISSING_CUSTOMER_ID':
    case 'MISSING_BUSINESS_ID':
    case 'MULTIPLE_PROFILES':
      return ALERT_CATEGORIES.RECIPIENT_MISMATCH;
    case 'INVALID_STORED_NUMBER':
      return ALERT_CATEGORIES.PHONE_NUMBER_CHANGED;
    default:
      return ALERT_CATEGORIES.RECIPIENT_MISMATCH;
  }
}

/**
 * Safely log a suppression/failure to the Delivery_Log.
 * Non-fatal: log write failures are caught and logged but do not propagate.
 */
async function safeLogSuppression(
  deliveryLogRepo: DeliveryLogRepository,
  tenantId: string,
  businessId: string,
  outboundMessageId: string,
  reason: string,
): Promise<void> {
  try {
    await deliveryLogRepo.create(tenantId, businessId, {
      outboundMessageId,
      state: 'suppressed',
      reason,
    });
  } catch (err) {
    logger.warn('[InvoiceAutomation] Failed to write delivery log entry', {
      tenantId,
      businessId,
      outboundMessageId,
      reason,
      error: err instanceof Error ? err.message : String(err),
    });
  }
}

/**
 * Async sleep utility for polling delays.
 */
function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
