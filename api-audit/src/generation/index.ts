/**
 * Collection_Generator and Test_Generator stages.
 *
 * Emits a Postman v2.1 collection organized by domain folders plus the five
 * Postman environments, and attaches positive, negative, schema, auth,
 * validation, and business-rule test scripts (Requirements 3, 4, 5, 6).
 */

export {
  BASE_URL_VARIABLE,
  CollectionGenerationError,
  CollectionGenerator,
  DefaultCollectionGenerator,
  buildCollection,
  buildRequest,
  findNonRepresentableReason,
  generateCollection,
  resolveDomain,
} from './collection-generator';

export {
  DEFAULT_RESPONSE_TIME_THRESHOLD_MS,
  DefaultTestGenerator,
  TestGenerator,
  TestGeneratorOptions,
  attachTests,
  buildAuthTest,
  buildAuthTests,
  buildAuthzTest,
  buildBaselineTests,
  buildBusinessRuleTest,
  buildMetadataTests,
  buildResponseTimeTest,
  buildSchemaTest,
  buildStatusTest,
  buildValidationTest,
} from './test-generator';
