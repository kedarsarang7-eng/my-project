# Bugfix Requirements Document

## Introduction

Six critical production defects affecting DukanX, a multi-tenant Flutter cross-platform (Android, iOS, Windows, macOS, Linux) business/accounting application. These defects span profile persistence, UI/UX rendering, invoice management with RBAC, navigation, data display, and invoice number generation. All fixes must respect the multi-tenant architecture (scoped to businessId), work offline-first with sync reconciliation, and function across all supported platforms.

**Defects covered:**
1. Vendor/Business Profile fails to save
2. GST Report Screen UI/UX overflow and misalignment (Android-focused)
3. Invoice Preview opens wrong invoice + missing Edit/Delete with RBAC enforcement
4. Dashboard widget oversizing + missing universal Back button
5. Daybook data not displaying
6. Invoice number generation (format, uniqueness, offline-safety)

## Bug Analysis

### Current Behavior (Defect)

**Defect 1 — Vendor/Business Profile Fails to Save**

1.1 WHEN a user fills out the Vendor/Business Profile form and taps Save THEN the system displays "Failed to Save Profile" or throws "Exception: Failed to Save" and the profile data is not persisted to either local storage or remote database

1.2 WHEN a user attempts to save the Vendor/Business Profile while offline THEN the system fails to queue the save operation for later sync and displays a save failure error instead of persisting locally and scheduling sync

1.3 WHEN a user saves a profile with valid data that includes special characters or locale-specific formatting (e.g., GSTIN, phone with country code) THEN the system fails during serialization (toJson/toMap) due to improper field validation or type conversion

**Defect 2 — GST Report Screen UI/UX (Android-focused)**

1.4 WHEN the GST Report Screen is opened on an Android device with screen width between 320dp and 600dp THEN the system renders a black background instead of the theme-appropriate surface color

1.5 WHEN the GST Report Screen is opened on a narrow viewport (320dp–400dp) THEN the system produces yellow/black RenderFlex overflow stripes because widgets exceed available horizontal space

1.6 WHEN KPI cards are rendered on the GST Report Screen on mobile THEN the system displays misaligned cards with overlapping text, inconsistent heights, and content overflowing card boundaries

1.7 WHEN the GST Report Screen is rendered on any viewport width between 320dp and desktop THEN the system shows text overflow (ellipsis or clipping) on report labels and values due to hardcoded widths and missing responsive sizing

**Defect 3 — Invoice Preview, Edit, Delete + RBAC**

1.8 WHEN a user taps an invoice in the Recent Transactions list THEN the system opens the wrong invoice (incorrect index or stale data reference) instead of the selected invoice

1.9 WHEN a user with Admin role views an invoice THEN the system provides no Edit or Delete actions, despite the user having full permissions

1.10 WHEN a user with CA, Staff, or Salesman role attempts to edit or delete an invoice via direct API or deep link THEN the system does not enforce permission checks at the service/data layer, allowing unauthorized modifications

1.11 WHEN any user accesses invoice operations THEN the system performs permission checks (if any) scattered across multiple UI widgets rather than centralized in a single PermissionService, leading to inconsistent enforcement

**Defect 4 — Dashboard Widget Sizing + Universal Back Button**

1.12 WHEN the Executive Dashboard is viewed on an Android phone (screen width < 600dp) THEN the system renders oversized widgets that overflow the viewport, requiring excessive scrolling and causing layout breaks

1.13 WHEN a user navigates to any specialized/share screen (beyond the main dashboard) THEN the system provides no consistent Back button, forcing the user to rely on system-level back gestures which may not be available on all platforms

**Defect 5 — Daybook Data Not Displaying**

1.14 WHEN a user opens the Daybook screen with valid transactions for the active businessId THEN the system displays an empty screen with no data, despite records existing in the database

1.15 WHEN the Daybook screen loads THEN the system does not show proper loading, empty, or error state indicators — the screen appears blank with no feedback to the user

1.16 WHEN the Daybook screen fetches data THEN the system does not properly scope the query to the active businessId and/or applies incorrect date-range/filter logic, returning zero results

**Defect 6 — Invoice Number Generation**

1.17 WHEN a new invoice is created THEN the system generates a random or unpredictable invoice number instead of using the required format YYYYMMDD + zero-padded sequence (e.g., 202606200001)

1.18 WHEN multiple invoices are created concurrently (e.g., two devices for the same business) THEN the system may generate duplicate invoice numbers due to lack of concurrency-safe sequence generation (no DB transaction with unique constraint)

1.19 WHEN a new business creates its first invoice THEN the system does not start the sequence at a configurable starting number (default 0001), potentially starting at random or undefined values

1.20 WHEN invoices are created offline on multiple devices THEN the system has no reservation scheme, leading to collisions when devices sync back to the server

### Expected Behavior (Correct)

**Defect 1 — Vendor/Business Profile Fails to Save**

2.1 WHEN a user fills out the Vendor/Business Profile form and taps Save THEN the system SHALL validate all form fields, serialize the data correctly (handling GSTIN, phone, address fields), persist to local storage immediately, and sync to remote database when online — displaying a success confirmation

2.2 WHEN a user attempts to save the Vendor/Business Profile while offline THEN the system SHALL persist the profile to local storage, enqueue the save operation in the sync queue, and display "Saved locally — will sync when online"

2.3 WHEN a user saves a profile with special characters or locale-specific formatting THEN the system SHALL properly validate and serialize all fields without throwing exceptions, handling edge cases in toJson/toMap conversion gracefully

**Defect 2 — GST Report Screen UI/UX (Android-focused)**

2.4 WHEN the GST Report Screen is opened on any device THEN the system SHALL render with the theme-appropriate background color (using Scaffold backgroundColor or theme surface color), never showing a black background

2.5 WHEN the GST Report Screen is opened on any viewport from 320dp to desktop THEN the system SHALL produce zero RenderFlex overflow warnings by using responsive layout units (MediaQuery, LayoutBuilder, or responsive utilities) and wrapping/scrolling where needed

2.6 WHEN KPI cards are rendered on the GST Report Screen on mobile (< 600dp) THEN the system SHALL display cards in a responsive grid (2-column on mobile) with consistent heights, proper padding, and no overlapping or overflowing content

2.7 WHEN report labels and values are rendered on the GST Report Screen THEN the system SHALL use responsive font sizes and flexible containers that prevent text overflow on all breakpoints from 320dp to desktop

**Defect 3 — Invoice Preview, Edit, Delete + RBAC**

2.8 WHEN a user taps an invoice in the Recent Transactions list THEN the system SHALL open the exact invoice that was tapped by using a stable unique identifier (invoiceId) rather than a positional index

2.9 WHEN a user with Admin role views an invoice THEN the system SHALL display Edit and Delete action buttons that are fully functional

2.10 WHEN a user with CA, Staff, or Salesman role views an invoice THEN the system SHALL display the invoice in View-only mode with Edit and Delete actions hidden or disabled, and any attempt to invoke edit/delete at the service layer SHALL be rejected with an authorization error

2.11 WHEN any user accesses invoice operations THEN the system SHALL enforce permissions through a centralized PermissionService that validates the user's role against the required permission at the service/data layer, not just the UI layer

**Defect 4 — Dashboard Widget Sizing + Universal Back Button**

2.12 WHEN the Executive Dashboard is viewed on an Android phone (< 600dp) THEN the system SHALL render appropriately sized widgets using responsive sizing that fits within the viewport without overflow, reducing card sizes and using compact layouts

2.13 WHEN a user navigates to any specialized or share screen across every business type THEN the system SHALL display a consistent Back button via a shared AppScaffold component that auto-injects navigation, working identically across Android, iOS, Windows, macOS, and Linux

**Defect 5 — Daybook Data Not Displaying**

2.14 WHEN a user opens the Daybook screen THEN the system SHALL fetch and display all transaction records scoped to the active businessId for the selected date range, with accurate calculations (totals, running balances)

2.15 WHEN the Daybook screen is loading data THEN the system SHALL show a loading indicator; when no data exists, display an empty state message; when an error occurs, display an actionable error state with retry option

2.16 WHEN the Daybook screen fetches data THEN the system SHALL correctly scope the query to the active businessId, apply the selected date-range filter, and support real-time updates when new transactions are added

**Defect 6 — Invoice Number Generation**

2.17 WHEN a new invoice is created THEN the system SHALL auto-generate an invoice number in the format YYYYMMDD + zero-padded 4-digit sequence (e.g., 202606200001), never random, always deterministic based on date and sequence

2.18 WHEN multiple invoices are created concurrently for the same business THEN the system SHALL use a database transaction with unique constraint to ensure monotonic increment and prevent duplicate numbers

2.19 WHEN a new business creates its first invoice THEN the system SHALL start the sequence at a configurable starting number (default 0001 for the first date)

2.20 WHEN invoices are created offline on multiple devices THEN the system SHALL use a reservation scheme (pre-allocated number blocks per device) and reconcile on sync without collisions, preserving uniqueness per business

### Unchanged Behavior (Regression Prevention)

**Defect 1 — Profile Save**

3.1 WHEN a user loads an existing saved profile THEN the system SHALL CONTINUE TO display all previously saved fields correctly without data loss

3.2 WHEN a user saves a profile while online and connectivity is stable THEN the system SHALL CONTINUE TO sync immediately to the remote database as before

**Defect 2 — GST Report Screen**

3.3 WHEN the GST Report Screen is viewed on desktop (≥ 1100dp) THEN the system SHALL CONTINUE TO render the existing multi-column layout with full-width KPI cards in a single row

3.4 WHEN GST Report calculations are performed THEN the system SHALL CONTINUE TO produce identical numerical results regardless of layout changes

**Defect 3 — Invoice RBAC**

3.5 WHEN a user with Admin role performs any existing invoice operation (create, view, share, print) THEN the system SHALL CONTINUE TO allow those operations without regression

3.6 WHEN a user with CA, Staff, or Salesman role views invoices THEN the system SHALL CONTINUE TO display invoice details in read-only mode exactly as before

3.7 WHEN invoice data is loaded for the Recent Transactions list THEN the system SHALL CONTINUE TO display the same invoice metadata (number, date, amount, customer) without regression

**Defect 4 — Dashboard + Navigation**

3.8 WHEN the Executive Dashboard is viewed on desktop or tablet (≥ 600dp) THEN the system SHALL CONTINUE TO render widgets at their current sizes without any layout changes

3.9 WHEN a user is on the main dashboard (home screen) THEN the system SHALL NOT display a Back button (no parent screen to navigate to)

**Defect 5 — Daybook**

3.10 WHEN the Daybook screen displays data correctly for a given business THEN the system SHALL CONTINUE TO show the same transaction records with identical totals and calculations after the fix

3.11 WHEN the Daybook screen applies date-range filters on working businesses THEN the system SHALL CONTINUE TO respect the same filter boundaries and business scoping rules

**Defect 6 — Invoice Numbers**

3.12 WHEN existing invoices have already been created with their current numbers THEN the system SHALL CONTINUE TO display and reference those existing numbers without renumbering or invalidation

3.13 WHEN invoice numbers are displayed in reports, PDFs, and shared documents THEN the system SHALL CONTINUE TO show the invoice number in all existing display contexts without format regression

---

## Bug Condition (Formal)

### Defect 1 — Profile Save Failure

```pascal
FUNCTION isBugCondition_ProfileSave(X)
  INPUT: X of type ProfileSaveInput { formData: Map, isOnline: boolean, businessId: string }
  OUTPUT: boolean
  
  // Bug triggers on any profile save attempt (always fails currently)
  RETURN X.formData IS NOT EMPTY AND X.businessId IS NOT NULL
END FUNCTION
```

```pascal
// Property: Fix Checking — Profile saves succeed
FOR ALL X WHERE isBugCondition_ProfileSave(X) DO
  result ← saveProfile'(X)
  ASSERT result.isSuccess = true
  ASSERT result.localPersisted = true
  IF X.isOnline THEN
    ASSERT result.remoteSynced = true
  ELSE
    ASSERT result.syncQueued = true
  END IF
END FOR
```

```pascal
// Property: Preservation Checking — Profile load unchanged
FOR ALL X WHERE NOT isBugCondition_ProfileSave(X) DO
  ASSERT loadProfile(X) = loadProfile'(X)
END FOR
```

### Defect 2 — GST Report Screen UI

```pascal
FUNCTION isBugCondition_GstReportUI(X)
  INPUT: X of type ScreenRenderInput { screenWidth: double, platform: string }
  OUTPUT: boolean
  
  // Bug triggers on mobile viewports
  RETURN X.screenWidth < 600
END FUNCTION
```

```pascal
// Property: Fix Checking — No overflow on mobile
FOR ALL X WHERE isBugCondition_GstReportUI(X) DO
  rendered ← renderGstReportScreen'(X)
  ASSERT rendered.overflowWarnings = 0
  ASSERT rendered.backgroundColor != Color.black
  ASSERT rendered.kpiCardsOverlap = false
  ASSERT rendered.textTruncation = false
END FOR
```

```pascal
// Property: Preservation Checking — Desktop layout unchanged
FOR ALL X WHERE NOT isBugCondition_GstReportUI(X) DO
  ASSERT renderGstReportScreen(X) = renderGstReportScreen'(X)
END FOR
```

### Defect 3 — Invoice Preview + RBAC

```pascal
FUNCTION isBugCondition_InvoiceRBAC(X)
  INPUT: X of type InvoiceActionInput { action: string, userRole: UserRole, invoiceId: string }
  OUTPUT: boolean
  
  // Bug condition 1: Tapping any invoice (wrong one opens)
  // Bug condition 2: Admin cannot edit/delete (missing actions)
  // Bug condition 3: Non-admin can edit/delete (no enforcement)
  RETURN X.action = "tap_invoice"
    OR (X.action IN {"edit", "delete"} AND X.userRole = UserRole.admin)
    OR (X.action IN {"edit", "delete"} AND X.userRole IN {UserRole.ca, UserRole.staff, UserRole.salesman})
END FUNCTION
```

```pascal
// Property: Fix Checking — Correct invoice opens and RBAC enforced
FOR ALL X WHERE isBugCondition_InvoiceRBAC(X) DO
  IF X.action = "tap_invoice" THEN
    result ← openInvoice'(X.invoiceId)
    ASSERT result.displayedInvoiceId = X.invoiceId
  END IF
  IF X.action IN {"edit", "delete"} AND X.userRole = UserRole.admin THEN
    result ← performInvoiceAction'(X)
    ASSERT result.isAllowed = true
  END IF
  IF X.action IN {"edit", "delete"} AND X.userRole IN {UserRole.ca, UserRole.staff, UserRole.salesman} THEN
    result ← performInvoiceAction'(X)
    ASSERT result.isAllowed = false
    ASSERT result.error = "Unauthorized"
  END IF
END FOR
```

```pascal
// Property: Preservation Checking — View access unchanged
FOR ALL X WHERE NOT isBugCondition_InvoiceRBAC(X) DO
  ASSERT invoiceOperation(X) = invoiceOperation'(X)
END FOR
```

### Defect 4 — Dashboard Sizing + Back Button

```pascal
FUNCTION isBugCondition_DashboardNav(X)
  INPUT: X of type NavigationInput { screenWidth: double, screenType: string, isHomeScreen: boolean }
  OUTPUT: boolean
  
  // Bug: oversized widgets on mobile OR missing back button on sub-screens
  RETURN (X.screenWidth < 600 AND X.screenType = "executive_dashboard")
    OR (X.isHomeScreen = false AND X.screenType != "main_dashboard")
END FUNCTION
```

```pascal
// Property: Fix Checking — Responsive sizing and back navigation
FOR ALL X WHERE isBugCondition_DashboardNav(X) DO
  rendered ← renderScreen'(X)
  IF X.screenWidth < 600 AND X.screenType = "executive_dashboard" THEN
    ASSERT rendered.widgetsWithinViewport = true
    ASSERT rendered.overflowWarnings = 0
  END IF
  IF X.isHomeScreen = false THEN
    ASSERT rendered.hasBackButton = true
  END IF
END FOR
```

```pascal
// Property: Preservation Checking — Desktop and home screen unchanged
FOR ALL X WHERE NOT isBugCondition_DashboardNav(X) DO
  ASSERT renderScreen(X) = renderScreen'(X)
END FOR
```

### Defect 5 — Daybook Data Not Displaying

```pascal
FUNCTION isBugCondition_Daybook(X)
  INPUT: X of type DaybookInput { businessId: string, dateRange: DateRange, hasRecords: boolean }
  OUTPUT: boolean
  
  // Bug triggers when valid records exist but aren't displayed
  RETURN X.businessId IS NOT NULL AND X.hasRecords = true
END FUNCTION
```

```pascal
// Property: Fix Checking — Data displays correctly
FOR ALL X WHERE isBugCondition_Daybook(X) DO
  result ← loadDaybook'(X)
  ASSERT result.records.length > 0
  ASSERT result.records ARE SCOPED TO X.businessId
  ASSERT result.totals ARE ACCURATE
  ASSERT result.state = "loaded"
END FOR
```

```pascal
// Property: Preservation Checking — Empty/error states preserved
FOR ALL X WHERE NOT isBugCondition_Daybook(X) DO
  ASSERT loadDaybook(X) = loadDaybook'(X)
END FOR
```

### Defect 6 — Invoice Number Generation

```pascal
FUNCTION isBugCondition_InvoiceNumber(X)
  INPUT: X of type InvoiceCreationInput { businessId: string, date: Date, isOffline: boolean, concurrentDevices: int }
  OUTPUT: boolean
  
  // Bug triggers on any invoice creation (format always wrong currently)
  RETURN X.businessId IS NOT NULL
END FUNCTION
```

```pascal
// Property: Fix Checking — Correct format and uniqueness
FOR ALL X WHERE isBugCondition_InvoiceNumber(X) DO
  number ← generateInvoiceNumber'(X)
  ASSERT number MATCHES pattern "YYYYMMDD" + 4-digit-zero-padded
  ASSERT number IS UNIQUE within X.businessId
  ASSERT number IS MONOTONICALLY INCREASING for same date
  IF X.isOffline THEN
    ASSERT number IS FROM reserved block
    ASSERT reconcile'(number) HAS NO collisions
  END IF
END FOR
```

```pascal
// Property: Preservation Checking — Existing numbers unchanged
FOR ALL X WHERE NOT isBugCondition_InvoiceNumber(X) DO
  ASSERT existingInvoiceNumbers(X) = existingInvoiceNumbers'(X)
END FOR
```
