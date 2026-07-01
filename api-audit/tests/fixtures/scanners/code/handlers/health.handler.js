/**
 * Fixture: Lambda handler documenting its routes in a doc comment.
 *
 * Exercises the code scanner's `METHOD /path` doc-comment route extraction
 * (Requirement 1.1). No Express registration is present here on purpose.
 *
 * GET /health
 * GET /health/deep
 */
exports.handler = async () => ({ statusCode: 200, body: 'ok' });
