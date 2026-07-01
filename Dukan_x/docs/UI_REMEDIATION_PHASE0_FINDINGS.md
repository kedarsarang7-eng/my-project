# Phase 0 — Root Cause Investigation Findings

> Generated for the DukanX multi-platform UI remediation (Android phone/tablet, iOS/iPadOS, macOS).
> **Windows path must remain unchanged.** Every fix below is platform-conditional where shared
> widgets are involved.

## Methodology note (text-scale testing)

The brief mandates testing every affected screen at system text scale 1.0x / 1.3x / 1.6x / 2.0x.
These tests require a physical device or emulator (Settings ▸ Font size / Accessibility), which
cannot be executed in this headless environment. Instead, Phase 0 was conducted by **static layout
analysis**: reading the widget tree of every affected screen, identifying fixed-width containers
and Text widgets lacking `maxLines`/`overflow`, and confirming the absence of any app-wide
`textScaler` clamp. This lets us predict the break-point of each widget precisely:

- **Breaks at 1.0x** → fixed-width layout with no flex (`Row` of `SizedBox`/`Container` width).
- **Breaks at ≥1.3x** → layout is flex-based (`Expanded`) but Text has no `maxLines`/`overflow`,
  so increased font size overflows the card.

The verification matrix in Phase 3 lists these as "must re-test on device" rather than claiming
a pass from static analysis alone.

---

## 1. Text scaling — NO app-wide cap, NO overflow safety net

**Confirmed root cause.**

- `lib/app/app.dart:127` — the `MaterialApp.builder` wraps `child` in
  `GlobalKeyboardHandler ▸ SyncConflictListener ▸ LicenseInvalidListener ▸ Stack`.
  There is **no `MediaQuery` override** clamping `textScaler` anywhere in the tree.
- `lib/main.dart` — root launches `DukanXApp` directly; no wrapper above it.

**Consequence:** every screen inherits the OS text-scale factor unmodified. On Android ≥1.3x and
iOS accessibility sizes, fixed-width layouts shatter.

## 2. KPI card / grid layout

### Dashboard v2 KPI row — `lib/features/dashboard/v2/widgets/performance_cards.dart`
- `PerformanceCards._buildCards` (line 27): `Row` of **4 `Expanded` `_KpiCard`**.
  Flex-based, so it survives 1.0x, but 4 cards on a narrow phone (~360–400dp) leaves each card
  ~80dp wide → a `₹1,23,456` value at `fontSize: 24` (line 266) **overflows** even at 1.0x on
  small phones, and wraps/overflows at 1.3x on all phones.
- **No responsive collapse** to a 2×2 grid on narrow widths.
- Every `Text` (title line 254, value line 266, subtitle line 280, badge line 238,
  change line 324/334) **lacks `maxLines` + `overflow`**.
- Trend/change indicator (`_ChangeIndicator`, line 319) is a `Row(mainAxisSize: min)` — fine,
  no `Positioned` escaping the card. (The brief's "↗ badge escapes card" hypothesis does **not**
  apply to this widget — the badge is a normal `Spacer()`-aligned `Container`.)

### Legacy dashboard metrics — `lib/screens/dashboard_metrics_row.dart`
- `Row` of **4 `Expanded` `_MetricCard`** (line 47) — flex-based.
- `_MetricCard` `Text` widgets (title line 126, value line 138) **lack `maxLines`/`overflow`**.
- Value is `₹<number>` at `fontSize: 24`; same overflow risk as above.

### Recommendation
The structural fix is: (a) app-wide `textScaler` clamp (Phase 1A) as the safety net, plus
(b) make these rows collapse to 2 columns when width is narrow (Phase 1B), plus (c) add
`maxLines: 1, overflow: ellipsis` and `FittedBox(scaleDown)` on value text.

## 3. Scaffold backgroundColor — two distinct failure modes

**Reference (correct):**
- `lib/providers/app_state_providers.dart` `_buildTheme`:
  - Light: `scaffoldBackgroundColor: palette.offWhite` (`Color(0xFFF8FAFC)`)
  - Dark:  `scaffoldBackgroundColor: Color(0xFF0F172A)`
- `lib/features/inventory/presentation/screens/inventory_dashboard_screen.dart:416`
  (mobile): `backgroundColor: isDark ? FuturisticColors.darkBackground : FuturisticColors.background`.

**Failure mode A — wrong explicit color (renders dark in light theme):**
| Screen | File:line | Issue |
|---|---|---|
| New Purchase Order | `lib/features/purchase/screens/add_purchase_screen.dart:337` | `backgroundColor: palette.mutedGray` — `mutedGray` is **dark slate** (`0xFF1E293B`/`0xFF0F172A`). Forces navy in light theme. |

Siblings with the identical bug: `purchase_dashboard_screen.dart:37`,
`purchase_history_screen.dart:47`.

**Failure mode B — no Scaffold / no explicit bg (inherits shell):**
| Screen | File | Wrapper |
|---|---|---|
| Buy Orders (PO list) | `lib/features/buy_flow/screens/buy_orders_screen.dart:30` | `DesktopContentContainer` (no Scaffold) |
| Stock Reversal/Return | `lib/features/buy_flow/screens/stock_reversal_screen.dart:431` | `DesktopContentContainer` |
| GST Reports | `lib/features/gst/screens/gst_reports_screen.dart:62` | `DesktopContentContainer` |
| Payment Reminders | `lib/features/settings/presentation/screens/payment_reminders_screen.dart:176` | `DesktopContentContainer` |
| Suppliers & Payouts | `lib/features/buy_flow/screens/vendor_payouts_screen.dart:31` | `DesktopContentContainer` |
| Stock Entry | `lib/features/stock/presentation/screens/add_stock_screen.dart:247` | `Scaffold` w/ **no** `backgroundColor` (body gradient Container instead) |

**Note:** `DesktopContentContainer` renders only a header `Container` + child; it sets no
background. These screens are rendered inside the adaptive shell, whose own Scaffold background
governs them. The bug is that several inner widgets hard-code `Colors.white` (e.g.
`gst_reports_screen.dart:114`), which breaks in dark mode and looks like a background mismatch.
The robust fix is to mirror Inventory's pattern and give each screen an explicit themed
`backgroundColor` (or ensure the shell does) plus replace hard-coded `Colors.white` card fills
with themed surface colors.

## 4. Inventory "stuck dark overlay"

**Corrected hypothesis.** There is no boolean/provider stuck `true` and no undisposed
modal barrier in the Inventory screens. The persistent translucent darkening described in the
report is caused by **`GlassContainer`** (`lib/widgets/glass_container.dart`):

- Default `opacity: 0.1` + `BackdropFilter` blur (line 51) + `color.withOpacity(0.1)` (line 56).
- When used as a screen-body/footer/panel, it produces a permanent **translucent blurred layer**
  that visually darkens and fuses with content behind it — indistinguishable from a "stuck scrim".

`GlassContainer` is widely reused (New Sale summary footer, purchase sections, etc.), so this is a
**systemic translucency issue**, not an Inventory-specific stuck state.

**Fix direction:** where `GlassContainer` is used as a primary content surface (not a deliberate
glass effect over an image/gradient), wrap it in or replace with an opaque themed `Container`,
or pass an explicit `color` + higher `opacity`. Inventory list items must render at full opacity
and remain tappable.

## 5. Language picker — transparency + mojibake (two bugs)

### 5a. Transparency
`lib/features/settings/presentation/screens/main_settings_screen.dart:1264` `_showLanguageSelector`:
- `showModalBottomSheet(backgroundColor: Colors.transparent, ...)` (line 1273)
- builder returns a `DraggableScrollableSheet(expand: false)` whose root is a bare `Column`
  (line 1283) — **no `Container`/`Material` with opaque background**. The list rows render
  directly over whatever is behind the sheet → visual merge.

### 5b. Mojibake (garbled text + flags) — THE encoding root cause
`lib/core/localization/localization_service.dart:30` `supportedLocales`:
- `nativeName` values are **double-encoded mojibake** stored in the source file
  (e.g. `'à¤¹à¤¿à¤‚à¤¦à¥€'` instead of `'हिंदी'`).
- `flag` values are **mojibake too** (e.g. `'ðŸ‡®ðŸ‡³'` instead of `'🇮🇳'`).
- Verified at the byte level: the file contains **76 × `0xC3` bytes** — the signature of UTF-8
  text that was itself mis-interpreted as Latin-1 and re-encoded as UTF-8. This is a **source-file
  corruption**, not a runtime decode bug.

The language picker (`main_settings_screen.dart:1313`) renders `info.flag` and
`info.nativeName` from this corrupted map → garbled flags + script.

### 5c. ₹ symbol — separate finding (source is CLEAN)
- The New Purchase Order total (`add_purchase_screen.dart:632`) uses a **correct hardcoded `₹`**.
- `AppL10n.formatCurrency` (`lib/core/localization/app_l10n.dart:99`) uses a correct `₹`.
- Byte-level check: `app_l10n.dart`, `add_purchase_screen.dart`,
  `bill_creation_screen_v2.dart` all have **0 × `0xC3`** — clean UTF-8.
- **Conclusion:** the "â‚¹" garble reported on the New PO total is **not present in current source**.
  It most likely originated from a localization ARB/JSON asset or a now-changed string. We will
  still verify the ARB asset encoding in Phase 1F and fix `localization_service.dart` (5b).

## 6. New Sale bottom panel / mic button

`lib/features/billing/presentation/screens/bill_creation_screen_v2.dart` (`_buildMobileLayout`):
- The summary panel is `bottomNavigationBar: _buildSummaryFooter(...)` (line 2288) — a proper
  fixed bottom slot, **not** an overlapping `Stack`/`Positioned` panel.
- `_buildSummaryFooter` (line 1104) wraps content in `GlassContainer(opacity: 0.1, blur: 20)`
  → semi-transparent footer (same `GlassContainer` issue as §4).
- The mic button is a `floatingActionButton` in a `Column` FAB stack (lines 2289–2319).
  Because it's a FAB (not absolutely positioned), it **does not straddle the panel edge** in the
  current code; it sits in the standard FAB region. The "straddles panel edge" report likely
  corresponds to an earlier version. We will keep the FAB fixed and ensure the panel is opaque
  so the chip row above remains visible.

## 7. Text field hint truncation

**Swept and CORRECTED.** A full-text search of `lib/` for the exact hints the brief calls out
("e.g., Primary B…", "Enter account n…", "e.g., HDFC0001…", "Ven…", "Pai…") finds **none of
them**. Specifically:

- There is **no "Link Bank Account" modal** in the UI layer. The only bank-related code is in
  the database/generated layer (`lib/core/database/app_database*.dart`), with no form UI.
- `lib/features/buy_flow` contains exactly **one** `hintText`: `"Type vendor name..."`
  (`buy_orders_screen.dart:302`), in a **full-width TextField** (not a narrow Row/SizedBox), so
  it does not truncate.
- Other buy-flow fields (`vendor_payouts_screen.dart`, `stock_entry_screen.dart`) use short
  `labelText` values ("Supplier Name", "Phone Number", "Amount (₹)") in full-width fields — no
  truncation risk.

**Conclusion:** the field-hint truncation in the brief is **not present in current source** — the
same situation as the ₹ "â‚¹" finding in §5c. The screens were likely removed/renamed since the
report. No fix warranted; flagged for device re-test rather than inventing fields that don't exist.

---

## Summary of confirmed root causes (to fix in Phase 1)

1. **No app-wide `textScaler` clamp** (`app.dart:127`). → Phase 1A
2. **KPI cards: 4-up fixed row on narrow widths + Text with no `maxLines`/`overflow`**. → Phase 1B
3. **`add_purchase_screen.dart` dark `palette.mutedGray` background** + DesktopContentContainer
   screens with no themed bg + hard-coded `Colors.white` cards. → Phase 1C
4. **`GlassContainer` (opacity 0.1 + blur) used as content surface** → Inventory "scrim",
   New Sale footer transparency, language picker merge. → Phase 1D
5. **Language picker sheet has no opaque background container.** → Phase 1D
6. **`localization_service.dart` mojibake in `nativeName` + `flag`** (source-file corruption). → Phase 1F
7. **Text field hints truncate** in vendor/payment/bank fields. → Phase 1E

## Hypotheses from the brief that were CORRECTED by code evidence

- "Inventory scrim stuck `true` after load" → no such boolean; the darkening is the translucent
  `GlassContainer`, a systemic widget issue (§4).
- "Revenue card ↗ badge escapes card via absolute positioning" → the `_KpiCard` badge is
  `Spacer()`-aligned in a `Row`, no `Positioned` (§2).
- "New Sale mic button straddles panel edge" → mic is a standard FAB, not absolutely positioned (§6).
- "â‚¹ on New PO total from a UTF-8 decode gap" → New PO source uses a clean `₹` literal (§5c).
  The genuine encoding corruption is `localization_service.dart` (§5b).
