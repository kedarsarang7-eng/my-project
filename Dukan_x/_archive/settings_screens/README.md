# Archived Settings Screens

Moved here (NOT deleted) as part of **Phase 5 — Settings Redesign**.

## settings_screen_STUB.dart
- **Original path:** `lib/features/settings/presentation/screens/settings_screen.dart`
- **Archived:** 2026-06-18
- **Reason:** 55-line "compile-safe" skeleton that the `/settings` route used to
  point at. It exposed only 2 items (Printer Settings + Startup Sound) while the
  real 1876-line hub (`main_settings_screen.dart`, also declaring
  `class SettingsScreen`) was unreachable on mobile/tablet. Phase 5 re-pointed
  `/settings` at the real hub, leaving this stub with **zero importers**.
- **Confidence:** High — after the route swap, `grep -rln
  "presentation/screens/settings_screen.dart" lib` returned nothing.
- **Restore:** `git`-untracked; move back manually if needed.
