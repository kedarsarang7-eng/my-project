/**
 * DUKANX ENTERPRISE LICENSING CLOUD FUNCTIONS
 * Handles license validation, activation, and management.
 * 
 * deployment: firebase deploy --only functions:licensing
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();

// ============================================================================
// HELPER: Generate Secure Hash (Device Fingerprint + Secret)
// ============================================================================
const generateValidationToken = (licenseKey, deviceFingerprint) => {
    // In production, use a secret stored in Google Secret Manager
    const secret = process.env.LICENSE_SECRET || 'dukanx_enterprise_secret_2026';
    return crypto.createHmac('sha256', secret)
        .update(`${licenseKey}:${deviceFingerprint}:${new Date().toISOString().split('T')[0]}`)
        .digest('hex');
};

// ============================================================================
// HELPER: Security Audit Log
// ============================================================================
const logSecurityEvent = (event, context, status, details = {}) => {
    // Attempt to get IP from rawRequest if available (onCall)
    const ip = context.rawRequest ? (context.rawRequest.headers['x-forwarded-for'] || context.rawRequest.socket.remoteAddress) : 'unknown';
    const uid = context.auth ? context.auth.uid : 'unauthenticated';

    console.log(JSON.stringify({
        event: event,
        timestamp: new Date().toISOString(),
        ip: ip,
        uid: uid,
        status: status,
        details: details
    }));
};

// ============================================================================
// 1. ACTIVATE LICENSE (User App)
// ============================================================================
// Called when user first enters license key on a device.
// Input: { licenseKey, deviceFingerprint, platform, businessType, deviceName }
exports.activateLicense = functions.https.onCall(async (data, context) => {
    // 1. Validate Input
    const { licenseKey, deviceFingerprint, platform, businessType, deviceName } = data;
    logSecurityEvent('activateLicense_attempt', context, 'pending', { licenseKey });

    if (!licenseKey || !deviceFingerprint || !platform || !businessType) {
        logSecurityEvent('activateLicense_fail', context, 'invalid_input', { missingFields: true });
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }

    // 2. Validate Auth (Optional: Can be unauthenticated for initial setup? check requirements. 
    // Usually user must be logged in to Firebase Auth at least anonymously or as a user.)
    // Let's enforce auth for security.
    if (!context.auth) {
        logSecurityEvent('activateLicense_fail', context, 'unauthenticated');
        throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
    }
    const userId = context.auth.uid;

    const licenseRef = db.collection('licenses').where('licenseKey', '==', licenseKey).limit(1);

    return db.runTransaction(async (t) => {
        // 3. Fetch License
        const licenseSnap = await t.get(licenseRef);
        if (licenseSnap.empty) {
            logSecurityEvent('activateLicense_fail', context, 'not_found', { licenseKey });
            throw new functions.https.HttpsError('not-found', 'License key not found');
        }
        const licenseDoc = licenseSnap.docs[0];
        const licenseData = licenseDoc.data();
        const licenseId = licenseDoc.id;

        // 4. Validate License State
        if (licenseData.status === 'blocked' || licenseData.status === 'suspended') {
            logSecurityEvent('activateLicense_fail', context, 'denied', { reason: 'License blocked' });
            throw new functions.https.HttpsError('permission-denied', 'License is blocked or suspended');
        }

        if (licenseData.status === 'expired') {
            // Allow activation if extended? No, must be active/inactive.
            // If expiry date is past, throw error.
            const expiry = new Date(licenseData.expiryDate);
            if (expiry < new Date()) {
                logSecurityEvent('activateLicense_fail', context, 'expired', { expiryDate: licenseData.expiryDate });
                throw new functions.https.HttpsError('failed-precondition', 'License has expired');
            }
        }

        // 5. Validate Business Type
        if (licenseData.businessType !== businessType) {
            logSecurityEvent('activateLicense_fail', context, 'mismatch', { expected: licenseData.businessType, got: businessType });
            throw new functions.https.HttpsError('failed-precondition', `License invalid for ${businessType}`);
        }

        // 6. Check Device Limit
        const devicesRef = db.collection('devices');
        const existingDeviceSnap = await devicesRef
            .where('licenseId', '==', licenseId)
            .get(); // Need to count active devices

        let currentDeviceCount = 0;
        let isAlreadyBound = false;

        existingDeviceSnap.forEach(doc => {
            const d = doc.data();
            if (d.status === 'active') currentDeviceCount++;
            if (d.deviceFingerprint === deviceFingerprint) isAlreadyBound = true;
        });

        if (isAlreadyBound) {
            logSecurityEvent('activateLicense_success', context, 'already_bound', { licenseId });
            // Already active on this device, just return success + token
            return {
                status: 'active',
                message: 'License already active on this device',
                licenseId: licenseId,
                expiryDate: licenseData.expiryDate,
                features: licenseData.enabledModules || [], // send back enabled modules
                validationToken: generateValidationToken(licenseKey, deviceFingerprint)
            };
        }

        if (currentDeviceCount >= licenseData.maxDevices) {
            logSecurityEvent('activateLicense_fail', context, 'limit_reached', { current: currentDeviceCount, max: licenseData.maxDevices });
            throw new functions.https.HttpsError('resource-exhausted', 'Max device limit reached for this license');
        }

        // 7. Bind New Device
        const newDeviceRef = devicesRef.doc();
        t.set(newDeviceRef, {
            licenseId: licenseId,
            deviceFingerprint: deviceFingerprint,
            deviceName: deviceName || 'Unknown Device',
            platform: platform,
            status: 'active',
            boundAt: new Date().toISOString(),
            lastSeenAt: new Date().toISOString(),
            boundByUserId: userId,
            created_at: admin.firestore.FieldValue.serverTimestamp(),
            updated_at: admin.firestore.FieldValue.serverTimestamp()
        });

        // 8. Update License Status (if first activation)
        if (licenseData.status === 'inactive') {
            t.update(licenseDoc.ref, {
                status: 'active',
                activatedAt: new Date().toISOString(),
                updated_at: admin.firestore.FieldValue.serverTimestamp()
            });
        }

        // 9. Audit Log
        const logRef = db.collection('activation_logs').doc();
        t.set(logRef, {
            license_id: licenseId,
            action: 'activation',
            status: 'success',
            license_key: licenseKey,
            device_fingerprint: deviceFingerprint,
            user_id: userId,
            ip: context.rawRequest ? (context.rawRequest.headers['x-forwarded-for'] || context.rawRequest.socket.remoteAddress) : 'unknown',
            created_at: new Date().toISOString()
        });

        logSecurityEvent('activateLicense_success', context, 'activated', { licenseId });

        return {
            status: 'active',
            message: 'License activated successfully',
            licenseId: licenseId,
            expiryDate: licenseData.expiryDate,
            features: licenseData.enabledModules || [],
            validationToken: generateValidationToken(licenseKey, deviceFingerprint)
        };
    });
});

// ============================================================================
// 2. VALIDATE LICENSE (Heartbeat / Startup)
// ============================================================================
// Input: { licenseKey, deviceFingerprint }
exports.validateLicense = functions.https.onCall(async (data, context) => {
    const { licenseKey, deviceFingerprint } = data;

    if (!licenseKey || !deviceFingerprint) {
        logSecurityEvent('validateLicense_fail', context, 'invalid_input');
        throw new functions.https.HttpsError('invalid-argument', 'Missing fields');
    }

    // Identify license
    const snap = await db.collection('licenses').where('licenseKey', '==', licenseKey).limit(1).get();
    if (snap.empty) {
        // High frequency log, maybe sample? For now log all failures.
        logSecurityEvent('validateLicense_fail', context, 'not_found', { licenseKey });
        return { status: 'invalid', message: 'License key not found' };
    }
    const licenseDoc = snap.docs[0];
    const license = licenseDoc.data();

    // Check Status
    if (license.status !== 'active') {
        logSecurityEvent('validateLicense_fail', context, 'inactive_status', { status: license.status });
        return { status: license.status, message: `License is ${license.status}` };
    }

    // Check Expiry
    if (new Date(license.expiryDate) < new Date()) {
        // Auto-expire if needed
        await licenseDoc.ref.update({ status: 'expired' });
        logSecurityEvent('validateLicense_fail', context, 'expired', { expiryDate: license.expiryDate });
        return { status: 'expired', message: 'License has expired' };
    }

    // Check Device Binding
    const deviceSnap = await db.collection('devices')
        .where('licenseId', '==', licenseDoc.id)
        .where('deviceFingerprint', '==', deviceFingerprint)
        .limit(1)
        .get();

    if (deviceSnap.empty) {
        logSecurityEvent('validateLicense_fail', context, 'device_mismatch', { deviceFingerprint });
        return { status: 'device_mismatch', message: 'Device not bound to this license' };
    }

    const deviceDoc = deviceSnap.docs[0];
    if (deviceDoc.data().status !== 'active') {
        logSecurityEvent('validateLicense_fail', context, 'device_blocked');
        return { status: 'blocked', message: 'Device is blocked' };
    }

    // Update Last Seen (Write Throttling: Only update if > 1 hour ago to save writes)
    const lastSeen = deviceDoc.data().lastSeenAt ? new Date(deviceDoc.data().lastSeenAt) : new Date(0);
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);

    if (lastSeen < oneHourAgo) {
        await deviceDoc.ref.update({
            lastSeenAt: new Date().toISOString()
        });
    }

    return {
        status: 'valid',
        expiryDate: license.expiryDate,
        features: license.enabledModules || [],
        validationToken: generateValidationToken(licenseKey, deviceFingerprint)
    };
});

// ============================================================================
// 3. ADMIN: CREATE LICENSE
// ============================================================================
// Admin App Only. Input: { businessType, maxDevices, expiryDays, customerId, enabledModules }
exports.adminCreateLicense = functions.https.onCall(async (data, context) => {
    // 1. RBAC Check
    logSecurityEvent('adminCreateLicense_attempt', context, 'pending');
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required');
    const adminUser = await db.collection('admin_users').doc(context.auth.uid).get();

    // Enforce Admin Role
    if (!adminUser.exists) {
        logSecurityEvent('adminCreateLicense_fail', context, 'not_admin');
        throw new functions.https.HttpsError('permission-denied', 'Not an admin user');
    }
    const adminData = adminUser.data();
    if (adminData.role !== 'admin' && adminData.role !== 'owner') {
        logSecurityEvent('adminCreateLicense_fail', context, 'insufficient_permissions', { role: adminData.role });
        throw new functions.https.HttpsError('permission-denied', 'Insufficient permissions');
    }

    const { businessType, maxDevices, expiryDays, customerId, enabledModules, type } = data;

    if (!businessType) throw new functions.https.HttpsError('invalid-argument', 'Business Type required');

    // 2. Generate Key
    const year = new Date().getFullYear();
    const platform = 'BOTH'; // Default
    const shortType = (businessType.substring(0, 4) || 'GEN').toUpperCase();
    const randomCode = crypto.randomBytes(3).toString('hex').toUpperCase(); // 6 chars
    const licenseKey = `APP-${shortType}-${platform}-${randomCode}-${year}`;

    // 3. Calculate Expiry
    const now = new Date();
    const expiryDate = new Date();
    expiryDate.setDate(now.getDate() + (expiryDays || 365));

    const licenseId = db.collection('licenses').doc().id;

    await db.collection('licenses').doc(licenseId).set({
        id: licenseId,
        licenseKey: licenseKey,
        businessType: businessType,
        customerId: customerId || null,
        licenseType: type || 'standard',
        maxDevices: maxDevices || 1,
        enabledModules: enabledModules || [],
        issueDate: now.toISOString(),
        expiryDate: expiryDate.toISOString(),
        status: 'inactive',
        platform: platform,
        createdBy: context.auth.uid,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp()
    });

    logSecurityEvent('adminCreateLicense_success', context, 'created', { licenseId });
    return { success: true, licenseKey: licenseKey, licenseId: licenseId };
});
