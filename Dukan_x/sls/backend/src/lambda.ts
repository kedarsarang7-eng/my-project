// ============================================
// Lambda Entry Point — Express → Serverless
// ============================================
// Wraps the existing Express app for AWS Lambda + API Gateway.
// Uses serverless-http to translate API Gateway events into Express req/res.

import serverless from 'serverless-http';
import app from './app';

// Export the Lambda handler
export const handler = serverless(app, {
    // Strip the /api prefix that API Gateway adds via {proxy+}
    basePath: '',
    // Binary content types that should be base64 encoded
    binary: ['image/*', 'application/pdf', 'application/octet-stream'],
});
