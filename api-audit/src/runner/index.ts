/**
 * Test_Runner stage.
 *
 * Executes a Postman collection via Newman against the Local then AWS
 * environments and emits RunResult/RequestOutcome records
 * (Requirements 10, 11).
 */

export {
  NewmanTestRunner,
  runCollection,
  toNewmanCollection,
  toNewmanEnvironment,
  toRunResult,
} from './newman-runner';
export type {
  NewmanRunFn,
  NewmanRunnerOptions,
  TestRunner,
} from './newman-runner';
export { compareRuns } from './local-vs-aws';
