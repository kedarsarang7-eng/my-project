# Manual Smoke-Test Checklist — Clothing Vertical

## Prerequisites
- Log in as a clothing merchant (BusinessType.clothing)
- Desktop app running

## Sidebar Navigation Tests

| # | Action | Expected Result | Pass/Fail |
|---|--------|----------------|-----------|
| 1 | Click "Variant Matrix" in clothing sidebar | Opens VariantManagementScreen with size×color grid | ☐ |
| 2 | Click "Tailoring / Alterations" | Opens TailoringMeasurementsScreen | ☐ |
| 3 | Click "Size & Color Stock Overview" | Opens ClothingInventoryScreen with tabs | ☐ |
| 4 | Click "Price-Tag / Barcode Printing" | Opens PrintMenuScreen | ☐ |
| 5 | None of the above shows "Unknown Screen" | No placeholder screens shown | ☐ |

## Quick Action Tests
| # | Action | Expected Result | Pass/Fail |
|---|--------|----------------|-----------|
| 6 | Click "Variants" quick action on dashboard | Navigates to VariantManagementScreen (not CategoriesScreen) | ☐ |

## Route Guard Tests
| # | Action | Expected Result | Pass/Fail |
|---|--------|----------------|-----------|
| 7 | Navigate to /clothing/variants without inventory permission | Blocked, redirected, access-denied shown | ☐ |

## Save Path Tests
| # | Action | Expected Result | Pass/Fail |
|---|--------|----------------|-----------|
| 8 | Edit variant grid quantities → tap Save | Success SnackBar shown within 2s | ☐ |
| 9 | Disconnect network → edit → Save | Data retained locally, sync indicator shows pending | ☐ |

## Tailoring Tests
| # | Action | Expected Result | Pass/Fail |
|---|--------|----------------|-----------|
| 10 | From bill, tap "Take Measurements" | Opens tailoring screen with customer/invoice context | ☐ |
| 11 | Enter invalid measurement → Save | Error names invalid field, values retained | ☐ |

## Dark Mode Test
| # | Action | Expected Result | Pass/Fail |
|---|--------|----------------|-----------|
| 12 | Switch to dark theme | All clothing screens render without hardcoded white/gold | ☐ |
