// Mock environment variables BEFORE importing the handler
process.env.DYNAMODB_TABLE_NAME = 'test-items-table';
process.env.AWS_REGION = 'us-east-1';

const { mockClient } = require('aws-sdk-client-mock');
const { DynamoDBDocumentClient, GetCommand } = require('@aws-sdk/lib-dynamodb');
const { handler } = require('./index');

// Mock the DynamoDB client
const ddbMock = mockClient(DynamoDBDocumentClient);

describe('Get Item Lambda Function', () => {
    beforeEach(() => {
        ddbMock.reset();
        jest.clearAllMocks();
    });

    const mockContext = {
        awsRequestId: 'test-request-id',
        functionName: 'test-get-item-function'
    };

    const validItemId = '123e4567-e89b-42d3-a456-426614174000';
    const mockItem = {
        id: validItemId,
        name: 'Test Item',
        description: 'A test item',
        category: 'electronics',
        price: 99.99,
        createdAt: '2023-01-01T00:00:00.000Z',
        updatedAt: '2023-01-01T00:00:00.000Z'
    };

    describe('Successful item retrieval', () => {
        test('should return item when found in database', async () => {
            // Arrange
            const event = {
                httpMethod: 'GET',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                }
            };

            ddbMock.on(GetCommand).resolves({
                Item: mockItem
            });

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(200);
            expect(JSON.parse(result.body)).toEqual(mockItem);
            expect(result.headers['Content-Type']).toBe('application/json');
            expect(result.headers['Access-Control-Allow-Origin']).toBe('*');

            // Verify DynamoDB was called correctly
            expect(ddbMock.commandCalls(GetCommand)).toHaveLength(1);
            expect(ddbMock.commandCalls(GetCommand)[0].args[0].input).toEqual({
                TableName: 'test-items-table',
                Key: {
                    id: validItemId
                }
            });
        });

        test('should handle item with minimal fields', async () => {
            // Arrange
            const minimalItem = {
                id: validItemId,
                name: 'Minimal Item',
                category: 'books',
                price: 10.00,
                createdAt: '2023-01-01T00:00:00.000Z',
                updatedAt: '2023-01-01T00:00:00.000Z'
            };

            const event = {
                httpMethod: 'GET',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                }
            };

            ddbMock.on(GetCommand).resolves({
                Item: minimalItem
            });

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(200);
            expect(JSON.parse(result.body)).toEqual(minimalItem);
        });
    });

    describe('Item not found scenarios', () => {
        test('should return 404 when item does not exist', async () => {
            // Arrange
            const event = {
                httpMethod: 'GET',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                }
            };

            ddbMock.on(GetCommand).resolves({
                // No Item property means item not found
            });

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(404);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Not Found');
            expect(responseBody.message).toBe(`Item with id '${validItemId}' not found`);
            expect(responseBody.requestId).toBe('test-request-id');
            expect(responseBody.timestamp).toBeDefined();
        });

        test('should return 404 when item is null', async () => {
            // Arrange
            const event = {
                httpMethod: 'GET',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                }
            };

            ddbMock.on(GetCommand).resolves({
                Item: null
            });

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(404);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Not Found');
        });
    });

    describe('Validation error scenarios', () => {
        test('should return 400 when item ID is missing', async () => {
            // Arrange
            const event = {
                httpMethod: 'GET',
                resource: '/items/{id}',
                pathParameters: null
            };

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(400);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Validation Error');
            expect(responseBody.message).toBe('Item ID is required');
            expect(responseBody.details).toContain('id: Item ID must be provided in the URL path');
        });

        test('should return 400 when path parameters is empty object', async () => {
            // Arrange
            const event = {
                httpMethod: 'GET',
                resource: '/items/{id}',
                pathParameters: {}
            };

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(400);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Validation Error');
            expect(responseBody.message).toBe('Item ID is required');
        });

        test('should return 400 when item ID is not a valid UUID', async () => {
            // Arrange
            const invalidIds = [
                'invalid-id',
                '123',
                'not-a-uuid',
                '123e4567-e89b-42d3-a456-42661417400', // too short
                '123e4567-e89b-42d3-a456-4266141740000', // too long
                '123e4567-e89b-22d3-a456-426614174000', // invalid version (should be 4)
                '123e4567-e89b-42d3-c456-426614174000', // invalid variant (should be 8,9,a,b)
                ''
            ];

            for (const invalidId of invalidIds) {
                const event = {
                    httpMethod: 'GET',
                    resource: '/items/{id}',
                    pathParameters: {
                        id: invalidId
                    }
                };

                // Act
                const result = await handler(event, mockContext);

                // Assert
                expect(result.statusCode).toBe(400);
                const responseBody = JSON.parse(result.body);
                expect(responseBody.error).toBe('Validation Error');
                
                // Empty string is treated as missing ID, not invalid format
                if (invalidId === '') {
                    expect(responseBody.message).toBe('Invalid item ID');
                    expect(responseBody.details).toContain('id: Item ID is required and must be a string');
                } else {
                    expect(responseBody.message).toBe('Invalid item ID format');
                    expect(responseBody.details).toContain('id: Item ID must be a valid UUID v4');
                }
            }
        });
    });

    describe('DynamoDB error handling', () => {
        test('should return 500 when DynamoDB table does not exist', async () => {
            // Arrange
            const event = {
                httpMethod: 'GET',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                }
            };

            const error = new Error('Table not found');
            error.name = 'ResourceNotFoundException';
            ddbMock.on(GetCommand).rejects(error);

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(500);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Internal Server Error');
            expect(responseBody.message).toBe('Database configuration error');
            expect(responseBody.requestId).toBe('test-request-id');
        });

        test('should return 503 when DynamoDB throughput is exceeded', async () => {
            // Arrange
            const event = {
                httpMethod: 'GET',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                }
            };

            const error = new Error('Throughput exceeded');
            error.name = 'ProvisionedThroughputExceededException';
            ddbMock.on(GetCommand).rejects(error);

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(503);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Service Unavailable');
            expect(responseBody.message).toBe('Database is temporarily unavailable. Please try again later.');
            expect(responseBody.requestId).toBe('test-request-id');
        });

        test('should return 500 for generic DynamoDB errors', async () => {
            // Arrange
            const event = {
                httpMethod: 'GET',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                }
            };

            const error = new Error('Generic DynamoDB error');
            error.name = 'InternalServerError';
            ddbMock.on(GetCommand).rejects(error);

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(500);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Internal Server Error');
            expect(responseBody.message).toBe('An unexpected error occurred while retrieving the item');
            expect(responseBody.requestId).toBe('test-request-id');
        });

        test('should return 500 for unexpected errors', async () => {
            // Arrange
            const event = {
                httpMethod: 'GET',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                }
            };

            const error = new Error('Unexpected error');
            ddbMock.on(GetCommand).rejects(error);

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(500);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Internal Server Error');
            expect(responseBody.message).toBe('An unexpected error occurred while retrieving the item');
        });
    });

    describe('Edge cases', () => {
        test('should handle event with undefined pathParameters', async () => {
            // Arrange
            const event = {
                httpMethod: 'GET',
                resource: '/items/{id}',
                pathParameters: undefined
            };

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(400);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Validation Error');
            expect(responseBody.message).toBe('Item ID is required');
        });

        test('should handle valid UUID v4 with different cases', async () => {
            // Arrange
            const upperCaseId = '123E4567-E89B-42D3-A456-426614174000';
            const lowerCaseId = '123e4567-e89b-42d3-a456-426614174000';
            
            const event = {
                httpMethod: 'GET',
                resource: '/items/{id}',
                pathParameters: {
                    id: upperCaseId
                }
            };

            ddbMock.on(GetCommand).resolves({
                Item: { ...mockItem, id: upperCaseId }
            });

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(200);
            
            // Verify DynamoDB was called with the original case
            expect(ddbMock.commandCalls(GetCommand)[0].args[0].input.Key.id).toBe(upperCaseId);
        });

        test('should include CORS headers in all responses', async () => {
            // Test successful response
            const successEvent = {
                httpMethod: 'GET',
                resource: '/items/{id}',
                pathParameters: { id: validItemId }
            };

            ddbMock.on(GetCommand).resolves({ Item: mockItem });
            const successResult = await handler(successEvent, mockContext);
            
            expect(successResult.headers['Access-Control-Allow-Origin']).toBe('*');
            expect(successResult.headers['Access-Control-Allow-Headers']).toBeDefined();
            expect(successResult.headers['Access-Control-Allow-Methods']).toBeDefined();

            // Test error response
            ddbMock.reset();
            const errorEvent = {
                httpMethod: 'GET',
                resource: '/items/{id}',
                pathParameters: { id: 'invalid-id' }
            };

            const errorResult = await handler(errorEvent, mockContext);
            expect(errorResult.headers['Access-Control-Allow-Origin']).toBe('*');
        });
    });
});