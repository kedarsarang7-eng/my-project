# Decision: Widen BusinessGuard Allow-Lists vs. Relocate Screens

**Date:** 2025-07-13

## Decision

**Widen** the existing `BusinessGuard` allow-lists for `/computer-shop/warranty`, `/computer-shop/serial-history`, and `/computer-shop/job-card/*` to include `BusinessType.mobileShop`, rather than relocating the screens out of `features/computer_shop/`.

## Alternatives Considered

1. **Widen the allow-lists (chosen):** Add `BusinessType.mobileShop` to the `allowedTypes` array in each route's `BusinessGuard`. No file moves, no import-path changes, no effect on computerShop or electronics.
2. **Relocate the screens to a shared `features/device_service/` location:** Move `WarrantyScreen`, `SerialHistoryScreen`, and `JobCardDetailScreen` out of `features/computer_shop/` into a new shared folder, update all import paths and route registrations across `Shared_Device_Verticals`.

## Rationale

Widening is the minimum, reversible, additive edit that satisfies the scope boundary (Requirement 2.1 access-widening clause) and avoids touching computerShop/electronics import paths or screen internals. A relocation would ripple across the `Shared_Device_Verticals` — requiring import updates in every file that references these screens, route-path changes, and test adjustments — all of which exceed the surgical scope defined for this remediation. Relocation is deferred unless a later need arises (e.g., a fourth vertical requiring these screens).
