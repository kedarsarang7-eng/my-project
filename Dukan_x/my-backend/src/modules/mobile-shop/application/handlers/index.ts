/**
 * MobileShop Application Handlers — Barrel Export
 *
 * Focused single-responsibility handlers for device inventory,
 * second-hand intake, reservations, demo units, returns,
 * service jobs, exchanges, and warranties.
 * All follow the pattern: idempotency → validate → plan → execute → map outcome.
 *
 * Requirements: 4.1–4.7, 5.1–5.8, 8.12
 */

// Device Inventory
export {
  createImeiUnitHandler,
  updateImeiUnitHandler,
  listImeiUnitsHandler,
  type CreateImeiUnitHandlerParams,
  type UpdateImeiUnitHandlerParams,
  type ListImeiUnitsFilters,
  type HandlerOutcome,
  type HandlerDependencies,
} from './device-inventory.handler';

// Second-Hand Intake
export {
  createIntakeHandler,
  type CreateIntakeParams,
  type IntakeHandlerDependencies,
  type IntakeOutcome,
} from './second-hand-intake.handler';

// Reservation
export {
  createReservationHandler,
  releaseReservationHandler,
  type CreateReservationParams,
  type ReleaseReservationParams,
  type ReservationHandlerDependencies,
  type ReservationOutcome,
} from './reservation.handler';

// Demo Unit
export {
  assignDemoHandler,
  returnFromDemoHandler,
  type AssignDemoParams,
  type ReturnFromDemoParams,
  type DemoHandlerDependencies,
  type DemoOutcome,
} from './demo-unit.handler';

// Device Return
export {
  processReturnHandler,
  type ProcessReturnParams,
  type ReturnDisposition,
  type ReturnHandlerDependencies,
  type ReturnOutcome,
} from './device-return.handler';

// Service Job
export {
  createServiceJob,
  updateServiceJobStatus,
  listServiceJobs,
  type CreateServiceJobParams,
  type UpdateServiceJobStatusParams,
  type ListServiceJobsFilters,
  type ServiceJobOutcome,
  type ServiceJobHandlerDeps,
} from './service-job.handler';

// Exchange
export {
  createExchange,
  listExchanges,
  type CreateExchangeParams,
  type ListExchangesFilters,
  type ExchangeOutcome,
  type ExchangeHandlerDeps,
} from './exchange.handler';

// Warranty
export {
  registerWarranty,
  fileWarrantyClaim,
  resolveWarrantyClaim,
  listWarranties,
  type RegisterWarrantyParams,
  type FileWarrantyClaimParams,
  type ResolveWarrantyClaimParams,
  type ListWarrantiesFilters,
  type WarrantyOutcome,
  type WarrantyClaimOutcome,
  type WarrantyHandlerDeps,
} from './warranty.handler';
