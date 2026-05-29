// ============================================================================
// Lambda Handler — In-Store Barcode Product Lookup
// ============================================================================
// GET /in-store/products/barcode/{barcode}?storeId={storeId}
//
// Returns product details for self-scan checkout.
// Uses GSI3 (barcodeGSI3PK / barcodeGSI3SK) from dynamodb.config.ts.
// Falls back to a scan of PRODUCT# prefix with barcode filter.
// ============================================================================

import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { Keys, queryItems, getItem } from '../config/dynamodb.config';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import { UserRole, AuthContext } from '../types/tenant.types';
import { SELF_SCAN_ELIGIBLE_BUSINESS_TYPES } from '../types/in-store.types';
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { config } from '../config/environment';

const s3 = new S3Client({ region: config.aws.region });
const BUCKET = config.s3.bucketName;
const PRESIGN_TTL = 900; // 15 minutes

async function freshenImageUrl(s3Key?: string): Promise<string | undefined> {
    if (!s3Key) return undefined;
    try {
        const url = await getSignedUrl(s3, new GetObjectCommand({ Bucket: BUCKET, Key: s3Key }), { expiresIn: PRESIGN_TTL });
        return url;
    } catch {
        return undefined;
    }
}

// ── GET /in-store/products/barcode/{barcode} ─────────────────────────────────

export const getProductByBarcode = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext) => {
        const barcode = event.pathParameters?.barcode;
        const storeId = event.queryStringParameters?.storeId;

        if (!barcode) return response.badRequest('barcode path parameter required');
        if (!storeId) return response.badRequest('storeId query parameter required');

        // Verify business type supports self-scan
        const businessType = auth.businessType as string;
        if (!(SELF_SCAN_ELIGIBLE_BUSINESS_TYPES as readonly string[]).includes(businessType)) {
            return response.forbidden(`Self Scan not supported for business type: ${businessType}`);
        }

        const tenantPK = Keys.tenantPK(auth.tenantId);

        // Strategy 1: GSI3 — direct barcode index (O(1) if barcode indexed)
        // GSI3PK = TENANT#<tenantId>, GSI3SK = BARCODE#<barcode>
        const gsi3Result = await queryItems<Record<string, any>>(
            Keys.barcodeGSI3PK(auth.tenantId),
            Keys.barcodeGSI3SK(barcode),
            { indexName: 'GSI3', limit: 5 }
        );

        let product: Record<string, any> | null = null;

        if (gsi3Result.items.length > 0) {
            // If storeId provided, prefer store-specific price book; else use first match
            product = gsi3Result.items.find(p =>
                (p.storeId === storeId || !p.storeId) &&
                p.isActive !== false &&
                !p.isDeleted
            ) || null;
        }

        // Strategy 2: Filter scan across PRODUCT# prefix (fallback)
        if (!product) {
            const scanResult = await queryItems<Record<string, any>>(
                tenantPK,
                'PRODUCT#',
                {
                    filterExpression: 'barcode = :barcode AND isActive = :true AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                    expressionAttributeValues: {
                        ':barcode': barcode,
                        ':true': true,
                        ':false': false,
                    },
                    limit: 5,
                }
            );

            if (scanResult.items.length > 0) {
                product = scanResult.items[0];
            }
        }

        if (!product) {
            logger.info('Barcode not found', { barcode, tenantId: auth.tenantId, storeId });
            return response.notFound('Product');
        }

        // Stock check
        const stockQuantity = Number(product.stockQuantity ?? product.quantity ?? 0);
        const isInStock = stockQuantity > 0;

        // Freshen image URL
        const imageUrl = await freshenImageUrl(product.imageS3Key || product.imageKey);

        // Calculate GST amount on selling price
        const sellingPriceCents = Number(product.salePriceCents || product.sellingPriceCents || product.priceCents || 0);
        const mrpCents = Number(product.mrpCents || product.maxRetailPriceCents || sellingPriceCents);
        const gstSlab = Number(product.gstSlab || product.gstRate || product.taxRate || 0);
        const discountPercent = mrpCents > 0
            ? Math.round(((mrpCents - sellingPriceCents) / mrpCents) * 100)
            : 0;

        // GST is included in selling price (GST-inclusive pricing)
        const taxableAmount = Math.round(sellingPriceCents / (1 + gstSlab / 100));
        const gstAmountCents = sellingPriceCents - taxableAmount;

        return response.success({
            productId: product.id || product.productId,
            name: product.name,
            brand: product.brand || null,
            imageUrl: imageUrl || product.imageUrl || null,
            mrp: mrpCents,
            sellingPrice: sellingPriceCents,
            discountPercent,
            gstSlab,
            gstAmount: gstAmountCents,
            stockAvailable: isInStock,
            stockQuantity,
            unit: product.unit || product.unitOfMeasure || 'piece',
            category: product.category || product.categoryName || null,
            barcode,
        });
    }
);
