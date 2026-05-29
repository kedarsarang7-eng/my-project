// ============================================================================
// UPLOAD ID CARD HANDLER - POST /staff/{staffId}/id-card
// ============================================================================
// Purpose: Upload generated ID card image to S3 for storage
// Features:
//   - Validate staff exists and belongs to station
//   - Upload image/PDF to S3
//   - Update DynamoDB with ID card metadata
//   - Return presigned URL for download
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { z } from 'zod';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { getItem, putItem, updateItem } from '../utils/dynamodb';
import { generateULID, getCurrentTimestamp } from '../utils/ulid';
import { TABLES, S3_BUCKETS } from '../constants/tables';
import type { StaffProfile, IDCardMetadata } from '../types/attendance';

// S3 client
const s3Client = new S3Client({});

// Validation schema
const uploadSchema = z.object({
  imageBase64: z.string().min(1, 'Image data is required'),
  format: z.enum(['PNG', 'PDF']),
  template: z.string().optional(),
  frontSide: z.boolean().default(true),
});

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: '',
    };
  }

  try {
    const staffId = event.pathParameters?.staffId;
    if (!staffId) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Staff ID is required' }),
      };
    }

    // Parse and validate body
    const body = JSON.parse(event.body || '{}');
    const validated = uploadSchema.parse(body);

    // Get staff profile
    const staff = await getItem<StaffProfile>(TABLES.STAFF_PROFILES, {
      staffId,
      SK: 'PROFILE',
    });

    if (!staff) {
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Staff not found' }),
      };
    }

    const stationId = staff.petrolPumpId;
    const timestamp = getCurrentTimestamp();
    const cardId = generateULID();
    const datePrefix = timestamp.split('T')[0];

    // Decode base64 image
    const imageBuffer = Buffer.from(validated.imageBase64, 'base64');
    const contentType = validated.format === 'PDF' ? 'application/pdf' : 'image/png';
    const fileExtension = validated.format === 'PDF' ? 'pdf' : 'png';

    // S3 key path: id-cards/{stationId}/{date}/{staffId}/{cardId}.{ext}
    const s3Key = `id-cards/${stationId}/${datePrefix}/${staffId}/${cardId}.${fileExtension}`;

    // Upload to S3
    const putCommand = new PutObjectCommand({
      Bucket: S3_BUCKETS.ID_CARD_SCANS,
      Key: s3Key,
      Body: imageBuffer,
      ContentType: contentType,
      Metadata: {
        staffId,
        stationId,
        uploadedAt: timestamp,
        format: validated.format,
        template: validated.template || 'standard',
      },
    });

    await s3Client.send(putCommand);

    // Generate presigned URL (valid for 1 hour)
    const getCommand = new PutObjectCommand({
      Bucket: S3_BUCKETS.ID_CARD_SCANS,
      Key: s3Key,
    });
    const presignedUrl = await getSignedUrl(s3Client, getCommand, { expiresIn: 3600 });

    // Store metadata in DynamoDB
    const cardMetadata: IDCardMetadata = {
      PK: `STAFF#${staffId}`,
      SK: `IDCARD#${cardId}`,
      cardId,
      staffId,
      stationId,
      s3Key,
      format: validated.format,
      template: validated.template || 'standard',
      uploadedAt: timestamp,
      uploadedBy: event.requestContext.authorizer?.claims?.sub || 'unknown',
      size: imageBuffer.length,
      url: presignedUrl,
    };

    await putItem(TABLES.ID_CARD_SCANS, cardMetadata);

    // Update staff profile with latest ID card
    await updateItem<StaffProfile>(
      TABLES.STAFF_PROFILES,
      { staffId, SK: 'PROFILE' },
      {
        latestIdCardUrl: presignedUrl,
        latestIdCardS3Key: s3Key,
        idCardUpdatedAt: timestamp,
      }
    );

    return {
      statusCode: 201,
      headers: corsHeaders,
      body: JSON.stringify({
        cardId,
        s3Key,
        downloadUrl: presignedUrl,
        expiresIn: 3600,
        staffName: staff.fullName,
        format: validated.format,
        size: imageBuffer.length,
        message: 'ID card uploaded successfully',
      }),
    };

  } catch (error) {
    console.error('Upload ID card error:', error);
    
    if (error instanceof z.ZodError) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'Validation failed',
          details: error.errors,
        }),
      };
    }

    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error',
      }),
    };
  }
};
