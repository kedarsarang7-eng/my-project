# Archived Billing Screens

These files were moved here (NOT deleted) as part of **Phase 4 — Billing Screen
Consolidation**. Each was confirmed to have **zero active references** (no route,
no import, no dynamic navigation) before archiving.

## Criteria for archival
- 0 imports across `lib/`
- 0 route references in `lib/app/routes.dart`
- No string-based / `RouteSettings` / dynamic references

If a file needs to be restored, `git mv` it back to its original path under
`lib/features/billing/presentation/screens/`.

---

## return_bill_screen.dart
- **Original path:** `lib/features/billing/presentation/screens/return_bill_screen.dart`
- **Archived:** 2026-06-18
- **Reason:** Orphan widget. `grep -rn "ReturnBillScreen\|return_bill_screen"`
  across `lib/` returned only the file itself — no route, no import. The
  *return/exchange* feature itself still works via
  `lib/features/billing/domain/services/return_exchange_service.dart` (which
  creates return bills programmatically); this screen was simply never wired
  into the navigation graph.
- **Confidence:** High — verified by static grep. No runtime/dynamic-nav
  reference found.
