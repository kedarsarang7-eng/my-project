# Bookstore Vertical — Backlog Features (Hard Stops)

> **Status:** DEFERRED — requires explicit business confirmation before any code is written.
>
> **Governance:** Requirement 12.7, Requirement 14.6 — these are business decisions, not
> engineering tasks. No implementation may proceed without the literal reply `APPROVED` for
> each individual item below.

---

## F21 — Used Books

**What exists today:** `BookStoreBusinessRules.suggestedResalePrice` and the `BookCondition`
enum in `lib/features/book_store/utils/book_store_business_rules.dart` provide pricing
helpers (brand-new 5% off → damaged 75% off). A test suite covers the helper logic.

**What does NOT exist:** No Used Books UI, no resale workflow screen, no used-book inventory
category, no condition-entry widget, and no POS integration for second-hand sales.

**Decision required:** Build a Used Books feature (condition entry, resale pricing, dedicated
inventory category, POS integration) — or defer indefinitely.

> ⛔ **NOT IMPLEMENTED — requires explicit business confirmation before any code is written.**

---

## F22 — Set/Bundle Class-Set Composition

**What exists today:** `UnitType.set` is defined in the billing/business-type config layer,
indicating the concept of a "set" unit is acknowledged.

**What does NOT exist:** No BOM (Bill of Materials) / bundle composition code, no
class-set builder UI, no set-pricing logic, and no inventory deduction for individual items
within a set on sale.

**Decision required:** Build a class-set/bundle composition feature (BOM definition,
set pricing, per-item stock deduction, set-level POS entry) — or defer indefinitely.

> ⛔ **NOT IMPLEMENTED — requires explicit business confirmation before any code is written.**

---

## F23 — Stationery Category with Mixed GST

**What exists today:** The category dropdown in the Add Book dialog is hardcoded to book-
related categories. `BookGstResolver` handles mixed HSN rates for per-item tax (Phase 3
confirmed policy: books 0%, notebooks 5%, stationery 5–18%).

**What does NOT exist:** No dedicated stationery category management UI, no category
CRUD screen, no HSN-rate assignment workflow, and no multi-category product browsing view.

**Decision required:** Build a stationery category management UI (category CRUD, HSN-rate
assignment, mixed-category browsing) — or defer indefinitely.

> ⛔ **NOT IMPLEMENTED — requires explicit business confirmation before any code is written.**

---

## F31 — Book Detail/Edit + Publisher/School Master UI

**What exists today:** The Add Book dialog in `BookInventoryScreen` allows creating a new
book entry. No edit or delete capability exists for existing books.

**What does NOT exist:** No book detail view, no edit dialog, no delete flow, no publisher
master (CRUD for publishers), and no school/institution master (CRUD for schools).

**Decision required:** Build full book detail/edit/delete, a publisher master screen, and
a school/institution master screen — or defer indefinitely.

> ⛔ **NOT IMPLEMENTED — requires explicit business confirmation before any code is written.**

---

## Summary Table

| Finding | Feature                              | Helpers Exist | UI Built | Status              |
|---------|--------------------------------------|:------------:|:--------:|---------------------|
| F21     | Used Books                           | ✓            | ✗        | DEFERRED — backlog  |
| F22     | Set/Bundle class-set composition     | partial      | ✗        | DEFERRED — backlog  |
| F23     | Stationery category with mixed GST   | partial      | ✗        | DEFERRED — backlog  |
| F31     | Book detail/edit + publisher/school   | partial      | ✗        | DEFERRED — backlog  |

---

## Verification

- **No code was written** for any of these four features in Phases 0–8 of this remediation.
- **Repository search confirms** zero UI widgets, zero screens, and zero dedicated routes
  exist for F21, F22, F23, or F31 beyond the noted utility helpers.
- Per Requirement 14.6: if the build-versus-defer decision is unconfirmed, the system halts
  and requests confirmation rather than guessing.

---

*Last updated: Phase 9 (Task 19.7)*
