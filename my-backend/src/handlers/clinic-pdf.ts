// ============================================================================
// Lambda Handler — Clinic PDF Generation (Prescription + Invoice)
// ============================================================================
import { authorizedHandler } from '../middleware/handler-wrapper';
import { FeatureKey } from '../config/plan-feature-registry';
import { Keys, getItem, queryItems } from '../config/dynamodb.config';
import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { AuthContext, BusinessType, UserRole } from '../types/tenant.types';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import PDFDocument from 'pdfkit';

const CLINIC_OPTS = { requiredBusinessType: BusinessType.CLINIC, requiredFeature: FeatureKey.CLINIC_E_PRESCRIPTION };

function isValidUUID(s: string | undefined): s is string {
    return !!s && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s);
}

/**
 * Generate a PDF buffer from a PDFDocument
 */
function generatePDFBuffer(doc: PDFKit.PDFDocument): Promise<Buffer> {
    return new Promise((resolve, reject) => {
        const chunks: Buffer[] = [];
        doc.on('data', (chunk: Buffer) => chunks.push(chunk));
        doc.on('end', () => resolve(Buffer.concat(chunks)));
        doc.on('error', reject);
    });
}

/**
 * GET /clinic/prescriptions/{id}/pdf — Generate prescription PDF
 */
export const generatePrescriptionPDF = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const id = event.pathParameters?.id;
    if (!isValidUUID(id)) return response.badRequest('Invalid prescription ID');

    const pk = Keys.tenantPK(auth.tenantId);

    try {
        const prescription = await getItem<Record<string, any>>(pk, `PRESCRIPTION#${id}`);
        if (!prescription || prescription.isDeleted) return response.notFound('Prescription');

        // Get patient + doctor info
        const [patient, doctor] = await Promise.all([
            getItem<Record<string, any>>(pk, `PATIENT#${prescription.patientId}`),
            prescription.doctorId ? getItem<Record<string, any>>(pk, `DOCTOR#${prescription.doctorId}`) : null,
        ]);

        const doc = new PDFDocument({ size: 'A4', margin: 50 });
        const bufferPromise = generatePDFBuffer(doc);

        // Header
        doc.fontSize(20).font('Helvetica-Bold').text('PRESCRIPTION', { align: 'center' });
        doc.moveDown(0.5);
        doc.fontSize(10).font('Helvetica').text(`Date: ${new Date(prescription.createdAt).toLocaleDateString('en-IN')}`, { align: 'right' });

        // Doctor info
        if (doctor) {
            doc.fontSize(12).font('Helvetica-Bold').text(`Dr. ${doctor.name}`);
            if (doctor.specialization) doc.fontSize(10).font('Helvetica').text(doctor.specialization);
            if (doctor.registrationNumber) doc.text(`Reg. No: ${doctor.registrationNumber}`);
        }
        doc.moveDown();

        // Patient info
        doc.moveTo(50, doc.y).lineTo(545, doc.y).stroke();
        doc.moveDown(0.5);
        doc.fontSize(11).font('Helvetica-Bold').text('Patient: ', { continued: true });
        doc.font('Helvetica').text(patient?.name || 'Unknown');
        if (patient?.age) doc.text(`Age: ${patient.age} | Gender: ${patient.gender || '-'} | Blood Group: ${patient.bloodGroup || '-'}`);
        doc.moveDown();

        // Medicines table
        doc.moveTo(50, doc.y).lineTo(545, doc.y).stroke();
        doc.moveDown(0.5);
        doc.fontSize(12).font('Helvetica-Bold').text('Rx');
        doc.moveDown(0.5);

        const medicines = prescription.medicines || [];
        medicines.forEach((med: any, i: number) => {
            doc.fontSize(11).font('Helvetica-Bold').text(`${i + 1}. ${med.medicineName}`);
            const details = [`Dosage: ${med.dosage || '-'}`, `Duration: ${med.duration || '-'}`];
            if (med.instructions) details.push(`Instructions: ${med.instructions}`);
            doc.fontSize(10).font('Helvetica').text(`   ${details.join('  |  ')}`);
            doc.moveDown(0.3);
        });

        // Advice
        if (prescription.advice) {
            doc.moveDown();
            doc.fontSize(11).font('Helvetica-Bold').text('Advice: ', { continued: true });
            doc.font('Helvetica').text(prescription.advice);
        }

        // Next visit
        if (prescription.nextVisitDate) {
            doc.moveDown();
            doc.fontSize(11).font('Helvetica-Bold').text('Next Visit: ', { continued: true });
            doc.font('Helvetica').text(new Date(prescription.nextVisitDate).toLocaleDateString('en-IN'));
        }

        // Footer
        doc.moveDown(2);
        doc.moveTo(350, doc.y).lineTo(545, doc.y).stroke();
        doc.moveDown(0.3);
        doc.fontSize(10).text('Doctor\'s Signature', { align: 'right' });

        doc.end();
        const pdfBuffer = await bufferPromise;

        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/pdf',
                'Content-Disposition': `inline; filename="prescription-${id}.pdf"`,
            },
            body: pdfBuffer.toString('base64'),
            isBase64Encoded: true,
        };
    } catch (err: any) {
        logger.error('Failed to generate prescription PDF', { error: err.message });
        return response.internalError('Failed to generate prescription PDF');
    }
}, CLINIC_OPTS);

/**
 * GET /clinic/billing/{id}/pdf — Generate invoice/receipt PDF
 */
export const generateInvoicePDF = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const id = event.pathParameters?.id;
    if (!isValidUUID(id)) return response.badRequest('Invalid bill ID');

    const pk = Keys.tenantPK(auth.tenantId);

    try {
        const bill = await getItem<Record<string, any>>(pk, `CLINICBILL#${id}`);
        if (!bill || bill.isDeleted) return response.notFound('Bill');

        const doc = new PDFDocument({ size: 'A4', margin: 50 });
        const bufferPromise = generatePDFBuffer(doc);

        // Header
        doc.fontSize(20).font('Helvetica-Bold').text('INVOICE / RECEIPT', { align: 'center' });
        doc.moveDown(0.5);
        doc.fontSize(10).font('Helvetica');
        doc.text(`Invoice #: ${bill.invoiceNumber}`, { align: 'right' });
        doc.text(`Date: ${new Date(bill.createdAt).toLocaleDateString('en-IN')}`, { align: 'right' });
        doc.moveDown();

        // Patient
        doc.fontSize(12).font('Helvetica-Bold').text('Bill To:');
        doc.fontSize(11).font('Helvetica').text(bill.patientName || 'Patient');
        doc.moveDown();

        // Table header
        doc.moveTo(50, doc.y).lineTo(545, doc.y).stroke();
        doc.moveDown(0.3);
        const tableY = doc.y;
        doc.fontSize(10).font('Helvetica-Bold');
        doc.text('#', 50, tableY, { width: 30 });
        doc.text('Service', 80, tableY, { width: 200 });
        doc.text('Qty', 280, tableY, { width: 40, align: 'center' });
        doc.text('Rate', 320, tableY, { width: 80, align: 'right' });
        doc.text('Disc%', 400, tableY, { width: 50, align: 'center' });
        doc.text('Amount', 450, tableY, { width: 95, align: 'right' });
        doc.moveDown();
        doc.moveTo(50, doc.y).lineTo(545, doc.y).stroke();
        doc.moveDown(0.3);

        // Line items
        const items = bill.items || [];
        items.forEach((item: any, i: number) => {
            const lineTotal = item.unitPrice * item.quantity * (1 - (item.discount || 0) / 100);
            const y = doc.y;
            doc.fontSize(10).font('Helvetica');
            doc.text(`${i + 1}`, 50, y, { width: 30 });
            doc.text(item.serviceName, 80, y, { width: 200 });
            doc.text(`${item.quantity}`, 280, y, { width: 40, align: 'center' });
            doc.text(`₹${item.unitPrice.toFixed(2)}`, 320, y, { width: 80, align: 'right' });
            doc.text(`${item.discount || 0}%`, 400, y, { width: 50, align: 'center' });
            doc.text(`₹${lineTotal.toFixed(2)}`, 450, y, { width: 95, align: 'right' });
            doc.moveDown(0.5);
        });

        // Total
        doc.moveDown(0.5);
        doc.moveTo(350, doc.y).lineTo(545, doc.y).stroke();
        doc.moveDown(0.3);
        doc.fontSize(12).font('Helvetica-Bold');
        doc.text(`Total: ₹${(bill.grandTotal || 0).toFixed(2)}`, 350, doc.y, { width: 195, align: 'right' });
        doc.moveDown();
        doc.fontSize(10).font('Helvetica').text(`Payment Mode: ${(bill.paymentMode || 'cash').toUpperCase()}`, { align: 'right' });

        doc.end();
        const pdfBuffer = await bufferPromise;

        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/pdf',
                'Content-Disposition': `inline; filename="invoice-${bill.invoiceNumber}.pdf"`,
            },
            body: pdfBuffer.toString('base64'),
            isBase64Encoded: true,
        };
    } catch (err: any) {
        logger.error('Failed to generate invoice PDF', { error: err.message });
        return response.internalError('Failed to generate invoice PDF');
    }
}, CLINIC_OPTS);
