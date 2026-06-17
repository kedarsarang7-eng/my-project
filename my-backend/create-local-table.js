const { DynamoDBClient, CreateTableCommand, ListTablesCommand } = require("@aws-sdk/client-dynamodb");

const client = new DynamoDBClient({
    region: "ap-south-1",
    endpoint: "http://localhost:4566",
    credentials: {
        accessKeyId: "test",
        secretAccessKey: "test"
    }
});

async function run() {
    try {
        console.log("Checking existing tables...");
        const listRes = await client.send(new ListTablesCommand({}));
        console.log("Existing tables:", listRes.TableNames);
        if (listRes.TableNames.includes("DukanX-dev")) {
            console.log("Table 'DukanX-dev' already exists.");
            return;
        }

        console.log("Creating table 'DukanX-dev'...");
        await client.send(new CreateTableCommand({
            TableName: "DukanX-dev",
            AttributeDefinitions: [
                { AttributeName: "PK", AttributeType: "S" },
                { AttributeName: "SK", AttributeType: "S" },
                { AttributeName: "GSI1PK", AttributeType: "S" },
                { AttributeName: "GSI1SK", AttributeType: "S" },
                { AttributeName: "GSI2PK", AttributeType: "S" },
                { AttributeName: "GSI2SK", AttributeType: "S" }
            ],
            KeySchema: [
                { AttributeName: "PK", KeyType: "HASH" },
                { AttributeName: "SK", KeyType: "RANGE" }
            ],
            GlobalSecondaryIndexes: [
                {
                    IndexName: "GSI1",
                    KeySchema: [
                        { AttributeName: "GSI1PK", KeyType: "HASH" },
                        { AttributeName: "GSI1SK", KeyType: "RANGE" }
                    ],
                    Projection: { ProjectionType: "ALL" }
                },
                {
                    IndexName: "GSI2",
                    KeySchema: [
                        { AttributeName: "GSI2PK", KeyType: "HASH" },
                        { AttributeName: "GSI2SK", KeyType: "RANGE" }
                    ],
                    Projection: { ProjectionType: "ALL" }
                }
            ],
            BillingMode: "PAY_PER_REQUEST"
        }));
        console.log("Table 'DukanX-dev' created successfully!");
    } catch (err) {
        console.error("Error creating table:", err);
    }
}

run();
