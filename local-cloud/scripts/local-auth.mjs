// =============================================================================
// Local Auth — JWT Token Generator for Local Development
// =============================================================================
// Simulates Cognito auth locally using jose (JWT) library.
// Generates tokens with the SAME claim structure as your production Cognito.
//
// Usage:
//   node local-cloud/scripts/local-auth.mjs token
//   node local-cloud/scripts/local-auth.mjs signup admin@test.com Test@1234
//   node local-cloud/scripts/local-auth.mjs login admin@test.com Test@1234
// =============================================================================

import { SignJWT, generateKeyPair, exportJWK } from 'jose';
import { randomUUID } from 'crypto';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const KEYS_DIR = join(__dirname, '..', '.keys');
const KEYS_FILE = join(KEYS_DIR, 'local-jwk.json');

// ─── Key Management ───────────────────────────────────────────────────

async function getOrCreateKeyPair() {
  if (existsSync(KEYS_FILE)) {
    const stored = JSON.parse(readFileSync(KEYS_FILE, 'utf-8'));
    // Import from stored JWK
    const { importJWK } = await import('jose');
    const privateKey = await importJWK(stored.privateKey, 'RS256');
    return { privateKey, kid: stored.kid };
  }

  // Generate new RSA key pair
  const { privateKey, publicKey } = await generateKeyPair('RS256');
  const kid = randomUUID();

  // Export and store
  const privateJwk = await exportJWK(privateKey);
  const publicJwk = await exportJWK(publicKey);

  if (!existsSync(KEYS_DIR)) mkdirSync(KEYS_DIR, { recursive: true });

  writeFileSync(KEYS_FILE, JSON.stringify({
    kid,
    privateKey: { ...privateJwk, kid },
    publicKey: { ...publicJwk, kid },
  }, null, 2));

  // Write JWKS endpoint file for local verification
  writeFileSync(join(KEYS_DIR, 'jwks.json'), JSON.stringify({
    keys: [{ ...publicJwk, kid, use: 'sig', alg: 'RS256' }],
  }, null, 2));

  console.log('  Generated new RSA key pair for local JWT signing');
  console.log(`  JWKS: ${join(KEYS_DIR, 'jwks.json')}`);

  return { privateKey, kid };
}

// ─── Token Generation ─────────────────────────────────────────────────

async function generateToken(claims = {}) {
  const { privateKey, kid } = await getOrCreateKeyPair();

  const defaults = {
    sub: claims.sub || randomUUID(),
    email: claims.email || 'admin@dukan-test.local',
    'custom:tenantId': claims.tenantId || 'tenant-001',
    'custom:role': claims.role || 'superadmin',
    'custom:plan': claims.plan || 'premium',
    'cognito:username': claims.email || 'admin@dukan-test.local',
    token_use: 'access',
    scope: 'aws.cognito.signin.user.admin',
    auth_time: Math.floor(Date.now() / 1000),
    // Client ID matches template.yaml
    client_id: claims.clientId || 'local-app-client-id',
  };

  const token = await new SignJWT(defaults)
    .setProtectedHeader({ alg: 'RS256', kid })
    .setIssuedAt()
    .setExpirationTime(claims.expiresIn || '24h')
    .setIssuer('http://localhost:4566/local-cognito')
    .setAudience(claims.clientId || 'local-app-client-id')
    .setJti(randomUUID())
    .sign(privateKey);

  return { token, claims: defaults };
}

// ─── User Simulation ──────────────────────────────────────────────────

const TEST_USERS = {
  'admin@dukan-test.local': {
    password: 'Test@1234',
    tenantId: 'tenant-001',
    role: 'superadmin',
    plan: 'premium',
    name: 'Rajesh Sharma',
  },
  'staff@dukan-test.local': {
    password: 'Test@1234',
    tenantId: 'tenant-001',
    role: 'staff',
    plan: 'premium',
    name: 'Priya Verma',
  },
  'admin@patel-fuel.local': {
    password: 'Test@1234',
    tenantId: 'tenant-002',
    role: 'admin',
    plan: 'pro',
    name: 'Amit Patel',
  },
};

async function signup(email, password) {
  if (!email || !password) {
    console.error('Usage: local-auth.mjs signup <email> <password>');
    process.exit(1);
  }

  if (password.length < 8) {
    console.error('Password must be at least 8 characters');
    process.exit(1);
  }

  // Store user (in real app, would write to LocalStack Cognito)
  TEST_USERS[email] = {
    password,
    tenantId: `tenant-${randomUUID().slice(0, 8)}`,
    role: 'admin',
    plan: 'basic',
    name: email.split('@')[0],
  };

  console.log(`✓ User created: ${email}`);
  console.log(`  Tenant ID: ${TEST_USERS[email].tenantId}`);
  console.log(`  Role: ${TEST_USERS[email].role}`);

  // Auto-generate token
  const { token } = await generateToken({
    email,
    tenantId: TEST_USERS[email].tenantId,
    role: TEST_USERS[email].role,
    plan: TEST_USERS[email].plan,
  });

  console.log(`\n  Access Token:\n  ${token}`);
}

async function login(email, password) {
  const user = TEST_USERS[email];
  if (!user) {
    console.error(`User not found: ${email}`);
    console.error('Available test users:');
    Object.keys(TEST_USERS).forEach((e) => console.error(`  - ${e} / ${TEST_USERS[e].password}`));
    process.exit(1);
  }

  if (user.password !== password) {
    console.error('Invalid password');
    process.exit(1);
  }

  const { token, claims } = await generateToken({
    email,
    tenantId: user.tenantId,
    role: user.role,
    plan: user.plan,
  });

  console.log('✓ Login successful');
  console.log(`  Email:     ${email}`);
  console.log(`  Tenant:    ${user.tenantId}`);
  console.log(`  Role:      ${user.role}`);
  console.log(`  Plan:      ${user.plan}`);
  console.log(`\n  Access Token:\n  ${token}`);
  console.log(`\n  Use in requests:\n  Authorization: Bearer ${token}`);
}

// ─── CLI Dispatch ─────────────────────────────────────────────────────

const [,, command, ...args] = process.argv;

switch (command) {
  case 'token': {
    const { token, claims } = await generateToken();
    console.log('━━━ Local JWT Token ━━━');
    console.log(`\n  Token:\n  ${token}`);
    console.log(`\n  Claims:`);
    console.log(`    sub:      ${claims.sub}`);
    console.log(`    email:    ${claims.email}`);
    console.log(`    tenantId: ${claims['custom:tenantId']}`);
    console.log(`    role:     ${claims['custom:role']}`);
    console.log(`    plan:     ${claims['custom:plan']}`);
    break;
  }
  case 'signup':
    await signup(args[0], args[1]);
    break;
  case 'login':
    await login(args[0], args[1]);
    break;
  default:
    console.log('Usage: local-auth.mjs <token|signup|login> [args...]');
    console.log('  token                       - Generate test JWT');
    console.log('  signup <email> <password>    - Create test user');
    console.log('  login <email> <password>     - Login and get token');
    console.log('\nTest users:');
    Object.entries(TEST_USERS).forEach(([e, u]) =>
      console.log(`  ${e} / ${u.password} (${u.role}@${u.tenantId})`)
    );
}
