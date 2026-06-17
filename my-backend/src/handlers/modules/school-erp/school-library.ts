import { configureAwsClient } from '../../../config/aws.config';
import { APIGatewayProxyHandlerV2 } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, GetCommand, QueryCommand, UpdateCommand, ScanCommand } from '@aws-sdk/lib-dynamodb';
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
    // GET /ac/library — overview stats
    if (method === 'GET' && path === '/ac/library') {
      const booksResult = await ddb.send(new QueryCommand({
        TableName: TABLE,
        IndexName: 'GSI1',
        KeyConditionExpression: 'GSI1PK = :pk AND begins_with(GSI1SK, :sk)',
        ExpressionAttributeValues: { ':pk': `TENANT#${tenantId}`, ':sk': 'BOOK#' },
        Select: 'COUNT',
      }));
      const issuedResult = await ddb.send(new QueryCommand({
        TableName: TABLE,
        IndexName: 'GSI1',
        KeyConditionExpression: 'GSI1PK = :pk AND begins_with(GSI1SK, :sk)',
        FilterExpression: '#s = :s',
        ExpressionAttributeNames: { '#s': 'status' },
        ExpressionAttributeValues: { ':pk': `TENANT#${tenantId}`, ':sk': 'ISSUE#', ':s': 'issued' },
      }));
      const overdue = (issuedResult.Items ?? []).filter((i: any) => new Date(i.dueDate) < new Date());
      return ok({
        totalBooks: booksResult.Count ?? 0,
        issuedBooks: issuedResult.Count ?? 0,
        availableBooks: (booksResult.Count ?? 0) - (issuedResult.Count ?? 0),
        overdueBooks: overdue.length,
        recentIssues: issuedResult.Items?.slice(0, 5) ?? [],
      });
    }

    // POST /ac/library/issue
    if (method === 'POST' && path === '/ac/library/issue') {
      const id = uuidv4();
      const dueDate = new Date(); dueDate.setDate(dueDate.getDate() + 14);
      const issue = {
        PK: `ISSUE#${id}`,
        SK: 'METADATA',
        GSI1PK: `TENANT#${tenantId}`,
        GSI1SK: `ISSUE#${new Date().toISOString()}`,
        id, tenantId,
        bookId: body.bookId,
        bookTitle: body.bookTitle,
        studentId: body.studentId,
        studentName: body.studentName,
        issuedDate: new Date().toISOString().split('T')[0],
        dueDate: body.dueDate ?? dueDate.toISOString().split('T')[0],
        issuedBy: userId,
        status: 'issued',
        isOverdue: false,
      };
      await ddb.send(new PutCommand({ TableName: TABLE, Item: issue }));
      // Update book availability
      await ddb.send(new UpdateCommand({ TableName: TABLE, Key: { PK: `BOOK#${body.bookId}`, SK: 'METADATA' }, UpdateExpression: 'SET availableCopies = availableCopies - :v', ExpressionAttributeValues: { ':v': 1 } }));
      return ok(issue, 201);
    }

    // POST /ac/library/return
    if (method === 'POST' && path === '/ac/library/return') {
      const { issueId, bookId } = body;
      await ddb.send(new UpdateCommand({ TableName: TABLE, Key: { PK: `ISSUE#${issueId}`, SK: 'METADATA' }, UpdateExpression: 'SET #s = :s, returnedDate = :d', ExpressionAttributeNames: { '#s': 'status' }, ExpressionAttributeValues: { ':s': 'returned', ':d': new Date().toISOString().split('T')[0] } }));
      await ddb.send(new UpdateCommand({ TableName: TABLE, Key: { PK: `BOOK#${bookId}`, SK: 'METADATA' }, UpdateExpression: 'SET availableCopies = availableCopies + :v', ExpressionAttributeValues: { ':v': 1 } }));
      return ok({ message: 'Book returned successfully' });
    }

    return err('Not found', 404);
  } catch (e: any) {
    console.error('school-library error:', e);
    return err(e.message ?? 'Internal server error', 500);
  }
};
