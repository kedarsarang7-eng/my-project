// ============================================
// Customer Auth Middleware — DEPRECATED (Firebase removed)
// ============================================
// Firebase Auth has been fully replaced by Amazon Cognito.
// This file now re-exports from cognitoCustomerAuth.ts for backward compatibility.
//
// All controllers already import directly from cognitoCustomerAuth.ts.
// This stub exists only to prevent import errors if any legacy code references it.
//
// SAFE TO DELETE once confirmed no references remain.
// ============================================

export {
    requireCognitoCustomerAuth as requireCustomerAuth,
    optionalCognitoCustomerAuth as optionalCustomerAuth,
    CognitoCustomerIdentity as CustomerIdentity,
} from './cognitoCustomerAuth';
