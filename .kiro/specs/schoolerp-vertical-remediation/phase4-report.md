# Phase 4 — Minors' PII and Compliance (Policy Stop)

**Spec:** `schoolerp-vertical-remediation`
**Phase:** 4 — Minors' PII and Compliance
**Requirements covered:** 7.1, 7.2, 7.3, 7.4, 7.5, 7.8, 7.9
**Status:** ⛔ **HARD STOP — AWAITING POLICY SIGN-OFF**

---

## Executive Summary

Per Requirement 7.1 and 7.9, Phase 4 is a **hard policy stop**. While ANY of the four
policy decisions below remains unconfirmed, **no minors' PII handling code will be
implemented**. This document surfaces each unconfirmed decision by name for sign-off,
records the encryption-at-rest verification status for the relevant DynamoDB table(s),
and explicitly declares the halt.

---

## ⛔ HALT DECLARATION

**Phase 4 is HALTED.** All four policy decisions listed below are currently
**UNCONFIRMED**. No minors' PII handling code (audit logging, access control for PII
fields, consent workflows, retention enforcement, or data export restrictions) will be
written until every policy is confirmed per Requirement 7.2.

A policy decision is considered **confirmed** only when a sign-off record captures:
1. The **decision name** (which policy)
2. The **agreed value** (the specific policy choice)
3. The **confirming compliance owner** (person/role who approved)
4. The **confirmation timestamp** (date/time of sign-off)

---

## Policy Decisions Requiring Sign-Off

### 1. Data Retention Period (Requirement 7.3)

| Field | Value |
|-------|-------|
| **Decision** | Data retention period for minors' personally identifiable information |
| **Description** | How long should the School_System retain minors' PII (student names, dates of birth, addresses, parent/guardian contacts, photos, academic records linked to identifiable minors)? This includes both active and archived/graduated student records. Applicable regulations (e.g., India's DPDPA 2023, local education board mandates) may prescribe minimum and maximum retention windows. |
| **Status** | ⚠️ **UNCONFIRMED** |
| **What is needed** | A compliance owner must specify: (a) the retention duration (e.g., "duration of enrollment + 5 years post-graduation"), (b) whether different PII categories have different retention windows, (c) the deletion/anonymization mechanism after expiry. Record: owner name/role, agreed value, timestamp. |

---

### 2. Parent/Guardian Consent Mechanism (Requirement 7.4)

| Field | Value |
|-------|-------|
| **Decision** | Parent or guardian consent mechanism for collecting and processing minors' PII |
| **Description** | How is verifiable consent obtained from a parent or guardian before the School_System collects, stores, or processes a minor's personally identifiable information? This covers initial enrollment, ongoing data processing, photo capture, sharing with third parties (e.g., transport providers), and re-consent upon material changes to data usage. |
| **Status** | ⚠️ **UNCONFIRMED** |
| **What is needed** | A compliance owner must specify: (a) the consent collection method (e.g., signed physical form uploaded, in-app digital consent with OTP verification, parent portal acknowledgment), (b) what constitutes valid consent (age threshold for "minor", guardian verification), (c) how consent withdrawal is handled, (d) whether re-consent is required annually or on policy change. Record: owner name/role, agreed value, timestamp. |

---

### 3. Authorized-Role List for PII Access (Requirement 7.5)

| Field | Value |
|-------|-------|
| **Decision** | Which roles are authorized to view or export minors' personally identifiable information |
| **Description** | Define the exhaustive list of user roles (mapped from the existing `UserRole` enum values — `owner`, `manager`, `staff`, `accountant`) that are permitted to view and/or export minors' PII. This also determines which roles trigger a denied-access audit entry when they attempt to view/export PII (Requirement 7.7). |
| **Status** | ⚠️ **UNCONFIRMED** |
| **What is needed** | A compliance owner must specify: (a) the list of roles permitted to **view** minors' PII, (b) the list of roles permitted to **export** minors' PII (may be a subset of view), (c) whether any additional conditions apply (e.g., only the assigned class teacher, only during active session). Record: owner name/role, agreed value, timestamp. |

---

### 4. Audit-Logging Policy for PII Access (Requirements 7.6, 7.7)

| Field | Value |
|-------|-------|
| **Decision** | Audit-logging approach for access to minors' personally identifiable information |
| **Description** | Define the audit logging policy governing how PII access events are recorded. This covers both allowed access (view/export by authorized roles) and denied access attempts (by unauthorized roles). The audit log must capture: acting user, record accessed, action type (`view`/`export`), outcome (`allowed`/`denied`), and timestamp, all scoped by `Tenant_Id`. |
| **Status** | ⚠️ **UNCONFIRMED** |
| **What is needed** | A compliance owner must specify: (a) where audit logs are stored (same DynamoDB table, separate audit table, external log service), (b) retention period for audit logs themselves, (c) who can access/query the audit logs, (d) whether real-time alerting is required on denied attempts, (e) whether bulk export triggers a single aggregate entry or per-record entries. Record: owner name/role, agreed value, timestamp. |

---

## Encryption-at-Rest Verification (Requirement 7.8)

Per Requirement 7.8, the boolean encryption-at-rest status must be verified for each
DynamoDB table storing minors' personally identifiable information.

| DynamoDB Table | Stores Minors' PII? | Encryption-at-Rest Status | Notes |
|----------------|---------------------|--------------------------|-------|
| `ac-students` (or tenant-prefixed equivalent serving `/ac/students`) | **Yes** — student names, DOB, addresses, parent/guardian contacts, photos | 🔍 **VERIFICATION NEEDED** | Cannot be verified from client code alone. **Action required:** Check AWS Console → DynamoDB → Table `ac-students` → Additional settings → Encryption → verify "Encryption type" is set to AWS owned key (default), AWS managed key, or customer managed key. Record the boolean result here. |
| `ac-invoices` / `ac-payments` (or equivalent serving `/ac/invoices`, `/ac/payments`) | **Possibly** — invoices reference student IDs which can link to PII | 🔍 **VERIFICATION NEEDED** | Check whether these tables store student names inline or only reference IDs. If names are stored, encryption-at-rest must be confirmed. |
| `ac-attendance` (or equivalent serving `/ac/attendance`) | **Possibly** — attendance records reference student IDs | 🔍 **VERIFICATION NEEDED** | Likely contains only student ID references (not PII directly), but verify table schema. |

### How to verify

```bash
# AWS CLI command to check encryption-at-rest for a DynamoDB table:
aws dynamodb describe-table --table-name <TABLE_NAME> --query "Table.SSEDescription"

# Expected output for encryption enabled:
# { "Status": "ENABLED", "SSEType": "KMS", "KMSMasterKeyArn": "arn:aws:kms:..." }
# or for default encryption:
# null (DynamoDB default encryption-at-rest is always enabled since 2018)
```

> **Note:** As of November 2018, all DynamoDB tables are encrypted at rest by default
> using AWS owned keys. However, compliance requirements may mandate customer-managed
> KMS keys (CMK) for minors' PII. The compliance owner should confirm whether default
> encryption is sufficient or CMK is required.

---

## Files Created / Modified / Deleted

| Action | File | Reason |
|--------|------|--------|
| **Created** | `.kiro/specs/schoolerp-vertical-remediation/phase4-report.md` | Phase 4 policy report (this file) |
| Modified | — | None |
| Deleted | — | None |

**Application source / configuration / build files modified: 0**
**`flutter analyze` required: No** (no application code changed)

---

## Next Steps (blocked until sign-off)

1. **Obtain sign-off** on all four policy decisions above from the designated compliance owner.
2. For each decision, record the agreed value, owner identity, and confirmation timestamp in this document.
3. **Verify encryption-at-rest** for the `ac-students` DynamoDB table (and any other table confirmed to store minors' PII inline) and record the boolean result above.
4. Once ALL four policies are confirmed AND encryption status is recorded, Phase 4 implementation (task 9.2 — per-record PII access audit log) may proceed.

Until then: **NO minors' PII handling code will be written.**

---

## Sign-Off Record (to be completed by compliance owner)

| # | Decision | Agreed Value | Confirming Owner | Timestamp |
|---|----------|-------------|-----------------|-----------|
| 1 | Data retention period | _PENDING_ | _PENDING_ | _PENDING_ |
| 2 | Parent/guardian consent mechanism | _PENDING_ | _PENDING_ | _PENDING_ |
| 3 | Authorized-role list | _PENDING_ | _PENDING_ | _PENDING_ |
| 4 | Audit-logging policy | _PENDING_ | _PENDING_ | _PENDING_ |

---

**Phase 4 status: ⛔ HALTED — awaiting policy sign-off on all four decisions above.**


---

## Task 9.2 — Per-Record PII Access Audit Log: DEFERRED

**Task:** 9.2 Implement the per-record PII access audit log (only after policies are confirmed)
**Requirements:** 7.6, 7.7
**Status:** 🚫 **DEFERRED — pending policy sign-off**
**Date recorded:** 2025-07-25

### Reason for Deferral

Per Requirement 7.1: _"While any of the data retention period, consent mechanism,
authorized-role list, or audit-logging policy is unconfirmed, the School_System SHALL
treat Phase 4 as a hard stop and SHALL NOT implement minors' PII handling code."_

As of this writing, **all four policy decisions remain UNCONFIRMED**:

| # | Policy Decision | Status |
|---|-----------------|--------|
| 1 | Data retention period | ⚠️ UNCONFIRMED |
| 2 | Parent/guardian consent mechanism | ⚠️ UNCONFIRMED |
| 3 | Authorized-role list for PII access | ⚠️ UNCONFIRMED |
| 4 | Audit-logging policy | ⚠️ UNCONFIRMED |

Therefore, the per-record PII access audit log (task 9.2) **cannot be implemented** and
is deferred until all four policies are confirmed with:
- The decision name
- The agreed value
- The confirming compliance owner (name/role)
- The confirmation timestamp

### What Task 9.2 Will Implement (when unblocked)

Once all policies are confirmed, implementation will:
1. Write exactly one audit entry per PII view/export capturing: acting user, record
   accessed, action type (`view`/`export`), outcome (`allowed`/`denied`), and timestamp,
   scoped by `Tenant_Id`.
2. Deny the operation and return/export no data when the user's role is not in the
   confirmed authorized-role list, writing an audit entry with outcome `denied`.
3. Use the RID pattern (`{tenantId}-{timestamp_ms}-{uuid_v4_short}`) for the audit
   entry identifier.

### Application Code Changes

**None.** No application source, configuration, or build files were modified for this
task. The hard-stop is the correct behavior per the spec.

### `flutter analyze` Required

**No.** No application code was changed.

### Unblock Criteria

Task 9.2 implementation will proceed **only when ALL of the following are true**:
- [ ] Policy 1 (data retention period) — confirmed with owner + timestamp
- [ ] Policy 2 (consent mechanism) — confirmed with owner + timestamp
- [ ] Policy 3 (authorized-role list) — confirmed with owner + timestamp
- [ ] Policy 4 (audit-logging policy) — confirmed with owner + timestamp

Until then, this task remains deferred and the Phase 4 hard stop remains in effect.
