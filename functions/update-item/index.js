const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, UpdateCommand } = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient({
    region: process.env.AWS_REGION || 'us-east-1'
});
const docClient = DynamoDBDocumentClient.from(client);

const TABLE_NAME = process.env.DYNAMODB_TABLE_NAME;

exports.handler = async (event, context) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    try {
        const itemId = event.pathParameters?.id;
        
        if (!itemId) {
            return {
                statusCode: 400,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Requested-With'
                },
                body: JSON.stringify({
                    error: 'Bad Request',
                    message: 'Item ID is required'
                })
            };
        }
        
        const requestBody = JSON.parse(event.body || '{}');
        const timestamp = new Date().toISOString();
        
        // Build update expression
        const updateExpressions = [];
        const expressionAttributeNames = {};
        const expressionAttributeValues = {};
        
        updateExpressions.push('#updatedAt = :updatedAt');
        expressionAttributeNames['#updatedAt'] = 'updatedAt';
        expressionAttributeValues[':updatedAt'] = timestamp;
        
        if (requestBody.name !== undefined) {
            updateExpressions.push('#name = :name');
            expressionAttributeNames['#name'] = 'name';
            expressionAttributeValues[':name'] = requestBody.name;
        }
        
        if (requestBody.description !== undefined) {
            updateExpressions.push('#description = :description');
            expressionAttributeNames['#description'] = 'description';
            expressionAttributeValues[':description'] = requestBody.description;
        }
        
        if (requestBody.category !== undefined) {
            updateExpressions.push('#category = :category');
            expressionAttributeNames['#category'] = 'category';
            expressionAttributeValues[':category'] = requestBody.category;
        }
        
        if (requestBody.price !== undefined) {
            updateExpressions.push('#price = :price');
            expressionAttributeNames['#price'] = 'price';
            expressionAttributeValues[':price'] = requestBody.price;
        }
        
        const command = new UpdateCommand({
            TableName: TABLE_NAME,
            Key: { id: itemId },
            UpdateExpression: `SET ${updateExpressions.join(', ')}`,
            ExpressionAttributeNames: expressionAttributeNames,
            ExpressionAttributeValues: expressionAttributeValues,
            ConditionExpression: 'attribute_exists(id)',
            ReturnValues: 'ALL_NEW'
        });
        
        const result = await docClient.send(command);
        
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Requested-With'
            },
            body: JSON.stringify(result.Attributes)
        };
        
    } catch (error) {
        console.error('Error:', error);
        
        if (error.name === 'ConditionalCheckFailedException') {
            return {
                statusCode: 404,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Requested-With'
                },
                body: JSON.stringify({
                    error: 'Not Found',
                    message: 'Item not found'
                })
            };
        }
        
        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Requested-With'
            },
            body: JSON.stringify({
                error: 'Internal Server Error',
                message: 'An error occurred while processing your request'
            })
        };
    }
};