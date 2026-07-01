// Firestore Rules Security Test
// Usage: Run with Firebase Emulator Suite
// > firebase emulators:start
// > jest test/security/firestore.rules.test.js

const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const fs = require('fs');

const PROJECT_ID = 'dukan-x-test';

describe('Firestore Security Rules', () => {
    let testEnv;

    beforeAll(async () => {
        testEnv = await initializeTestEnvironment({
            projectId: PROJECT_ID,
            firestore: {
                rules: fs.readFileSync('../../firestore.rules', 'utf8'),
            },
        });
    });

    afterAll(async () => {
        await testEnv.cleanup();
    });

    // ==========================================================
    // 1. ADMIN USERS (RBAC)
    // ==========================================================

    it('prevents public access to admin_users', async () => {
        const db = testEnv.authenticatedContext('user_alice').firestore();
        await assertFails(db.collection('admin_users').doc('admin_bob').get());
    });

    it('allows owner to read their own admin entry', async () => {
        const db = testEnv.authenticatedContext('admin_bob').firestore();
        await assertSucceeds(db.collection('admin_users').doc('admin_bob').get());
    });

    // ==========================================================
    // 2. LICENSES
    // ==========================================================

    it('prevents public reading of licenses', async () => {
        const db = testEnv.unauthenticatedContext().firestore();
        await assertFails(db.collection('licenses').doc('some_license').get());
    });

    it('allows user to read their own license', async () => {
        const db = testEnv.authenticatedContext('cust_123').firestore();
        const licenseRef = db.collection('licenses').doc('lic_123');
        // Setup data where customerId == cust_123
        await testEnv.withSecurityRulesDisabled(async (context) => {
            await context.firestore().collection('licenses').doc('lic_123').set({
                customerId: 'cust_123',
                status: 'active'
            });
        });
        await assertSucceeds(licenseRef.get());
    });

    it('prevents users from writing valid licenses', async () => {
        const db = testEnv.authenticatedContext('hacker_joe').firestore();
        await assertFails(db.collection('licenses').doc('new_lic').set({
            status: 'active',
            expiryDate: '2099-01-01'
        }));
    });

    // ==========================================================
    // 3. DEVICES
    // ==========================================================

    it('prevents direct device binding by users (must use Cloud Function)', async () => {
        const db = testEnv.authenticatedContext('user_1').firestore();
        await assertFails(db.collection('devices').add({
            licenseKey: 'hack'
        }));
    });

});
