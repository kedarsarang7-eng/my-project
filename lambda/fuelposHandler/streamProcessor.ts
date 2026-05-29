import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, UpdateCommand, GetCommand, PutCommand } from '@aws-sdk/lib-dynamodb';
import { DynamoDBStreamEvent, DynamoDBRecord } from 'aws-lambda';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

interface TransactionData {
  stationId: string;
  date: string;
  amount: number;
  fuelType: string;
  liters: number;
  status: string;
  hour: number;
}

function extractTransactionData(record: DynamoDBRecord): TransactionData | null {
  const newImage = record.dynamodb?.NewImage;
  if (!newImage) return null;

  // Only process if status is PAID
  const status = newImage.status?.S;
  if (status !== 'PAID') return null;

  const pk = newImage.PK?.S || '';
  const sk = newImage.SK?.S || '';

  // Parse PK: STATION#STN402, SK: TXN#2024-10-26#8432
  const stationId = pk.replace('STATION#', '');
  const skParts = sk.split('#');
  const date = skParts[1] || new Date().toISOString().split('T')[0];
  const timestamp = newImage.timestamp?.S || new Date().toISOString();
  const hour = new Date(timestamp).getHours();

  return {
    stationId,
    date,
    amount: parseFloat(newImage.amount?.N || '0'),
    fuelType: newImage.fuelType?.S || 'Unknown',
    liters: parseFloat(newImage.liters?.N || '0'),
    status,
    hour,
  };
}

async function updateDailySummary(data: TransactionData): Promise<void> {
  const tableName = process.env.DYNAMODB_TABLE_DAILY_SUMMARY || 'FuelPOS_DailySummary';

  try {
    // Check if summary exists
    const existing = await docClient.send(
      new GetCommand({
        TableName: tableName,
        Key: {
          PK: `STATION#${data.stationId}`,
          SK: `DATE#${data.date}`,
        },
      })
    );

    const now = new Date().toISOString();

    if (!existing.Item) {
      // Create new summary
      await docClient.send(
        new PutCommand({
          TableName: tableName,
          Item: {
            PK: `STATION#${data.stationId}`,
            SK: `DATE#${data.date}`,
            stationId: data.stationId,
            date: data.date,
            totalSales: data.amount,
            totalLiters: data.liters,
            petrolLiters: data.fuelType === 'Petrol' ? data.liters : 0,
            dieselLiters: data.fuelType === 'Diesel' ? data.liters : 0,
            transactionCount: 1,
            revenueBySegment: {
              petrol: { amount: data.fuelType === 'Petrol' ? data.amount : 0, percent: data.fuelType === 'Petrol' ? 100 : 0 },
              diesel: { amount: data.fuelType === 'Diesel' ? data.amount : 0, percent: data.fuelType === 'Diesel' ? 100 : 0 },
              lubricants: { amount: 0, percent: 0 },
              shopItems: { amount: 0, percent: 0 },
            },
            createdAt: now,
            updatedAt: now,
            GSI1PK: `MONTH#${data.date.slice(0, 7)}#${data.stationId}`,
            GSI1SK: data.date,
          },
        })
      );
    } else {
      // Update existing summary
      const current = existing.Item;
      const isPetrol = data.fuelType === 'Petrol';
      const isDiesel = data.fuelType === 'Diesel';

      await docClient.send(
        new UpdateCommand({
          TableName: tableName,
          Key: {
            PK: `STATION#${data.stationId}`,
            SK: `DATE#${data.date}`,
          },
          UpdateExpression: 'SET totalSales = totalSales + :amount, totalLiters = totalLiters + :liters, transactionCount = transactionCount + :one, updatedAt = :now, petrolLiters = petrolLiters + :petrolLiters, dieselLiters = dieselLiters + :dieselLiters',
          ExpressionAttributeValues: {
            ':amount': data.amount,
            ':liters': data.liters,
            ':one': 1,
            ':now': now,
            ':petrolLiters': isPetrol ? data.liters : 0,
            ':dieselLiters': isDiesel ? data.liters : 0,
          },
        })
      );
    }
  } catch (error) {
    console.error('Error updating daily summary:', error);
    throw error;
  }
}

async function updateFuelChart(data: TransactionData): Promise<void> {
  const tableName = process.env.DYNAMODB_TABLE_FUEL_CHART || 'FuelPOS_FuelChart';

  try {
    const now = new Date().toISOString();

    await docClient.send(
      new UpdateCommand({
        TableName: tableName,
        Key: {
          PK: `STATION#${data.stationId}#DATE#${data.date}`,
          SK: `HOUR#${data.hour}`,
        },
        UpdateExpression: 'SET stationId = :stationId, #date = :date, #hour = :hour, hourLabel = :hourLabel, updatedAt = :now ADD petrolLiters :petrolLiters, dieselLiters :dieselLiters, transactionCount :one',
        ExpressionAttributeNames: {
          '#date': 'date',
          '#hour': 'hour',
        },
        ExpressionAttributeValues: {
          ':stationId': data.stationId,
          ':date': data.date,
          ':hour': data.hour,
          ':hourLabel': `${data.hour.toString().padStart(2, '0')}:00`,
          ':now': now,
          ':petrolLiters': data.fuelType === 'Petrol' ? data.liters : 0,
          ':dieselLiters': data.fuelType === 'Diesel' ? data.liters : 0,
          ':one': 1,
        },
      })
    );
  } catch (error) {
    console.error('Error updating fuel chart:', error);
    throw error;
  }
}

export const handler = async (event: DynamoDBStreamEvent): Promise<void> => {
  console.log(`Processing ${event.Records.length} stream records`);

  for (const record of event.Records) {
    try {
      // Only process INSERT and MODIFY events where status changed to PAID
      if (record.eventName !== 'INSERT' && record.eventName !== 'MODIFY') {
        continue;
      }

      const data = extractTransactionData(record);
      if (!data) {
        continue;
      }

      console.log('Processing transaction:', {
        stationId: data.stationId,
        date: data.date,
        amount: data.amount,
        fuelType: data.fuelType,
      });

      // Update aggregations in parallel
      await Promise.all([
        updateDailySummary(data),
        updateFuelChart(data),
      ]);
    } catch (error) {
      console.error('Error processing record:', error);
      // Continue processing other records
    }
  }
};
