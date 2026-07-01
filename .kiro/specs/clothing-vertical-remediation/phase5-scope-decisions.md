# Phase 5 — Scope Decisions (Requirement 11.8)

This document records explicit in-scope or deferred-backlog decisions for features evaluated
during Phase 5 (GST value-slab rule, variant model unification, exchange). Each decision
includes a written rationale.

---

## 1. Season/Collection Tracking

**Decision:** Deferred to backlog.

**Rationale:** The current variant model supports color/size/SKU but has no season or
collection metadata. Adding season/collection tracking requires a schema change — either new
fields on `VariantItem` or a separate entity — that goes beyond the surgical remediation
scope defined by Requirement 2. No existing screen, sidebar item, or business rule in the
clothing vertical references seasons or collections, so no user-facing functionality depends
on this today.

---

## 2. Brand-wise Stock Reporting

**Decision:** Deferred to backlog.

**Rationale:** Products in DukanX already carry a category but not a brand field.
Implementing brand-wise stock reporting requires adding a brand field to the product model
(a cross-vertical schema change that falls outside the clothing-remediation scope boundary
defined in Requirement 2.1) and building a new reporting screen. Neither the product model
nor any existing clothing screen surfaces brand information, making this a net-new feature
rather than a remediation of existing broken functionality.

---

## 3. Loyalty/Bundle Support

**Decision:** Deferred to backlog.

**Rationale:** Loyalty programs and product bundling are business features that span billing,
customer management, and inventory — they are not clothing-specific and would require
cross-cutting infrastructure changes (loyalty point accrual, redemption rules, bundle pricing
logic, customer tier tracking) beyond this remediation. Adding them would violate the scope
boundary of Requirement 2.1 which restricts changes to `features/clothing/*`,
`modules/clothing/*`, the clothing case within Shared_Components, and navigation entries
needed for reachability.
