import { configureAwsClient } from '../../../config/aws.config';
import { APIGatewayProxyHandlerV2 } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, GetCommand, QueryCommand, UpdateCommand, DeleteCommand } from '@aws-sdk/lib-dynamodb';
import { v4 as uuidv4 } from 'uuid';

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient(configureAwsClient({})));
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
    // GET /ac/lesson-plans
    if (method === 'GET' && path === '/ac/lesson-plans') {
      const batchId = params.batchId;
      const result = await ddb.send(new QueryCommand({
        TableName: TABLE,
        IndexName: 'GSI1',
        KeyConditionExpression: 'GSI1PK = :pk AND begins_with(GSI1SK, :sk)',
        ExpressionAttributeValues: {
          ':pk': `FACULTY#${userId}`,
          ':sk': batchId ? `LP#BATCH#${batchId}` : 'LP#',
        },
        ScanIndexForward: false,
      }));
      return ok({ items: result.Items ?? [], total: result.Count ?? 0 });
    }

    // POST /ac/lesson-plans
    if (method === 'POST' && path === '/ac/lesson-plans') {
      const id = uuidv4();
      const plan = {
        PK: `LP#${id}`, SK: 'METADATA',
        GSI1PK: `FACULTY#${userId}`,
        GSI1SK: `LP#BATCH#${body.batchId}#${id}`,
        id, tenantId,
        batchId: body.batchId,
        subject: body.subject,
        topic: body.topic,
        subtopics: body.subtopics ?? [],
        objectives: body.objectives ?? '',
        teachingAids: body.teachingAids ?? [],
        duration: body.duration ?? 45,
        plannedDate: body.plannedDate ?? '',
        status: 'draft',
        createdBy: userId,
        createdAt: new Date().toISOString(),
      };
      await ddb.send(new PutCommand({ TableName: TABLE, Item: plan }));
      return ok(plan, 201);
    }

    // GET /ac/lesson-plans/{planId}
    if (method === 'GET' && path.match(/\/ac\/lesson-plans\/[^/]+$/)) {
      const planId = path.split('/').pop()!;
      const result = await ddb.send(new GetCommand({ TableName: TABLE, Key: { PK: `LP#${planId}`, SK: 'METADATA' } }));
      if (!result.Item) return err('Lesson plan not found', 404);
      return ok(result.Item);
    }

    // PUT /ac/lesson-plans/{planId}
    if (method === 'PUT' && path.match(/\/ac\/lesson-plans\/[^/]+$/)) {
      const planId = path.split('/').pop()!;
      await ddb.send(new UpdateCommand({
        TableName: TABLE,
        Key: { PK: `LP#${planId}`, SK: 'METADATA' },
        UpdateExpression: 'SET topic = :t, subtopics = :st, objectives = :o, #s = :s, updatedAt = :ua',
        ExpressionAttributeNames: { '#s': 'status' },
        ExpressionAttributeValues: {
          ':t': body.topic,
          ':st': body.subtopics ?? [],
          ':o': body.objectives ?? '',
          ':s': body.status ?? 'draft',
          ':ua': new Date().toISOString(),
        },
      }));
      return ok({ message: 'Lesson plan updated' });
    }

    // DELETE /ac/lesson-plans/{planId}
    if (method === 'DELETE' && path.match(/\/ac\/lesson-plans\/[^/]+$/)) {
      const planId = path.split('/').pop()!;
      await ddb.send(new DeleteCommand({ TableName: TABLE, Key: { PK: `LP#${planId}`, SK: 'METADATA' } }));
      return ok({ message: 'Lesson plan deleted' });
    }

    return err('Not found', 404);
  } catch (e: any) {
    console.error('school-lesson-plans error:', e);
    return err(e.message ?? 'Internal server error', 500);
  }
};
