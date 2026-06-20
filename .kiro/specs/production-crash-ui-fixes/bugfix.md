# Bugfix Requirements Document

## Introduction

DukanX, a multi-tenant Flutter desktop and mobile app, has a set of production-severity bugs spanning four phases of priority. Phase 0 contains app-crashing defects caused by unregistered GetIt services (`DunningService`, `PaymentGatewayApiService`) and null check failures on screens that access session state before sign-in is confirmed. Phase 1 is a high-severity text layout bug where labels wrap one letter per line in narrow flex containers. Phase 2 covers recurring root causes: black backgrounds (missing Scaffold `backgroundColor`), status bar overlapping titles (missing SafeArea/AppBar), a ₹ symbol encoding bug (mojibake), overlapping dashboard cards, and a stuck dark loading overlay. Phase 3 is cosmetic truncation and spacing issues. All bugs affect production users across Android, iOS, Windows, and macOS builds.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN a user navigates to the Dunning Configuration screen THEN the system crashes with "Bad state: GetIt: Object/factory with type DunningService is not registered inside GetIt" because `DunningService` is never registered in the service locator

1.2 WHEN a user navigates to the Payment Gateway Settings screen THEN the system crashes with "Bad state: GetIt: Object/factory with type PaymentGatewayApiService is not registered inside GetIt" because `PaymentGatewayApiService` is never registered in the service locator

1.3 WHEN a user navigates to the Data Import/Export screen before session initialization completes (or while signed out) THEN the system crashes with "Null check operator used on a null value" when accessing `SessionManager.userId!` or a dependent nullable property

1.4 WHEN a user navigates to the Database Management screen before session initialization completes THEN the system crashes with "Null check operator used on a null value" on nullable property access without null-safety guards

1.5 WHEN a Text widget is placed inside a Row without Expanded or Flexible wrapping in BuyFlow Dashboard stat cards THEN the text wraps one letter per line vertically because the Row allocates near-zero intrinsic width to the unconstrained Text

1.6 WHEN a Text widget is placed inside a Row without Expanded or Flexible wrapping in Stock Entry "Total/Due" labels THEN the text wraps one letter per line vertically

1.7 WHEN a Text widget is placed inside a Row without Expanded or Flexible wrapping in Stock Reversal info banner THEN the text wraps one letter per line vertically

1.8 WHEN a Text widget is placed inside a Row without Expanded or Flexible wrapping in New Purchase Order vendor sidebar and "No items added" empty state THEN the text wraps one letter per line vertically

1.9 WHEN the Settings screen is opened THEN the screen renders with a solid black background instead of the theme-appropriate surface color because the Scaffold (or equivalent container) lacks an explicit `backgroundColor`

1.10 WHEN the Financial Reports screen is opened THEN the screen renders with a solid black background

1.11 WHEN the Data Import/Export screen is opened THEN the screen renders with a solid black background

1.12 WHEN the Database Management screen is opened THEN the screen renders with a solid black background

1.13 WHEN the Settings, Financial Reports, Data Import/Export, or Database Management screens are opened THEN the system status bar (time, battery, etc.) overlaps the screen title text because SafeArea or a proper AppBar is missing or incorrectly configured

1.14 WHEN the New Purchase Order screen displays "Total Amount" with ₹ symbol THEN the rupee sign renders as "â‚¹" (mojibake) due to incorrect byte-level string construction or missing UTF-8 font support

1.15 WHEN the main Dashboard renders "Recent Transactions" and "Tax Summary" cards THEN the cards visually overlap or collide because they use a fixed-width layout that does not adapt to the available viewport

1.16 WHEN the Inventory screen finishes loading data THEN a dark semi-transparent overlay (loading skeleton/scrim) remains visible and is never dismissed, blocking user interaction

1.17 WHEN the "Vendor Details" dropdown label is rendered in a constrained container THEN the label is truncated to "Ven..." making it unreadable

1.18 WHEN the "Payment Info" dropdown label is rendered in a constrained container THEN the label is truncated to "Pai..." making it unreadable

### Expected Behavior (Correct)

2.1 WHEN a user navigates to the Dunning Configuration screen THEN the system SHALL either resolve `DunningService` from GetIt (registered as a lazy singleton) or, if the feature is gated behind a subscription tier, display an upgrade prompt UI instead of crashing

2.2 WHEN a user navigates to the Payment Gateway Settings screen THEN the system SHALL either resolve `PaymentGatewayApiService` from GetIt (registered as a lazy singleton) or display an upgrade prompt UI instead of crashing

2.3 WHEN a user navigates to the Data Import/Export screen before session initialization completes THEN the system SHALL gracefully handle a null userId by showing a "Please sign in" message or disabling actions, without crashing

2.4 WHEN a user navigates to the Database Management screen before session initialization completes THEN the system SHALL gracefully handle null state by showing appropriate fallback UI without crashing

2.5 WHEN a Text widget is inside a Row in BuyFlow Dashboard stat cards THEN the system SHALL wrap the Text in Expanded (or Flexible) with TextOverflow.ellipsis so the text fills available horizontal space and truncates gracefully instead of wrapping vertically

2.6 WHEN a Text widget is inside a Row in Stock Entry "Total/Due" labels THEN the system SHALL wrap the Text in Expanded (or Flexible) with TextOverflow.ellipsis

2.7 WHEN a Text widget is inside a Row in Stock Reversal info banner THEN the system SHALL wrap the Text in Expanded (or Flexible) with TextOverflow.ellipsis

2.8 WHEN a Text widget is inside a Row in New Purchase Order vendor sidebar and "No items added" empty state THEN the system SHALL wrap the Text in Expanded (or Flexible) with TextOverflow.ellipsis

2.9 WHEN the Settings screen is opened THEN the system SHALL render with the theme-appropriate surface/background color (dark theme: dark surface; light theme: light surface) by setting `backgroundColor` on the Scaffold

2.10 WHEN the Financial Reports screen is opened THEN the system SHALL render with the theme-appropriate background color

2.11 WHEN the Data Import/Export screen is opened THEN the system SHALL render with the theme-appropriate background color

2.12 WHEN the Database Management screen is opened THEN the system SHALL render with the theme-appropriate background color

2.13 WHEN the Settings, Financial Reports, Data Import/Export, or Database Management screens are opened THEN the system SHALL render content below the system status bar using SafeArea or a properly configured AppBar, preventing any overlap

2.14 WHEN the New Purchase Order screen displays "Total Amount" with ₹ symbol THEN the system SHALL render the correct Unicode rupee sign (₹, U+20B9) without mojibake by using a proper UTF-8 string literal or ensuring the font supports the character

2.15 WHEN the main Dashboard renders "Recent Transactions" and "Tax Summary" cards THEN the system SHALL lay them out responsively (using Wrap, Column, or flex-based layout) so they never overlap regardless of viewport width

2.16 WHEN the Inventory screen finishes loading data THEN the system SHALL dismiss the loading overlay/scrim immediately, restoring full interactivity

2.17 WHEN the "Vendor Details" dropdown label is rendered THEN the system SHALL provide sufficient width or use overflow handling so the full label is readable

2.18 WHEN the "Payment Info" dropdown label is rendered THEN the system SHALL provide sufficient width or use overflow handling so the full label is readable

### Unchanged Behavior (Regression Prevention)

3.1 WHEN a user navigates to any screen where services ARE properly registered in GetIt THEN the system SHALL CONTINUE TO resolve those services normally without any change in behavior

3.2 WHEN a user is signed in and navigates to Data Import/Export or Database Management THEN the system SHALL CONTINUE TO function identically (import CSV, export reports, run VACUUM/ANALYZE/integrity checks)

3.3 WHEN Text widgets are placed in Rows that already have proper Expanded/Flexible wrapping THEN the system SHALL CONTINUE TO render those text labels correctly without any layout regression

3.4 WHEN screens that already have proper Scaffold backgroundColor and SafeArea configuration are opened THEN the system SHALL CONTINUE TO render with correct backgrounds and safe area insets

3.5 WHEN the ₹ symbol is displayed correctly on other screens (e.g., billing, invoices) THEN the system SHALL CONTINUE TO display the rupee symbol correctly on those screens

3.6 WHEN dashboard cards that are already responsive are displayed THEN the system SHALL CONTINUE TO render without overlap on all supported viewport sizes

3.7 WHEN the Inventory screen has no data to load (empty state) THEN the system SHALL CONTINUE TO show the empty state UI correctly without a stuck overlay

3.8 WHEN dropdown labels have sufficient space in their current containers THEN the system SHALL CONTINUE TO render full labels without unnecessary truncation or layout changes

3.9 WHEN subscription-gated features are accessed by users on the correct plan tier THEN the system SHALL CONTINUE TO provide full feature access without showing upgrade prompts

3.10 WHEN the app boots and navigates through all 19+ dashboards THEN the system SHALL CONTINUE TO complete navigation without any unhandled exceptions (integration test verification)
