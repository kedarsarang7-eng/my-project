// ============================================================================
// Feature: openwa-whatsapp-automation
// Unit Test: Pilot config validation — all six pilot configs validate against
//            the AutomationConfig Zod schema with zero violations
// ----------------------------------------------------------------------------
// Validates: Requirements 1.6
//
// Requirement 1.6:
//   "THE WhatsApp_Automation_System SHALL validate the Grocery, Mobile Store,
//    Clinic, School ERP, Petrol Pump, and Jewellery pilot configurations
//    against the Automation_Config schema, and validation SHALL pass only when
//    all six configurations conform to the schema with zero schema violations."
// ============================================================================

import { automationConfigSchema } from '../../schemas/entities';
import {
  groceryConfig,
  mobileStoreConfig,
  clinicConfig,
  schoolErpConfig,
  petrolPumpConfig,
  jewelleryConfig,
  PILOT_CONFIGS,
} from '../../config/pilot-configs';

describe('Feature: openwa-whatsapp-automation', () => {
  describe('Pilot config validation [Validates: Requirements 1.6]', () => {
    it('should have exactly 6 pilot configs', () => {
      expect(PILOT_CONFIGS).toHaveLength(6);
    });

    it('Grocery config validates against AutomationConfig schema with zero violations', () => {
      const result = automationConfigSchema.safeParse(groceryConfig);
      expect(result.success).toBe(true);
      if (!result.success) {
        fail(`Grocery config schema violations: ${JSON.stringify(result.error.issues)}`);
      }
    });

    it('Mobile Store config validates against AutomationConfig schema with zero violations', () => {
      const result = automationConfigSchema.safeParse(mobileStoreConfig);
      expect(result.success).toBe(true);
      if (!result.success) {
        fail(`Mobile Store config schema violations: ${JSON.stringify(result.error.issues)}`);
      }
    });

    it('Clinic config validates against AutomationConfig schema with zero violations', () => {
      const result = automationConfigSchema.safeParse(clinicConfig);
      expect(result.success).toBe(true);
      if (!result.success) {
        fail(`Clinic config schema violations: ${JSON.stringify(result.error.issues)}`);
      }
    });

    it('School ERP config validates against AutomationConfig schema with zero violations', () => {
      const result = automationConfigSchema.safeParse(schoolErpConfig);
      expect(result.success).toBe(true);
      if (!result.success) {
        fail(`School ERP config schema violations: ${JSON.stringify(result.error.issues)}`);
      }
    });

    it('Petrol Pump config validates against AutomationConfig schema with zero violations', () => {
      const result = automationConfigSchema.safeParse(petrolPumpConfig);
      expect(result.success).toBe(true);
      if (!result.success) {
        fail(`Petrol Pump config schema violations: ${JSON.stringify(result.error.issues)}`);
      }
    });

    it('Jewellery config validates against AutomationConfig schema with zero violations', () => {
      const result = automationConfigSchema.safeParse(jewelleryConfig);
      expect(result.success).toBe(true);
      if (!result.success) {
        fail(`Jewellery config schema violations: ${JSON.stringify(result.error.issues)}`);
      }
    });

    it('all six pilot configs validate against the schema (aggregate check)', () => {
      const results = PILOT_CONFIGS.map((config) => ({
        businessType: config.businessType,
        result: automationConfigSchema.safeParse(config),
      }));

      const failures = results.filter((r) => !r.result.success);
      expect(failures).toHaveLength(0);
    });
  });
});
