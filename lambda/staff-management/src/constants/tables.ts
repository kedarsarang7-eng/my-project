// ============================================================================
// DYNAMODB TABLE CONSTANTS
// ============================================================================

export const TABLES = {
  STAFF_PROFILES: process.env.STAFF_TABLE || 'PetrolStaffProfiles',
  STAFF_ACTIVITY_LOG: process.env.ACTIVITY_LOG_TABLE || 'PetrolStaffActivityLog',
  WEBSOCKET_CONNECTIONS: process.env.WEBSOCKET_TABLE || 'PetrolWebSocketConnections',
  STAFF_ID_COUNTER: process.env.STAFF_ID_COUNTER_TABLE || 'PetrolStaffIdCounter'
} as const;

export const INDEXES = {
  // StaffProfiles GSIs
  GSI1: 'petrolPumpId-role-index', // Query by pump + role
  GSI2: 'petrolPumpId-active-index', // Query by pump + active status
  GSI3: 'cognitoUserId-index' // Lookup by Cognito ID
} as const;

export const COGNITO = {
  USER_POOL_ID: process.env.USER_POOL_ID || '',
  CLIENT_ID: process.env.COGNITO_CLIENT_ID || ''
} as const;
