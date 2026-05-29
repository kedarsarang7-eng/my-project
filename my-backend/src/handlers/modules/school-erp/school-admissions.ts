import { APIGatewayProxyHandlerV2 } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, GetCommand, QueryCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { v4 as uuidv4 } from 'uuid';

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const TABLE = process.env.DYNAMODB_TABLE!;

const ok = (body: unknown, status = 200) => ({ statusCode: status, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }, body: JSON.stringify(body) });
const err = (msg: string, status = 400) => ({ statusCode: status, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }, body: JSON.stringify({ message: msg }) });

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  const method = event.requestContext.http.method;
  const path = event.rawPath;
  const claims = (event.requestContext as any).authorizer?.jwt?.claims ?? {};
  const tenantId = claims['custom:tenantId'] ?? 'default';
  const userId = claims.sub ?? '';
  const body = event.body ? JSON.parse(event.body) : {};
  const params = event.queryStringParameters ?? {};

  try {
    // GET /ac/admissions
    if (method === 'GET' && path === '/ac/admissions') {
      const status = params.status ?? 'pending';
      const result = await ddb.send(new QueryCommand({
        TableName: TABLE,
        IndexName: 'GSI1',
        KeyConditionExpression: 'GSI1PK = :pk AND GSI1SK = :sk',
        ExpressionAttributeValues: { ':pk': `TENANT#${tenantId}`, ':sk': `ADMISSION_STATUS#${status}` },
        ScanIndexForward: false,
        Limit: parseInt(params.limit ?? '50'),
      }));
      return ok({ items: result.Items ?? [], total: result.Count ?? 0, status });
    }

    // POST /ac/admissions — new application
    if (method === 'POST' && path === '/ac/admissions') {
      const id = uuidv4();
      const item = {
        PK: `ADMISSION#${id}`,
        SK: 'METADATA',
        GSI1PK: `TENANT#${tenantId}`,
        GSI1SK: 'ADMISSION_STATUS#pending',
        id, tenantId,
        firstName: body.firstName ?? '',
        lastName: body.lastName ?? '',
        email: body.email ?? '',
        phone: body.phone ?? '',
        dateOfBirth: body.dateOfBirth ?? '',
        requestedBatch: body.requestedBatch ?? body.batchId ?? '',
        parentName: body.parentName ?? '',
        parentPhone: body.parentPhone ?? '',
        address: body.address ?? '',
        status: 'pending',
        appliedDate: new Date().toISOString().split('T')[0],
        createdAt: new Date().toISOString(),
        createdBy: userId,
      };
      await ddb.send(new PutCommand({ TableName: TABLE, Item: item }));
      return ok(item, 201);
    }

    // GET /ac/admissions/{admissionId}
    if (method === 'GET' && path.match(/\/ac\/admissions\/[^/]+$/)) {
      const admissionId = path.split('/').pop()!;
      const result = await ddb.send(new GetCommand({ TableName: TABLE, Key: { PK: `ADMISSION#${admissionId}`, SK: 'METADATA' } }));
      if (!result.Item) return err('Admission not found', 404);
      return ok(result.Item);
    }

    // POST /ac/admissions/{admissionId}/review — approve or reject
    if (method === 'POST' && path.includes('/review')) {
      const admissionId = path.split('/')[3];
      const action = body.action as 'approve' | 'reject';
      if (!['approve', 'reject'].includes(action)) return err('action must be approve or reject');

      const newStatus = action === 'approve' ? 'approved' : 'rejected';
      await ddb.send(new UpdateCommand({
        TableName: TABLE,
        Key: { PK: `ADMISSION#${admissionId}`, SK: 'METADATA' },
        UpdateExpression: 'SET #s = :s, reviewedBy = :rb, reviewedAt = :ra, GSI1SK = :gsk, rejectionReason = :rr',
        ExpressionAttributeNames: { '#s': 'status' },
        ExpressionAttributeValues: {
          ':s': newStatus,
          ':rb': userId,
          ':ra': new Date().toISOString(),
          ':gsk': `ADMISSION_STATUS#${newStatus}`,
          ':rr': body.reason ?? '',
        },
      }));

      // If approved → create student record
      if (action === 'approve') {
        const admission = (await ddb.send(new GetCommand({ TableName: TABLE, Key: { PK: `ADMISSION#${admissionId}`, SK: 'METADATA' } }))).Item;
        if (admission) {
          const studentId = `STU${Date.now().toString().slice(-6)}`;
          await ddb.send(new PutCommand({
            TableName: TABLE,
            Item: {
              PK: `STUDENT#${uuidv4()}`,
              SK: 'METADATA',
              GSI1PK: `TENANT#${tenantId}`,
              GSI1SK: `BATCH#${admission.requestedBatch}#STUDENT`,
              ...admission,
              studentId,
              status: 'active',
              enrolledDate: new Date().toISOString().split('T')[0],
              admissionId,
            },
          }));
        }
      }

      return ok({ message: `Admission ${newStatus}`, status: newStatus });
    }

    return err('Not found', 404);
  } catch (e: any) {
    console.error('school-admissions error:', e);
    return err(e.message ?? 'Internal server error', 500);
  }
};
