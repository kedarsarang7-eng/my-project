import { configureAwsClient } from '../../../config/aws.config';
import { APIGatewayProxyHandlerV2 } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, GetCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
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
  const role = claims['custom:role'] ?? 'faculty';
  const body = event.body ? JSON.parse(event.body) : {};
  const params = event.queryStringParameters ?? {};

  try {
    // GET /ac/payslip — list payslips (admin sees all, faculty sees own)
    if (method === 'GET' && path === '/ac/payslip') {
      const facultyId = role === 'admin' ? (params.facultyId ?? null) : userId;
      const month = params.month;

      let queryParams: any;
      if (facultyId) {
        queryParams = {
          TableName: TABLE,
          IndexName: 'GSI1',
          KeyConditionExpression: 'GSI1PK = :pk AND begins_with(GSI1SK, :sk)',
          ExpressionAttributeValues: { ':pk': `FACULTY#${facultyId}`, ':sk': month ? `PAYSLIP#${month}` : 'PAYSLIP#' },
          ScanIndexForward: false,
        };
      } else {
        queryParams = {
          TableName: TABLE,
          IndexName: 'GSI1',
          KeyConditionExpression: 'GSI1PK = :pk AND begins_with(GSI1SK, :sk)',
          ExpressionAttributeValues: { ':pk': `TENANT#${tenantId}`, ':sk': month ? `PAYSLIP#${month}` : 'PAYSLIP#' },
          ScanIndexForward: false,
        };
      }

      const result = await ddb.send(new QueryCommand(queryParams));

      // For admin, also compute aggregate
      if (role === 'admin') {
        const items = result.Items ?? [];
        const currentMonth = month ?? new Date().toISOString().slice(0, 7);
        const currentMonthItems = items.filter((i: any) => i.month === currentMonth);
        return ok({
          staffPayroll: items,
          totalStaff: new Set(items.map((i: any) => i.facultyId)).size,
          currentMonthTotal: currentMonthItems.reduce((s: number, i: any) => s + (i.netSalary ?? 0), 0),
          pendingAmount: currentMonthItems.filter((i: any) => i.paymentStatus !== 'paid').reduce((s: number, i: any) => s + (i.netSalary ?? 0), 0),
          yearToDate: items.filter((i: any) => i.year === new Date().getFullYear().toString()).reduce((s: number, i: any) => s + (i.netSalary ?? 0), 0),
        });
      }

      return ok({ items: result.Items ?? [] });
    }

    // POST /ac/payslip — generate payslip (admin only)
    if (method === 'POST' && path === '/ac/payslip') {
      if (role !== 'admin') return err('Forbidden', 403);
      const id = uuidv4();
      const month = body.month ?? new Date().toISOString().slice(0, 7);
      const gross = (body.basicSalary ?? 0) + (body.hra ?? 0) + (body.allowances ?? 0);
      const deductions = (body.pf ?? 0) + (body.tax ?? 0) + (body.otherDeductions ?? 0);
      const net = gross - deductions;

      const payslip = {
        PK: `PAYSLIP#${id}`, SK: 'METADATA',
        GSI1PK: `FACULTY#${body.facultyId}`, GSI1SK: `PAYSLIP#${month}#${id}`,
        GSI2PK: `TENANT#${tenantId}`, GSI2SK: `PAYSLIP#${month}#${id}`,
        id, tenantId,
        facultyId: body.facultyId,
        firstName: body.firstName ?? '',
        lastName: body.lastName ?? '',
        designation: body.designation ?? '',
        department: body.department ?? '',
        month,
        year: month.split('-')[0],
        basicSalary: body.basicSalary ?? 0,
        hra: body.hra ?? 0,
        allowances: body.allowances ?? 0,
        pf: body.pf ?? 0,
        tax: body.tax ?? 0,
        otherDeductions: body.otherDeductions ?? 0,
        grossSalary: gross,
        totalDeductions: deductions,
        netSalary: net,
        paymentStatus: 'pending',
        generatedBy: userId,
        generatedAt: new Date().toISOString(),
        workingDays: body.workingDays ?? 26,
        presentDays: body.presentDays ?? 26,
      };
      await ddb.send(new PutCommand({ TableName: TABLE, Item: payslip }));
      return ok(payslip, 201);
    }

    // GET /ac/payslip/{payslipId}
    if (method === 'GET' && path.match(/\/ac\/payslip\/[^/]+$/)) {
      const payslipId = path.split('/').pop()!;
      const result = await ddb.send(new GetCommand({ TableName: TABLE, Key: { PK: `PAYSLIP#${payslipId}`, SK: 'METADATA' } }));
      if (!result.Item) return err('Payslip not found', 404);
      return ok(result.Item);
    }

    return err('Not found', 404);
  } catch (e: any) {
    console.error('school-payslip error:', e);
    return err(e.message ?? 'Internal server error', 500);
  }
};
