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

  try {
    // GET /ac/hostel — overview
    if (method === 'GET' && path === '/ac/hostel') {
      const blocksResult = await ddb.send(new QueryCommand({
        TableName: TABLE,
        IndexName: 'GSI1',
        KeyConditionExpression: 'GSI1PK = :pk AND begins_with(GSI1SK, :sk)',
        ExpressionAttributeValues: { ':pk': `TENANT#${tenantId}`, ':sk': 'HOSTEL_BLOCK#' },
      }));
      const blocks = blocksResult.Items ?? [];
      const totalRooms = blocks.reduce((s: number, b: any) => s + (b.totalRooms ?? 0), 0);
      const occupiedRooms = blocks.reduce((s: number, b: any) => s + (b.occupiedRooms ?? 0), 0);
      const totalResidents = blocks.reduce((s: number, b: any) => s + (b.residentCount ?? 0), 0);
      return ok({ blocks, totalRooms, occupiedRooms, totalResidents });
    }

    // GET /ac/hostel/blocks
    if (method === 'GET' && path === '/ac/hostel/blocks') {
      const result = await ddb.send(new QueryCommand({
        TableName: TABLE,
        IndexName: 'GSI1',
        KeyConditionExpression: 'GSI1PK = :pk AND begins_with(GSI1SK, :sk)',
        ExpressionAttributeValues: { ':pk': `TENANT#${tenantId}`, ':sk': 'HOSTEL_BLOCK#' },
      }));
      return ok({ items: result.Items ?? [] });
    }

    // POST /ac/hostel/blocks
    if (method === 'POST' && path === '/ac/hostel/blocks') {
      const id = uuidv4();
      const block = {
        PK: `HOSTEL_BLOCK#${id}`, SK: 'METADATA',
        GSI1PK: `TENANT#${tenantId}`, GSI1SK: `HOSTEL_BLOCK#${id}`,
        id, tenantId,
        name: body.name,
        gender: body.gender ?? 'co-ed',
        totalRooms: body.totalRooms ?? 0,
        occupiedRooms: 0,
        residentCount: 0,
        wardenName: body.wardenName ?? '',
        wardenPhone: body.wardenPhone ?? '',
        createdAt: new Date().toISOString(),
      };
      await ddb.send(new PutCommand({ TableName: TABLE, Item: block }));
      return ok(block, 201);
    }

    // GET /ac/hostel/rooms
    if (method === 'GET' && path === '/ac/hostel/rooms') {
      const result = await ddb.send(new QueryCommand({
        TableName: TABLE,
        IndexName: 'GSI1',
        KeyConditionExpression: 'GSI1PK = :pk AND begins_with(GSI1SK, :sk)',
        ExpressionAttributeValues: { ':pk': `TENANT#${tenantId}`, ':sk': 'HOSTEL_ROOM#' },
      }));
      return ok({ items: result.Items ?? [] });
    }

    // POST /ac/hostel/rooms
    if (method === 'POST' && path === '/ac/hostel/rooms') {
      const id = uuidv4();
      const room = {
        PK: `HOSTEL_ROOM#${id}`, SK: 'METADATA',
        GSI1PK: `TENANT#${tenantId}`, GSI1SK: `HOSTEL_ROOM#${body.blockId}#${id}`,
        id, tenantId,
        blockId: body.blockId,
        roomNumber: body.roomNumber,
        capacity: body.capacity ?? 2,
        occupancy: 0,
        type: body.type ?? 'shared',
        floor: body.floor ?? 1,
        status: 'available',
        createdAt: new Date().toISOString(),
      };
      await ddb.send(new PutCommand({ TableName: TABLE, Item: room }));
      return ok(room, 201);
    }

    // POST /ac/hostel/allocate
    if (method === 'POST' && path === '/ac/hostel/allocate') {
      const id = uuidv4();
      const allocation = {
        PK: `HOSTEL_ALLOC#${id}`, SK: 'METADATA',
        GSI1PK: `TENANT#${tenantId}`, GSI1SK: `HOSTEL_ALLOC#${body.studentId}`,
        id, tenantId,
        studentId: body.studentId,
        studentName: body.studentName ?? '',
        roomId: body.roomId,
        blockId: body.blockId,
        bedNumber: body.bedNumber ?? 1,
        startDate: body.startDate ?? new Date().toISOString().split('T')[0],
        status: 'active',
        allocatedBy: userId,
        allocatedAt: new Date().toISOString(),
      };
      await ddb.send(new PutCommand({ TableName: TABLE, Item: allocation }));
      await ddb.send(new UpdateCommand({ TableName: TABLE, Key: { PK: `HOSTEL_ROOM#${body.roomId}`, SK: 'METADATA' }, UpdateExpression: 'SET occupancy = occupancy + :v', ExpressionAttributeValues: { ':v': 1 } }));
      return ok(allocation, 201);
    }

    // GET /ac/hostel/residents
    if (method === 'GET' && path === '/ac/hostel/residents') {
      const result = await ddb.send(new QueryCommand({
        TableName: TABLE,
        IndexName: 'GSI1',
        KeyConditionExpression: 'GSI1PK = :pk AND begins_with(GSI1SK, :sk)',
        ExpressionAttributeValues: { ':pk': `TENANT#${tenantId}`, ':sk': 'HOSTEL_ALLOC#' },
      }));
      return ok({ items: result.Items ?? [], total: result.Count ?? 0 });
    }

    return err('Not found', 404);
  } catch (e: any) {
    console.error('school-hostel error:', e);
    return err(e.message ?? 'Internal server error', 500);
  }
};
