/**
 * Fixture: Express-style REST route registrations.
 *
 * Exercises the code scanner's detection of `router.<method>('/path', ...)`
 * registrations (Requirement 1.1). Handlers are inline no-ops so the file is
 * self-contained.
 */
import { Router } from 'express';

const router = Router();
const noop = (_req: unknown, _res: unknown): void => undefined;

router.get('/customers', noop);
router.post('/customers', noop);
router.put('/customers/:id', noop);
router.delete('/customers/:id', noop);

export default router;
