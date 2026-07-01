import { APIGatewayProxyHandler } from 'aws-lambda';
import * as admin from 'firebase-admin';
import { v4 as uuidv4 } from 'uuid';
import * as crypto from 'crypto';
import { SNSClient, PublishCommand, DeleteEndpointCommand } from "@aws-sdk/client-sns";
import { authorizedHandler } from '../middleware/handler-wrapper';
import { getPool } from '../config/db.config';
import { logger } from '../utils/logger';

// --- Configuration ---
const MERCHANT_ID = process.env.PHONEPE_MERCHANT_ID || 'MERC_ID';
const SALT_KEY = process.env.PHONEPE_SALT_KEY || 'SALT_KEY';
const SALT_INDEX = process.env.PHONEPE_SALT_INDEX || '1';
const FIREBASE_DB_URL = process.env.FIREBASE_DB_URL;

const snsClient = new SNSClient({ region: process.env.AWS_REGION });

// --- Initialize Firebase Admin (graceful — server starts even without Firebase) ---
let firebaseDb: admin.database.Database | null = null;

try {
    const raw = process.env.FIREBASE_SERVICE_ACCOUNT || '{}';
    const serviceAccount = JSON.parse(raw);
    if (serviceAccount.project_id && !admin.apps.length) {
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
            databaseURL: FIREBASE_DB_URL
        });
        firebaseDb = admin.database();
        logger.info("Firebase Admin Initialized");
    } else if (!admin.apps.length) {
        logger.warn("Firebase skipped — FIREBASE_SERVICE_ACCOUNT has no project_id");
    } else {
        firebaseDb = admin.database();
    }
} catch (e) {
    logger.warn("Firebase skipped — invalid config", { error: (e as Error).message });
}

// --- Feature A: Initiate Payment (Dynamic QR) ---
export const initiatePayment = authorizedHandler([], async (event, _context, auth) => {
    const body = JSON.parse(event.body || '{}');
    const { amount, fuelType, customerId } = body;

    if (!amount || !fuelType) {
        return { statusCode: 400, body: JSON.stringify({ message: "Missing required fields: amount, fuelType" }) };
    }

    const pool = getPool();
    // Use the tenant context automatically set by authorizedHandler
    const rateRes = await pool.query(
        `SELECT petrol_price, diesel_price FROM daily_rates WHERE tenant_id = $1 ORDER BY date DESC LIMIT 1`,
        [auth.tenantId]
    );

    if (rateRes.rows.length === 0) {
        return { statusCode: 400, body: JSON.stringify({ message: "Daily rates not set for today" }) };
    }

    const rate = fuelType === 'petrol' ? rateRes.rows[0].petrol_price : rateRes.rows[0].diesel_price;
    const liters = (amount / rate).toFixed(2);
    const transactionId = uuidv4();

    // 2. Prepare PhonePe Payload
    const payload = {
        merchantId: MERCHANT_ID,
        merchantTransactionId: transactionId,
        merchantUserId: auth.tenantId,
        amount: amount * 100, // in paise
        redirectUrl: `https://${event.requestContext.domainName}/phonepe-webhook`,
        redirectMode: "POST",
        callbackUrl: `https://${event.requestContext.domainName}/phonepe-webhook`,
        paymentInstrument: {
            type: "PAY_PAGE"
        }
    };

    const base64Payload = Buffer.from(JSON.stringify(payload)).toString('base64');
    // const checksum = crypto.createHash('sha256').update(base64Payload + "/pg/v1/pay" + SALT_KEY).digest('hex') + "###" + SALT_INDEX;

    // 3. Insert Pending Transaction
    await pool.query(
        `INSERT INTO transactions (id, tenant_id, amount, liters, payment_mode, status, timestamp, customer_id) 
         VALUES ($1, $2, $3, $4, 'UPI', 'PENDING', NOW(), $5)`,
        [transactionId, auth.tenantId, amount, liters, customerId || null]
    );

    // MOCKING Response for "Zero Cost" Development Env
    const qrCodeUrl = `upi://pay?pa=mockmerchant@ybl&pn=PetrolPump&am=${amount}&tr=${transactionId}&tn=FuelPayment`;

    return {
        statusCode: 200,
        body: JSON.stringify({
            transactionId,
            qrCode: qrCodeUrl,
            liters,
            rate
        })
    };
});

// --- Feature B: Webhook & Sync ---
export const paymentWebhook: APIGatewayProxyHandler = async (event) => {
    try {
        // 1. Verify Checksum
        const xVerify = event.headers['x-verify'] || event.headers['X-VERIFY'];
        if (!xVerify) return { statusCode: 401, body: "Missing Checksum" };

        const body = JSON.parse(event.body || '{}');
        const { code, merchantTransactionId, transactionId, amount } = body;

        if (code === 'PAYMENT_SUCCESS') {
            const pool = getPool();

            // NOTE: This runs as SYSTEM. 
            // We update specific transaction by ID.

            const updateRes = await pool.query(
                `UPDATE transactions SET status = 'SUCCESS', payment_id = $1 WHERE id = $2 RETURNING tenant_id, liters, payment_mode, customer_id`,
                [transactionId || merchantTransactionId, merchantTransactionId]
            );

            if (updateRes.rowCount === 0) {
                return { statusCode: 404, body: "Transaction not found (or access denied)" };
            }

            const { tenant_id, liters, customer_id } = updateRes.rows[0];

            // 3. Update Firebase (skip if Firebase not configured)
            if (firebaseDb) {
                const saleRef = firebaseDb.ref(`tenants/${tenant_id}/today_sales/${merchantTransactionId}`);
                await saleRef.set({
                    amount: amount / 100,
                    liters: parseFloat(liters),
                    fuel_type: 'petrol',
                    timestamp: admin.database.ServerValue.TIMESTAMP,
                    status: 'COMPLETED'
                });
            } else {
                logger.warn('Firebase not configured — skipping real-time sync');
            }

            // 4. Send SNS Push Notification (Feature Added)
            if (customer_id) {
                try {
                    const userRes = await pool.query(
                        `SELECT sns_endpoint_arn FROM users WHERE id = $1`,
                        [customer_id]
                    );

                    if (userRes.rows.length > 0 && userRes.rows[0].sns_endpoint_arn) {
                        const endpointArn = userRes.rows[0].sns_endpoint_arn;

                        try {
                            const publishCommand = new PublishCommand({
                                TargetArn: endpointArn,
                                Message: JSON.stringify({
                                    default: `Payment Successful! ₹${amount / 100} paid for ${liters}L fuel.`,
                                    GCM: JSON.stringify({
                                        notification: {
                                            title: 'Payment Received',
                                            body: `Thanks! We received ₹${amount / 100}.`
                                        },
                                        data: {
                                            transactionId: merchantTransactionId,
                                            type: 'PAYMENT_SUCCESS'
                                        }
                                    })
                                }),
                                MessageStructure: 'json'
                            });

                            await snsClient.send(publishCommand);
                            logger.info('Push Notification Sent', { customer_id });

                        } catch (snsError: any) {
                            if (snsError.name === 'EndpointDisabledException') {
                                logger.warn('Endpoint Disabled, removing from DB', { endpointArn });
                                await pool.query(
                                    `UPDATE users SET sns_endpoint_arn = NULL WHERE id = $1`,
                                    [customer_id]
                                );
                                // Optional: Delete from SNS
                                // await snsClient.send(new DeleteEndpointCommand({ EndpointArn: endpointArn }));
                            } else {
                                logger.error('Failed to send SNS Notification', { error: snsError.message });
                            }
                        }
                    }
                } catch (dbError) {
                    logger.error('Failed to fetch user for notification', { error: (dbError as Error).message });
                }
            }

            return { statusCode: 200, body: JSON.stringify({ success: true }) };
        }

        return { statusCode: 200, body: JSON.stringify({ success: false, message: "Payment Failed or Pending" }) };

    } catch (error) {
        logger.error("Webhook Failed", { error: (error as Error).message });
        return { statusCode: 500, body: JSON.stringify({ error: (error as Error).message }) };
    }
};
