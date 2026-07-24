/**
 * IMEI Unit — Domain Model
 *
 * Pure domain model for a tenant-scoped IMEI unit with lifecycle state,
 * version, condition, ownership, valuation, warranty, and associations.
 * Provides a factory for initial creation and an event-based state transition.
 *
 * Requirements: 3.5–3.6, 3.10–3.11, 4.1, 4.5–4.7, 4.9, 5.2–5.4
 */

import type { Money, EvidenceReference } from '../schemas/common.schema';
import { DeviceLifecycleState, type DeviceLifecycleEvent } from './device-lifecycle';

// ─── Device Condition ────────────────────────────────────────────────────────

export enum DeviceCondition {
  NEW = 'NEW',
  LIKE_NEW = 'LIKE_NEW',
  GOOD = 'GOOD',
  FAIR = 'FAIR',
  POOR = 'POOR',
  DAMAGED = 'DAMAGED',
}

// ─── Ownership Source ────────────────────────────────────────────────────────

export enum OwnershipSource {
  PURCHASED_NEW = 'PURCHASED_NEW',
  SECOND_HAND_INTAKE = 'SECOND_HAND_INTAKE',
  EXCHANGE_IN = 'EXCHANGE_IN',
  RETURN = 'RETURN',
  DEMO_ALLOCATION = 'DEMO_ALLOCATION',
  TRANSFER = 'TRANSFER',
}

// ─── IMEI Unit Domain Model ──────────────────────────────────────────────────

/**
 * Immutable domain representation of a tenant-scoped IMEI unit.
 * Mutations produce a new instance via `applyTransition`.
 */
export interface ImeiUnit {
  readonly tenantId: string;
  readonly entityId: string;
  readonly version: number;
  readonly dataModelVersion: number;
  readonly imei: string;
  readonly lifecycleState: DeviceLifecycleState;
  readonly condition: DeviceCondition;
  readonly ownershipSource: OwnershipSource;
  readonly brand: string;
  readonly model: string;
  readonly color?: string;
  readonly storage?: string;

  // Valuation
  readonly acquisitionCost: Money;
  readonly salePrice: Money;
  readonly marketValuation?: Money;

  // Warranty
  readonly warrantyStartDate?: string;
  readonly warrantyEndDate?: string;
  readonly warrantyProvider?: string;

  // Associations
  readonly customerId?: string;
  readonly saleInvoiceId?: string;
  readonly soldAt?: string;
  readonly supplierId?: string;
  readonly exchangeId?: string;
  readonly intakeId?: string;

  // Evidence
  readonly evidenceRefs?: readonly EvidenceReference[];

  // Timestamps
  readonly createdAt: string;
  readonly updatedAt: string;
}

// ─── Factory Parameters ──────────────────────────────────────────────────────

/**
 * Parameters for creating a new IMEI unit.
 * Initial state is either IN_STOCK (new devices) or SECOND_HAND (used intake).
 */
export interface CreateImeiUnitParams {
  readonly tenantId: string;
  readonly entityId: string;
  readonly imei: string;
  readonly condition: DeviceCondition;
  readonly ownershipSource: OwnershipSource;
  readonly brand: string;
  readonly model: string;
  readonly color?: string;
  readonly storage?: string;
  readonly acquisitionCost: Money;
  readonly salePrice: Money;
  readonly marketValuation?: Money;
  readonly warrantyStartDate?: string;
  readonly warrantyEndDate?: string;
  readonly warrantyProvider?: string;
  readonly supplierId?: string;
  readonly exchangeId?: string;
  readonly intakeId?: string;
  readonly evidenceRefs?: readonly EvidenceReference[];
  /** Whether this is a second-hand intake (initial state: SECOND_HAND) */
  readonly isSecondHand?: boolean;
  readonly dataModelVersion?: number;
}

// ─── Current Data Model Version ──────────────────────────────────────────────

export const CURRENT_IMEI_UNIT_DATA_MODEL_VERSION = 1;

// ─── Factory ─────────────────────────────────────────────────────────────────

/**
 * Creates a new IMEI unit with initial state.
 * - New devices start as IN_STOCK
 * - Second-hand intake devices start as SECOND_HAND
 */
export function createImeiUnit(params: CreateImeiUnitParams): ImeiUnit {
  const now = new Date().toISOString();
  const initialState = params.isSecondHand
    ? DeviceLifecycleState.SECOND_HAND
    : DeviceLifecycleState.IN_STOCK;

  return {
    tenantId: params.tenantId,
    entityId: params.entityId,
    version: 1,
    dataModelVersion: params.dataModelVersion ?? CURRENT_IMEI_UNIT_DATA_MODEL_VERSION,
    imei: params.imei,
    lifecycleState: initialState,
    condition: params.condition,
    ownershipSource: params.ownershipSource,
    brand: params.brand,
    model: params.model,
    color: params.color,
    storage: params.storage,
    acquisitionCost: params.acquisitionCost,
    salePrice: params.salePrice,
    marketValuation: params.marketValuation,
    warrantyStartDate: params.warrantyStartDate,
    warrantyEndDate: params.warrantyEndDate,
    warrantyProvider: params.warrantyProvider,
    supplierId: params.supplierId,
    exchangeId: params.exchangeId,
    intakeId: params.intakeId,
    evidenceRefs: params.evidenceRefs,
    createdAt: now,
    updatedAt: now,
  };
}

// ─── Apply Transition ────────────────────────────────────────────────────────

/**
 * Applies a validated lifecycle event to an IMEI unit, producing a new
 * immutable version with updated state and version number.
 *
 * This function does NOT validate the transition — that responsibility
 * belongs to `validateTransition` in device-lifecycle.ts. This function
 * assumes the event has already been validated.
 */
export function applyTransition(
  unit: ImeiUnit,
  event: DeviceLifecycleEvent,
): ImeiUnit {
  return {
    ...unit,
    lifecycleState: event.newState,
    version: event.newVersion,
    updatedAt: event.occurredAt,
  };
}
