# Decision: Sales-Return Capability for mobileShop

**Date:** 2025-07-14

## Decision

**GRANT** the IMEI-aware return flow (`useSalesReturn`) for mobileShop.

## Alternatives Considered

1. **Grant an IMEI-aware return flow (chosen):** Enable `useSalesReturn` for mobileShop, providing a return path that reverts an `IMEISerial` status from `sold` back to a returnable state (`inStock`/`returned`), scoped by tenant.
2. **Remain without sales-return:** Leave mobileShop without any return flow, requiring merchants to manually edit serial records or work around the absence of a structured return process.

## Rationale

Mobile phone shops need to process returns of sold devices, and the IMEI-tracked inventory model (status transitions: sold → inStock/returned) already supports this; granting the return flow provides a complete sales lifecycle for IMEI-tracked units and avoids merchants needing to manually modify serial records. The return operation is naturally tenant-scoped (only the owning tenant can revert a sale), aligns with the existing `IMEISerialStatus` states, and closes a gap that would otherwise force merchants into error-prone manual corrections for legitimate customer returns.

## Requirements Covered

- Requirement 11.3: Record a documented decision resolving `useSalesReturn` for mobileShop.
- Requirement 11.4–11.6: Implementation of the IMEI-aware return flow (task 17.3).
