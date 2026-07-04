// ============================================================================
// Staff Module — Services (barrel)
// ============================================================================
// Services are added in later tasks:
//   pii-crypto.service.ts        → envelope encryption + masking
//   pii-access.service.ts        → role-gated PII encryption/masking/unmasking
//   payroll.service.ts           → pure computePayslip (DynamoDB txn, online-only)
//   statutory.service.ts         → effective-dated PF/ESI/PT/TDS rates
//   formula-evaluator.service.ts → sandboxed AST evaluator (jsep; no eval)
//   commission.service.ts        → category/brand/product/target/profit/custom
//   performance.service.ts       → deterministic, inspectable weighted score
//   attendance.service.ts        → geo/GPS/WiFi validation; append-only events
//   staff-feature-config.service.ts → BusinessType × SubscriptionTier resolver
//   staff-audit.service.ts       → append-only audit entries
//   staff-notify.service.ts      → Push/Email/In-App/WebSocket; WhatsApp via OpenWA
// ============================================================================

// Task 2.4 — Staff_Feature_Config resolver (BusinessType × SubscriptionTier).
export * from './staff-feature-config.service';

// Task 3.1 — PII crypto + masking (KMS envelope encryption) and the
// full-Aadhaar-capture feature flag (kept OFF).
export * from './pii-crypto.service';

// Task 3.2 — PII access service (role-gated encryption/masking/unmasking).
export * from './pii-access.service';

// Task 5.1 — Append-only attendance capture (manual|qr|barcode|gps|wifi);
// Face/Biometric as a flagged-off interface only.
export * from './attendance.service';

// Task 10.1 — Sandboxed AST formula evaluator (jsep; no eval/new Function).
export * from './formula-evaluator.service';

// Task 10.2 — Performance scoring (deterministic inspectable weighted sum)
// and commission engine (category/brand/product/target/profit/custom rules).
export * from './performance.service';
export * from './commission.service';

// Task 7.1 — Task workflow pure functions (recurrence, dependency gating,
// escalation). Used by task handlers and property tests.
export * from './task-workflow.service';

// Task 7.2 — Task analytics aggregation (pure function; Property 19, Req 5.6).
export * from './task-analytics.service';

// Task 6.1 — Leave validation & accrual logic (pure, deterministic; Property 12).
export * from './leave.service';

// Task 5.3 — Roster builder service: pure shift-rule enforcement (Property 11).
export * from './roster-builder.service';

// Task 6.2 — Staff audit service (append-only audit entries; basic version).
export * from './staff-audit.service';

// Task 3.3 — Append-only audit entries (PII unmask reads, mutations).
export * from './staff-audit.service';

// Task 9.1 — Statutory rate service: effective-dated PF/ESI/PT/TDS rates from
// DynamoDB. PT is state-specific; no hardcoded rates. Throws
// STATUTORY_RATE_UNAVAILABLE when a required rate is missing (Req 6.2–6.4).
export * from './statutory.service';

// Task 9.2 + 9.3 — Payroll engine: pure computePayslip, single-writer lock
// (conditional PutItem), and atomic TransactWriteCommand payroll processing.
export * from './payroll.service';

// Task 11.1 — Staff-specific RBAC extension (AD-3: extend, do not replace).
// Adds field/button/action/report/dashboard/export/delete/approval permission
// descriptors; enforces every check backend-only, fail-closed (Req 8.1, 8.2).
export * from './staff-rbac.service';

// Task 14.1 — Deferred capabilities (SMS, ML/predictive, gamification) as
// flagged-off interfaces. Face/Biometric and full-Aadhaar are already gated in
// attendance.service.ts and pii-crypto.service.ts respectively.
export * from './deferred-capabilities.service';

// Task 9.4 — Salary component service: audit-before-write wrapper for
// SalaryComponent mutations (Req 6.8, Property 22).
export * from './salary-component.service';

// Task 13.2 — Report export service: Excel (exceljs), PDF (pdfkit), CSV
// generation from generic ReportData (Req 9.6).
export * from './report-export.service';

// Task 13.2 — Global staff search + saved filters CRUD (Req 9.7).
export * from './staff-search.service';

// Task 11.3 — Multi-channel notification service: Push/Email/In-App/WebSocket
// via src/notifications; WhatsApp via OpenWA (no second gateway; Req 8.5);
// SMS adapter interface flagged OFF (Req 8.6).
export * from './staff-notify.service';
