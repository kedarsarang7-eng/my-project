import { APIGatewayProxyHandlerV2 } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand, PutCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const TABLE = process.env.DYNAMODB_TABLE!;

const ok = (body: unknown, status = 200) => ({ statusCode: status, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }, body: JSON.stringify(body) });
const err = (msg: string, status = 400) => ({ statusCode: status, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }, body: JSON.stringify({ message: msg }) });

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  const method = event.requestContext.http.method;
  const path = event.rawPath;
  const claims = (event.requestContext as any).authorizer?.jwt?.claims ?? {};
  const tenantId = claims['custom:tenantId'] ?? 'default';
  const role = claims['custom:role'] ?? '';
  const body = event.body ? JSON.parse(event.body) : {};

  try {
    // GET /ac/config
    if (method === 'GET' && path === '/ac/config') {
      const result = await ddb.send(new GetCommand({ TableName: TABLE, Key: { PK: `TENANT#${tenantId}`, SK: 'CONFIG' } }));
      const config = result.Item ?? {
        institutionName: 'My Institution',
        address: '',
        phone: '',
        email: '',
        board: '',
        affiliationNo: '',
        logoUrl: null,
        currency: 'INR',
        timezone: 'Asia/Kolkata',
        academicYearStart: 'April',
        workingDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        schoolStartTime: '08:00',
        schoolEndTime: '15:00',
        modules: { transport: true, library: true, hostel: false, payroll: true },
      };
      return ok(config);
    }

    // PUT /ac/config — admin only
    if (method === 'PUT' && path === '/ac/config') {
      if (role !== 'admin') return err('Forbidden', 403);
      const existing = (await ddb.send(new GetCommand({ TableName: TABLE, Key: { PK: `TENANT#${tenantId}`, SK: 'CONFIG' } }))).Item ?? {};
      const updated = {
        ...existing,
        ...body,
        PK: `TENANT#${tenantId}`,
        SK: 'CONFIG',
        tenantId,
        updatedAt: new Date().toISOString(),
      };
      await ddb.send(new PutCommand({ TableName: TABLE, Item: updated }));
      return ok(updated);
    }

    // GET /ac/config/academic-year
    if (method === 'GET' && path === '/ac/config/academic-year') {
      const result = await ddb.send(new GetCommand({ TableName: TABLE, Key: { PK: `TENANT#${tenantId}`, SK: 'ACADEMIC_YEAR' } }));
      const now = new Date();
      const currentYear = now.getMonth() >= 3 ? now.getFullYear() : now.getFullYear() - 1;
      return ok(result.Item ?? {
        current: `${currentYear}-${currentYear + 1}`,
        startDate: `${currentYear}-04-01`,
        endDate: `${currentYear + 1}-03-31`,
        terms: [
          { name: 'Term 1', startDate: `${currentYear}-04-01`, endDate: `${currentYear}-09-30` },
          { name: 'Term 2', startDate: `${currentYear}-10-01`, endDate: `${currentYear + 1}-03-31` },
        ],
      });
    }

    // PUT /ac/config/academic-year
    if (method === 'PUT' && path === '/ac/config/academic-year') {
      if (role !== 'admin') return err('Forbidden', 403);
      await ddb.send(new PutCommand({
        TableName: TABLE,
        Item: { PK: `TENANT#${tenantId}`, SK: 'ACADEMIC_YEAR', tenantId, ...body, updatedAt: new Date().toISOString() },
      }));
      return ok({ message: 'Academic year updated' });
    }

    return err('Not found', 404);
  } catch (e: any) {
    console.error('school-config error:', e);
    return err(e.message ?? 'Internal server error', 500);
  }
};
