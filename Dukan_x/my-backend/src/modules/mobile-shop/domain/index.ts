/**
 * Domain Module — Public Exports
 *
 * Pure domain logic for IMEI unit lifecycle management.
 * No persistence, no DynamoDB — only state machines and validation.
 */

export {
  DeviceLifecycleState,
  ALLOWED_TRANSITIONS,
  LifecycleErrorCode,
  validateTransition,
  isTerminalState,
  getAllowedTargets,
} from './device-lifecycle';

export type {
  TransitionCommand,
  DeviceLifecycleEvent,
  LifecycleError,
  TransitionableUnit,
  Result,
} from './device-lifecycle';

export {
  DeviceCondition,
  OwnershipSource,
  CURRENT_IMEI_UNIT_DATA_MODEL_VERSION,
  createImeiUnit,
  applyTransition,
} from './imei-unit';

export type {
  ImeiUnit,
  CreateImeiUnitParams,
} from './imei-unit';

export {
  validateWarrantyMonths,
  calculateWarrantyEndDate,
  validateWarrantyRegistration,
  getDaysInMonth,
} from './warranty-validator';

export type {
  WarrantyValidationErrorCode,
  WarrantyValidationError,
  WarrantyRegistrationParams,
  ValidatedWarrantyRegistration,
} from './warranty-validator';

export {
  validateMoney,
  validateSalePrice,
} from './monetary-validator';

export type {
  Money,
  MonetaryValidationErrorCode,
  MonetaryValidationError,
  SalePriceParams,
  ValidatedSalePrice,
  SalePriceValidationResult,
} from './monetary-validator';
