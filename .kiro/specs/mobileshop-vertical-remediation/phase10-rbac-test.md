# Phase 10 — RBAC Visibility Test per Permission-Tagged Item

**Spec:** `mobileshop-vertical-remediation`
**Task:** 21.3 — Run the RBAC visibility test per permission-tagged item
**Requirement covered:** 13.6
**Method:** Static code review of `sidebarSectionsProvider` filtering logic and `RolePermissions` matrix

---

## Summary

All permission-tagged sidebar items visible to `BusinessType.mobileShop` are correctly filtered by `sidebarSectionsProvider`. For every role that lacks the tagged permission, the item is excluded from the returned sections. **Overall result: PASS.**

---

## Provider Filtering Logic (verified)

**File:** `lib/widgets/desktop/sidebar_configuration.dart`
**Provider:** `sidebarSectionsProvider` (line ~80)

The provider:
1. Calls `_getSectionsForBusiness(businessTypeState.type)` → for `mobileShop`, returns `_getMobileShopSections()`.
2. For each item, checks `item.permission != null`.
3. Maps the permission string to `Permission` enum: `Permission.values.firstWhere((p) => p.name == item.permission, orElse: () => Permission.manageSettings)`.
4. Evaluates `RolePermissions.hasPermission(userRole, permission)` → if `false`, item is **excluded**.
5. Sections with zero remaining items are removed entirely.

This confirms the filtering logic correctly blocks any item whose permission tag is not held by the user's role.

---

## Permission-Tagged Items in the mobileShop Sidebar

`_getMobileShopSections()` returns:
- 5 mobile-specific items (capability-gated, NO permission tags)
- `..._getCommonSections(startingIndex: 1)` — shared common sections with permission tags

### Items carrying a `permission` tag (from `_getCommonSections`):

| # | Item ID | Label | Section | Permission Tag | Permission Enum Resolves To |
|---|---------|-------|---------|----------------|-----------------------------|
| 1 | `invoice_margin` | Profit & Loss | Reports & Analytics | `'viewReports'` | `Permission.viewReports` |
| 2 | `gstr1` | GST Reports | Reports & Analytics | `'viewGstReports'` | `Permission.viewGstReports` |
| 3 | `print_settings` | Printing | System | `'manageSettings'` | `Permission.manageSettings` |
| 4 | `backup` | Backup | System | `'manageSettings'` | `Permission.manageSettings` |
| 5 | `error_logs` | System Logs | System | `'viewAuditLog'` | `Permission.viewAuditLog` |
| 6 | `device_settings` | Settings | System | `'manageSettings'` | `Permission.manageSettings` |

---

## RolePermissions Matrix (relevant permissions)

**Source:** `lib/services/role_management_service.dart`, class `RolePermissions`

| Permission | owner | accountant | manager | staff |
|------------|:-----:|:----------:|:-------:|:-----:|
| `viewReports` | ✅ | ✅ | ✅ | ❌ |
| `viewGstReports` | ✅ | ✅ | ❌ | ❌ |
| `viewAuditLog` | ✅ | ✅ | ❌ | ❌ |
| `manageSettings` | ✅ | ❌ | ❌ | ❌ |

---

## Per-Item RBAC Visibility Test Results

### Item 1: `invoice_margin` (Profit & Loss) — permission: `viewReports`

| Role | Has `viewReports`? | Item visible? | Expected | Result |
|------|:------------------:|:-------------:|:--------:|:------:|
| owner | ✅ | ✅ Shown | Shown | **PASS** |
| accountant | ✅ | ✅ Shown | Shown | **PASS** |
| manager | ✅ | ✅ Shown | Shown | **PASS** |
| staff | ❌ | ❌ Hidden | Hidden | **PASS** |

### Item 2: `gstr1` (GST Reports) — permission: `viewGstReports`

| Role | Has `viewGstReports`? | Item visible? | Expected | Result |
|------|:---------------------:|:-------------:|:--------:|:------:|
| owner | ✅ | ✅ Shown | Shown | **PASS** |
| accountant | ✅ | ✅ Shown | Shown | **PASS** |
| manager | ❌ | ❌ Hidden | Hidden | **PASS** |
| staff | ❌ | ❌ Hidden | Hidden | **PASS** |

### Item 3: `print_settings` (Printing) — permission: `manageSettings`

| Role | Has `manageSettings`? | Item visible? | Expected | Result |
|------|:---------------------:|:-------------:|:--------:|:------:|
| owner | ✅ | ✅ Shown | Shown | **PASS** |
| accountant | ❌ | ❌ Hidden | Hidden | **PASS** |
| manager | ❌ | ❌ Hidden | Hidden | **PASS** |
| staff | ❌ | ❌ Hidden | Hidden | **PASS** |

### Item 4: `backup` (Backup) — permission: `manageSettings`

| Role | Has `manageSettings`? | Item visible? | Expected | Result |
|------|:---------------------:|:-------------:|:--------:|:------:|
| owner | ✅ | ✅ Shown | Shown | **PASS** |
| accountant | ❌ | ❌ Hidden | Hidden | **PASS** |
| manager | ❌ | ❌ Hidden | Hidden | **PASS** |
| staff | ❌ | ❌ Hidden | Hidden | **PASS** |

### Item 5: `error_logs` (System Logs) — permission: `viewAuditLog`

| Role | Has `viewAuditLog`? | Item visible? | Expected | Result |
|------|:-------------------:|:-------------:|:--------:|:------:|
| owner | ✅ | ✅ Shown | Shown | **PASS** |
| accountant | ✅ | ✅ Shown | Shown | **PASS** |
| manager | ❌ | ❌ Hidden | Hidden | **PASS** |
| staff | ❌ | ❌ Hidden | Hidden | **PASS** |

### Item 6: `device_settings` (Settings) — permission: `manageSettings`

| Role | Has `manageSettings`? | Item visible? | Expected | Result |
|------|:---------------------:|:-------------:|:--------:|:------:|
| owner | ✅ | ✅ Shown | Shown | **PASS** |
| accountant | ❌ | ❌ Hidden | Hidden | **PASS** |
| manager | ❌ | ❌ Hidden | Hidden | **PASS** |
| staff | ❌ | ❌ Hidden | Hidden | **PASS** |

---

## Specific Verification: `staff` role blocked from sensitive items

Per Requirement 13.6, specifically verifying that the `staff` role is blocked from items gated by `viewReports`, `viewGstReports`, `viewAuditLog`, and `manageSettings`:

| Permission | `staff` has it? | Items blocked | Verified |
|------------|:---------------:|---------------|:--------:|
| `viewReports` | ❌ (not in staff set) | `invoice_margin` | ✅ PASS |
| `viewGstReports` | ❌ (not in staff set) | `gstr1` | ✅ PASS |
| `viewAuditLog` | ❌ (not in staff set) | `error_logs` | ✅ PASS |
| `manageSettings` | ❌ (not in staff set) | `print_settings`, `backup`, `device_settings` | ✅ PASS |

The `staff` role's permission set in `RolePermissions._permissions` is:
```dart
UserRole.staff: {
  Permission.createBill, Permission.printBill,
  Permission.createCustomer, Permission.viewCustomerBalance,
  Permission.viewStock,
  Permission.receivePayment,
  Permission.closeCashDay,
}
```

None of the four relevant permissions (`viewReports`, `viewGstReports`, `viewAuditLog`, `manageSettings`) appear in this set. `RolePermissions.hasPermission(UserRole.staff, Permission.viewReports)` → `false`, and likewise for the other three. The provider correctly excludes these items for the `staff` role.

---

## Edge Cases Verified

1. **Null session:** When `session == null`, the provider returns `false` for any permission-tagged item (line: `if (session == null) return false;`). → All permission-tagged items hidden. **PASS.**

2. **Unknown role (`UserRole.unknown`):** Not in `_permissions` map → `_permissions[UserRole.unknown]?.contains(...)` → `null?.contains(...)` → `?? false`. → All permission-tagged items hidden. **PASS.**

3. **Fallback for unrecognized permission string:** `Permission.values.firstWhere(..., orElse: () => Permission.manageSettings)` — an unrecognized permission string falls back to `manageSettings` (owner-only), which is the most restrictive sensible default. **PASS.**

---

## Conclusion

**All 6 permission-tagged sidebar items visible to `BusinessType.mobileShop` are correctly filtered by `sidebarSectionsProvider`.** For each item, roles lacking the tagged permission are blocked (item excluded from the section list), and roles holding the permission see the item. The `staff` role is specifically confirmed to be blocked from all items gated by `viewReports`, `viewGstReports`, `viewAuditLog`, and `manageSettings`.

**Overall RBAC visibility test result: PASS (all items, all roles).**
