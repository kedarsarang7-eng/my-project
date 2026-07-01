# Decision: EMI/Finance Scope — Deferred-Backlog

**Date:** 2025-07-13

## Decision

EMI/finance is **deferred-backlog** — no EMI code will be implemented as part of this remediation.

## Alternatives Considered

1. **Defer to backlog (chosen):** Leave all EMI-related files (`Mobile_Shop_Module` nav-item "EMI", `Mobile_Shop_Routes` `/mobile/emi` stub) unmodified. No EMI logic, screen, or endpoint is created, altered, or wired during this remediation.
2. **Implement EMI/finance in-scope:** Build an EMI calculator, tenure selection, and ledger integration as part of Phase 6.

## Rationale

The scope boundary (Requirement 2.5) explicitly requires confirmation before any EMI code change, and no such confirmation has been received. Implementing EMI without that confirmation would violate the non-negotiable scope boundary and risk introducing financial logic that has not been reviewed or approved by the product owner. The existing EMI-related files (the `Mobile_Shop_Module` nav-item referencing "EMI" and the `Mobile_Shop_Routes` `/mobile/emi` legacy redirect stub) remain unmodified. EMI/finance is recorded as a backlog item for future implementation pending an explicit product decision and the Requirement 2.5 confirmation.

## Requirements Covered

- **Requirement 9.9:** An explicit decision records EMI/finance as in-scope or deferred-backlog with a one-sentence rationale.
- **Requirement 2.5:** No EMI code change without explicit confirmation.
