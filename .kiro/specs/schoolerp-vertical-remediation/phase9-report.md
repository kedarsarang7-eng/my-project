# Phase 9 — Dead Code & Duplicate Cleanup: Reference Search Report

> **Tasks 19.1 & 19.2** — Requirements 12.1, 12.2, 12.3, 12.4, 12.5, 12.6

---

## Summary

All three Phase 9 deletion candidates were subjected to repository-wide reference searches.
**Result: zero candidates qualify for deletion.** Each candidate is either actively referenced,
outside Flutter app scope, or does not exist in the codebase.

---

## Candidate 1: `/ac/students` Collision Residue

**What was searched:** Any residual code from the original `/ac/students` path collision
between `AcStudentsScreen` and `AcStudentRegistrationScreen`.

**Search scope:** Entire `Dukan_x/` tree (all `*.dart` files excluding `.freezed.dart` and
`.g.dart`).

**Exact symbol/path searched:** `AcStudentRegistrationScreen`, `/ac/students/register`

**Result:** The collision was resolved in Phase 1 (Task 3.3) by giving
`AcStudentRegistrationScreen` a distinct path `/ac/students/register`. Both paths are live
and actively referenced. There is **no residual collision code** to delete — the resolution
was additive (a new route was added, nothing was left orphaned).

**Live references found (outside definition file):**

| # | File | Line | Context |
|---|------|------|---------|
| 1 | `lib/core/routing/legacy_routes.dart` | 2076 | GoRoute `path: '/ac/students/register'` — active route binding |
| 2 | `lib/core/routing/legacy_routes.dart` | 2083 | `child: const AcStudentRegistrationScreen()` — route builder |
| 3 | `lib/features/dashboard/v2/widgets/business_quick_actions.dart` | 524 | `context.push('/ac/students/register')` — "New Admission" quick action |

**Decision:** RETAIN — multiple live references exist. No deletion candidate here.
Requirement 12.4 applies: candidate retained unchanged; live references recorded above.

---

## Candidate 2: `SchoolErpModule.navItems` Redundancy

**What was searched:** The backend module manifest flagged in Phase 1 (Task 3.3, Requirement
4.9) as providing navigation items (`featureKeys`) that duplicate what
`sidebarSectionsProvider` already provides in the Flutter app.

**Search scope:** Entire workspace (`Dukan_x/`, `my-backend/`, all source files).

**Exact path/symbol searched:** `my-backend/src/modules/school-erp/manifest.ts`
(`schoolErpManifest` — specifically its `featureKeys` array).

**Result:** The manifest file is a **backend** artifact at
`my-backend/src/modules/school-erp/manifest.ts`. Per Requirement 2.1, code changes in this
remediation are restricted to:
- `lib/features/academic_coaching/*`
- The `schoolErp` case within Shared_Components
- The schoolErp offline sync handler
- Navigation entries needed for reachability

The backend manifest is **outside the Flutter app scope**. Additionally, it has a live
reference:

| # | File | Line | Context |
|---|------|------|---------|
| 1 | `my-backend/src/core/registry/module-registry.ts` | 22 | `import { schoolErpManifest } from '../../modules/school-erp/manifest';` — active import |

The Dart-side codebase has **no** `SchoolErpModule` class or `navItems` object. The only
Dart reference is a comment in `legacy_routes.dart` (lines 2025–2029) flagging the
redundancy for tracking purposes.

**Decision:** RETAIN — the candidate is (a) outside the Flutter app scope boundary
(Requirement 2.1), and (b) actively imported by the backend module registry.
Requirement 12.4 applies: candidate retained unchanged; live reference recorded above.

---

## Candidate 3: Redundant `/ac/fees` `LegacyRouteRedirect`

**What was searched:** A `LegacyRouteRedirect` widget/class that would redirect from an old
path to the current `/ac/fees` route.

**Search scope:** Entire `Dukan_x/` tree (all `*.dart` files excluding `.freezed.dart` and
`.g.dart`); also searched the workspace root for any `legacy_route_redirect.dart` file.

**Exact symbol/path searched:** `LegacyRouteRedirect` (class), `legacy_route_redirect.dart`
(file), any redirect involving `/ac/fees`.

**Result:** 
- **No `LegacyRouteRedirect` class exists** in the Dukan_x codebase. No file named
  `legacy_route_redirect.dart` was found anywhere in the workspace.
- The `/ac/fees` route is **directly bound** to `AcFeeCollectionScreen` via
  `SchoolPermissionGuard` in `legacy_routes.dart` (line 2199). There is no intermediate
  redirect widget.
- The term `LegacyRouteRedirect` appears only in:
  - `tool/audit_system/gap_registry.dart` — as a detection pattern for the audit tool
  - `test/audit/d1_navigation_graph_walk_test.dart` — as a test expectation pattern
  - Comments in `sidebar_navigation_handler.dart` and `app_router.dart` — referring to
    **vegetablesBroker** routes (not schoolErp)

**Decision:** NOT APPLICABLE — the deletion candidate does not exist. There is no
`LegacyRouteRedirect` for `/ac/fees` to delete. Requirement 12.3's precondition ("WHERE a
redundant `LegacyRouteRedirect` exists on `/ac/fees`") is not satisfied.

---

## Task 19.2 — Deletion Disposition

Per the reference search results above:

| Candidate | Live References | Zero-Reference? | Sign-off Obtained? | Deletion Status |
|-----------|----------------:|:---------------:|:------------------:|-----------------|
| `/ac/students` collision residue | 3 | NO | N/A | **BLOCKED** — live references exist |
| `SchoolErpModule.navItems` | 1 (+ out of scope) | NO | N/A | **BLOCKED** — out of scope + live ref |
| `/ac/fees` `LegacyRouteRedirect` | 0 (does not exist) | N/A | N/A | **NOT APPLICABLE** — candidate absent |

**No deletions were performed.** Per Requirement 1.9 and Requirement 12.5–12.6:
- Candidates 1 and 2 have live references → deletion blocked (Req 12.4).
- Candidate 3 does not exist → nothing to delete (Req 12.3 precondition unsatisfied).
- Even if a candidate had zero references, deletion would be BLOCKED pending the literal
  `APPROVED` reply from the user (Req 1.9, 12.5). No sign-off was requested because no
  candidate qualified.

---

## Files Created/Modified/Deleted

| Action | File |
|--------|------|
| CREATED | `.kiro/specs/schoolerp-vertical-remediation/phase9-report.md` (this file) |

No application source, configuration, or build files were modified.
