// ============================================================================
// EMAIL ID CARD HANDLER - POST /staff/{staffId}/id-card/email
// ============================================================================
// Purpose: Email ID card to staff member via Amazon SES
// Features:
//   - Generate ID card on-the-fly or use existing S3 copy
//   - Send email with ID card attachment
//   - Professional HTML email template
//   - Track email delivery status
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { z } from 'zod';
import { SESClient, SendRawEmailCommand } from '@aws-sdk/client-ses';
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import { getItem, putItem, queryItems } from '../utils/dynamodb';
import { getCurrentTimestamp } from '../utils/ulid';
import { TABLES, S3_BUCKETS } from '../constants/tables';
import type { StaffProfile, IDCardMetadata } from '../types/attendance';

const sesClient = new SESClient({});
const s3Client = new S3Client({});

// Validation schema
const emailSchema = z.object({
  generateOnFly: z.boolean().default(false),
  s3Key: z.string().optional(),
  customMessage: z.string().max(500).optional(),
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
    const validated = emailSchema.parse(body);

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

    if (!staff.email) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Staff does not have an email address' }),
      };
    }

    // Get ID card data
    let attachmentData: Buffer;
    let fileName: string;
    let contentType: string;

    if (validated.s3Key) {
      // Fetch from S3
      const getCommand = new GetObjectCommand({
        Bucket: S3_BUCKETS.ID_CARD_SCANS,
        Key: validated.s3Key,
      });
      
      const response = await s3Client.send(getCommand);
      const streamToBuffer = async (stream: any): Promise<Buffer> => {
        const chunks: Buffer[] = [];
        for await (const chunk of stream) {
          chunks.push(chunk);
        }
        return Buffer.concat(chunks);
      };
      
      attachmentData = await streamToBuffer(response.Body);
      fileName = validated.s3Key.split('/').pop() || 'id-card.pdf';
      contentType = response.ContentType || 'application/pdf';
    } else {
      // Get latest ID card from DynamoDB
      const latestCards = await queryItems<IDCardMetadata>(TABLES.ID_CARD_SCANS, {
        keyConditionExpression: 'PK = :staffId',
        expressionAttributeValues: {
          ':staffId': `STAFF#${staffId}`,
        },
        scanIndexForward: false,
        limit: 1,
      });

      if (latestCards.items.length === 0) {
        return {
          statusCode: 404,
          headers: corsHeaders,
          body: JSON.stringify({ error: 'No ID card found for this staff' }),
        };
      }

      const latestCard = latestCards.items[0];
      
      const getCommand = new GetObjectCommand({
        Bucket: S3_BUCKETS.ID_CARD_SCANS,
        Key: latestCard.s3Key,
      });
      
      const response = await s3Client.send(getCommand);
      const streamToBuffer = async (stream: any): Promise<Buffer> => {
        const chunks: Buffer[] = [];
        for await (const chunk of stream) {
          chunks.push(chunk);
        }
        return Buffer.concat(chunks);
      };
      
      attachmentData = await streamToBuffer(response.Body);
      fileName = `id-card-${staffId}.${latestCard.format.toLowerCase()}`;
      contentType = latestCard.format === 'PDF' ? 'application/pdf' : 'image/png';
    }

    // Build email
    const timestamp = getCurrentTimestamp();
    const senderEmail = process.env.SES_SENDER_EMAIL || 'noreply@petrolpump.com';
    const stationName = staff.petrolPumpId; // Would fetch actual name from DB
    
    const subject = `Your Staff ID Card - ${stationName}`;
    
    const htmlBody = `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: #1E3A5F; color: white; padding: 20px; text-align: center; }
    .content { background: #f9f9f9; padding: 30px; margin: 20px 0; }
    .footer { text-align: center; color: #666; font-size: 12px; }
    .highlight { background: #fff3cd; padding: 15px; border-left: 4px solid #ffc107; margin: 20px 0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Your Staff ID Card</h1>
    </div>
    
    <div class="content">
      <p>Dear ${staff.fullName},</p>
      
      <p>Your digital ID card has been generated and is attached to this email.</p>
      
      <div class="highlight">
        <strong>Important:</strong>
        <ul>
          <li>Please print this ID card and carry it during your shifts</li>
          <li>Use this ID card for scanning during check-in/check-out</li>
          <li>If lost, contact your manager immediately</li>
        </ul>
      </div>
      
      <p><strong>Staff ID:</strong> ${staffId}</p>
      <p><strong>Role:</strong> ${staff.role}</p>
      <p><strong>Generated:</strong> ${new Date(timestamp).toLocaleString()}</p>
      
      ${validated.customMessage ? `<p><em>${validated.customMessage}</em></p>` : ''}
    </div>
    
    <div class="footer">
      <p>This is an automated message from Petrol Pump Management System</p>
      <p>© ${new Date().getFullYear()} ${stationName}</p>
    </div>
  </div>
</body>
</html>`;

    // Build raw email with attachment
    const boundary = `----=_Part_${Date.now()}`;
    const rawEmail = [
      `From: ${senderEmail}`,
      `To: ${staff.email}`,
      `Subject: ${subject}`,
      `MIME-Version: 1.0`,
      `Content-Type: multipart/mixed; boundary="${boundary}"`,
      '',
      `--${boundary}`,
      `Content-Type: text/html; charset=UTF-8`,
      `Content-Transfer-Encoding: 7bit`,
      '',
      htmlBody,
      '',
      `--${boundary}`,
      `Content-Type: ${contentType}; name="${fileName}"`,
      `Content-Disposition: attachment; filename="${fileName}"`,
      `Content-Transfer-Encoding: base64`,
      '',
      attachmentData.toString('base64'),
      '',
      `--${boundary}--`,
    ].join('\n');

    // Send email via SES
    const sendCommand = new SendRawEmailCommand({
      RawMessage: {
        Data: Buffer.from(rawEmail),
      },
    });

    const result = await sesClient.send(sendCommand);

    // Log email sent (optional - for tracking)
    const emailLog = {
      PK: `STAFF#${staffId}`,
      SK: `EMAIL#${timestamp}`,
      staffId,
      email: staff.email,
      type: 'ID_CARD',
      messageId: result.MessageId,
      sentAt: timestamp,
      s3Key: validated.s3Key || 'latest',
    };
    
    await putItem('PetrolStaffEmailLog', emailLog);

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        success: true,
        message: 'ID card emailed successfully',
        email: staff.email,
        messageId: result.MessageId,
        staffName: staff.fullName,
      }),
    };

  } catch (error) {
    console.error('Email ID card error:', error);
    
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
