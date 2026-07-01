# Phase 4 Decision: Permission Gating & Module Disposition

**Date:** 2025-07-24  
**Phase:** 4 — Sidebar, Navigation, and RBAC Wiring  
**Requirements covered:** 7.7, 7.9

---

## (a) Permission Decision: `manageStaff` → `viewInvoices`

**Decision:** `manageStaff` is **replaced** by `viewInvoices` as the gating permission for
repair/exchange operations rendered through the Content_Host in-shell path.

**Rationale:** The `/service_jobs` and `/exchanges` named routes already use
`Permissions.viewInvoices` (visible to owner, accountant, and manager roles); `manageStaff`
is more restrictive (owner-only) and too narrow for everyday repair-desk and exchange-counter
workflows — aligning the Content_Host guard with `viewInvoices` matches the route-level guards
and eliminates the permission inconsistency between the two navigation paths.

---

## (b) Module Disposition: Mobile_Shop_Module / Mobile_Shop_Routes

**Decision:** N/A — no action required.

**Rationale:** The `Mobile_Shop_Module`, `Mobile_Shop_Routes`, `MobileShopSyncHandler`, and
`MobileShopWsHandler` do not exist in the live codebase (Phase 0, Discrepancy A — the audit
premise that these are "orphaned but present" was falsified; no `lib/modules/` directory and
no such classes were found). There is nothing to delete or retain.
