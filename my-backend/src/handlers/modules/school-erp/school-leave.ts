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
  const role = claims['custom:role'] ?? 'student';
  const body = event.body ? JSON.parse(event.body) : {};

  try {
    // GET /ac/leave/pending — admin/faculty only
    if (method === 'GET' && path === '/ac/leave/pending') {
      const result = await ddb.send(new QueryCommand({
        TableName: TABLE,
        IndexName: 'GSI1',
        KeyConditionExpression: 'GSI1PK = :pk AND GSI1SK = :sk',
        ExpressionAttributeValues: { ':pk': `TENANT#${tenantId}`, ':sk': 'LEAVE_STATUS#pending' },
      }));
      return ok({ items: result.Items ?? [] });
    }

    // GET /ac/leave/balance
    if (method === 'GET' && path === '/ac/leave/balance') {
      const result = await ddb.send(new GetCommand({
        TableName: TABLE,
        Key: { PK: `LEAVE_BALANCE#${userId}`, SK: `TENANT#${tenantId}` },
      }));
      return ok(result.Item ?? { casual: 12, sick: 6, earned: 15, used: { casual: 0, sick: 0, earned: 0 } });
    }

    // GET /ac/leave — list own leaves
    if (method === 'GET' && path === '/ac/leave') {
      const result = await ddb.send(new QueryCommand({
        TableName: TABLE,
        IndexName: 'GSI1',
        KeyConditionExpression: 'GSI1PK = :pk AND begins_with(GSI1SK, :sk)',
        ExpressionAttributeValues: { ':pk': `USER#${userId}`, ':sk': 'LEAVE#' },
      }));
      return ok({ items: result.Items ?? [] });
    }

    // POST /ac/leave — apply for leave
    if (method === 'POST' && path === '/ac/leave') {
      const id = uuidv4();
      const startDate = body.startDate;
      const endDate = body.endDate;
      const start = new Date(startDate);
      const end = new Date(endDate);
      const days = Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1;

      const item = {
        PK: `LEAVE#${id}`,
        SK: 'METADATA',
        GSI1PK: `USER#${userId}`,
        GSI1SK: `LEAVE#${new Date().toISOString()}`,
        GSI2PK: `TENANT#${tenantId}`,
        GSI2SK: 'LEAVE_STATUS#pending',
        id, tenantId, userId,
        applicantName: body.applicantName ?? '',
        personType: role,
        leaveType: body.leaveType,
        startDate, endDate, days,
        reason: body.reason ?? '',
        status: 'pending',
        appliedAt: new Date().toISOString(),
      };
      await ddb.send(new PutCommand({ TableName: TABLE, Item: item }));
      return ok(item, 201);
    }

    // POST /ac/leave/{leaveId}/approve
    if (method === 'POST' && path.includes('/approve')) {
      if (!['admin', 'teacher'].includes(role)) return err('Forbidden', 403);
      const leaveId = path.split('/')[3];
      const approved = body.approved !== false;
      const newStatus = approved ? 'approved' : 'rejected';

      await ddb.send(new UpdateCommand({
        TableName: TABLE,
        Key: { PK: `LEAVE#${leaveId}`, SK: 'METADATA' },
        UpdateExpression: 'SET #s = :s, reviewedBy = :rb, reviewedAt = :ra, GSI2SK = :gsk',
        ExpressionAttributeNames: { '#s': 'status' },
        ExpressionAttributeValues: { ':s': newStatus, ':rb': userId, ':ra': new Date().toISOString(), ':gsk': `LEAVE_STATUS#${newStatus}` },
      }));
      return ok({ message: `Leave ${newStatus}` });
    }

    return err('Not found', 404);
  } catch (e: any) {
    console.error('school-leave error:', e);
    return err(e.message ?? 'Internal server error', 500);
  }
};
