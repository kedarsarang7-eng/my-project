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
  const tenantId = (event.requestContext as any).authorizer?.jwt?.claims?.['custom:tenantId'] ?? 'default';
  const userId = (event.requestContext as any).authorizer?.jwt?.claims?.sub ?? '';
  const body = event.body ? JSON.parse(event.body) : {};
  const params = event.queryStringParameters ?? {};

  try {
    // GET /ac/homework
    if (method === 'GET' && path === '/ac/homework') {
      const batchId = params.batchId;
      const queryParams: any = {
        TableName: TABLE,
        IndexName: 'GSI1',
        KeyConditionExpression: batchId
          ? 'GSI1PK = :pk AND begins_with(GSI1SK, :sk)'
          : 'GSI1PK = :pk',
        ExpressionAttributeValues: batchId
          ? { ':pk': `TENANT#${tenantId}`, ':sk': `BATCH#${batchId}#HW` }
          : { ':pk': `TENANT#${tenantId}`, ':sk': 'HW#' },
      };
      const result = await ddb.send(new QueryCommand(queryParams));
      return ok({ items: result.Items ?? [], total: result.Count ?? 0 });
    }

    // POST /ac/homework
    if (method === 'POST' && path === '/ac/homework') {
      const id = uuidv4();
      const item = {
        PK: `HW#${id}`,
        SK: 'METADATA',
        GSI1PK: `TENANT#${tenantId}`,
        GSI1SK: `BATCH#${body.batchId}#HW#${id}`,
        id,
        tenantId,
        batchId: body.batchId,
        subject: body.subject,
        title: body.title,
        description: body.description,
        dueDate: body.dueDate,
        createdBy: userId,
        createdAt: new Date().toISOString(),
        submissionCount: 0,
      };
      await ddb.send(new PutCommand({ TableName: TABLE, Item: item }));
      return ok(item, 201);
    }

    // GET /ac/homework/{homeworkId}
    if (method === 'GET' && path.includes('/ac/homework/')) {
      const homeworkId = path.split('/').pop()!;
      const result = await ddb.send(new GetCommand({ TableName: TABLE, Key: { PK: `HW#${homeworkId}`, SK: 'METADATA' } }));
      if (!result.Item) return err('Homework not found', 404);
      return ok(result.Item);
    }

    // GET /ac/homework/submissions
    if (method === 'GET' && path === '/ac/homework/submissions') {
      const homeworkId = params.homeworkId;
      const result = await ddb.send(new QueryCommand({
        TableName: TABLE,
        IndexName: 'GSI1',
        KeyConditionExpression: 'GSI1PK = :pk AND begins_with(GSI1SK, :sk)',
        ExpressionAttributeValues: { ':pk': `HW#${homeworkId}`, ':sk': 'SUBMISSION#' },
      }));
      return ok({ items: result.Items ?? [], total: result.Count ?? 0 });
    }

    // POST /ac/homework/{homeworkId}/submit
    if (method === 'POST' && path.includes('/submit')) {
      const homeworkId = path.split('/')[3];
      const subId = uuidv4();
      const submission = {
        PK: `HW#${homeworkId}`,
        SK: `SUBMISSION#${subId}`,
        GSI1PK: `STUDENT#${userId}`,
        GSI1SK: `SUBMISSION#${new Date().toISOString()}`,
        id: subId,
        homeworkId,
        studentId: userId,
        fileUrl: body.fileUrl,
        notes: body.notes,
        submittedAt: new Date().toISOString(),
        status: 'submitted',
      };
      await ddb.send(new PutCommand({ TableName: TABLE, Item: submission }));
      return ok(submission, 201);
    }

    // POST /ac/homework/submissions/{submissionId}/grade
    if (method === 'POST' && path.includes('/grade')) {
      const parts = path.split('/');
      const submissionId = parts[parts.length - 2];
      const homeworkId = params.homeworkId ?? '';
      await ddb.send(new UpdateCommand({
        TableName: TABLE,
        Key: { PK: `HW#${homeworkId}`, SK: `SUBMISSION#${submissionId}` },
        UpdateExpression: 'SET grade = :g, feedback = :f, gradedAt = :t, gradedBy = :u',
        ExpressionAttributeValues: { ':g': body.grade, ':f': body.feedback ?? '', ':t': new Date().toISOString(), ':u': userId },
      }));
      return ok({ message: 'Graded successfully' });
    }

    return err('Not found', 404);
  } catch (e: any) {
    console.error('school-homework error:', e);
    return err(e.message ?? 'Internal server error', 500);
  }
};
