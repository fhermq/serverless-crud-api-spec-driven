// Mock environment variables BEFORE importing the handler
process.env.DYNAMODB_TABLE_NAME = 'test-items-table';
process.env.AWS_REGION = 'us-east-1';

const { mockClient } = require('aws-sdk-client-mock');
const { DynamoDBDocumentClient, UpdateCommand } = require('@aws-sdk/lib-dynamodb');
const { handler } = require('./index');

// Mock the DynamoDB client
const ddbMock = mockClient(DynamoDBDocumentClient);

describe('Update Item Lambda Function', () => {
    beforeEach(() => {
        ddbMock.reset();
        jest.clearAllMocks();
    });

    const mockContext = {
        awsRequestId: 'test-request-id',
        functionName: 'test-update-item-function'
    };

    const validItemId = '123e4567-e89b-42d3-a456-426614174000';
    const mockUpdatedItem = {
        id: validItemId,
        name: 'Updated Item Name',
        description: 'Updated description',
        category: 'electronics',
        price: 149.99,
        createdAt: '2023-01-01T00:00:00.000Z',
        updatedAt: '2023-01-02T12:00:00.000Z'
    };

    describe('Successful item updates', () => {
        test('should update all fields when provided', async () => {
            // Arrange
            const updateData = {
                name: 'Updated Item Name',
                description: 'Updated description',
                category: 'electronics',
                price: 149.99
            };

            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: JSON.stringify(updateData)
            };

            ddbMock.on(UpdateCommand).resolves({
                Attributes: mockUpdatedItem
            });

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(200);
            expect(JSON.parse(result.body)).toEqual(mockUpdatedItem);
            expect(result.headers['Content-Type']).toBe('application/json');
            expect(result.headers['Access-Control-Allow-Origin']).toBe('*');

            // Verify DynamoDB was called correctly
            expect(ddbMock.commandCalls(UpdateCommand)).toHaveLength(1);
            const updateCall = ddbMock.commandCalls(UpdateCommand)[0].args[0].input;
            expect(updateCall.TableName).toBe('test-items-table');
            expect(updateCall.Key).toEqual({ id: validItemId });
            expect(updateCall.ConditionExpression).toBe('attribute_exists(id)');
            expect(updateCall.ReturnValues).toBe('ALL_NEW');
            expect(updateCall.UpdateExpression).toContain('SET');
            expect(updateCall.UpdateExpression).toContain('#name = :name');
            expect(updateCall.UpdateExpression).toContain('#description = :description');
            expect(updateCall.UpdateExpression).toContain('#category = :category');
            expect(updateCall.UpdateExpression).toContain('#price = :price');
            expect(updateCall.UpdateExpression).toContain('#updatedAt = :updatedAt');
        });

        test('should update only name field when provided', async () => {
            // Arrange
            const updateData = {
                name: 'New Name Only'
            };

            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: JSON.stringify(updateData)
            };

            const partiallyUpdatedItem = {
                ...mockUpdatedItem,
                name: 'New Name Only'
            };

            ddbMock.on(UpdateCommand).resolves({
                Attributes: partiallyUpdatedItem
            });

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(200);
            expect(JSON.parse(result.body)).toEqual(partiallyUpdatedItem);

            // Verify only name and updatedAt are in the update expression
            const updateCall = ddbMock.commandCalls(UpdateCommand)[0].args[0].input;
            expect(updateCall.UpdateExpression).toContain('#name = :name');
            expect(updateCall.UpdateExpression).toContain('#updatedAt = :updatedAt');
            expect(updateCall.UpdateExpression).not.toContain('#description');
            expect(updateCall.UpdateExpression).not.toContain('#category');
            expect(updateCall.UpdateExpression).not.toContain('#price');
        });

        test('should update only price field when provided', async () => {
            // Arrange
            const updateData = {
                price: 99.99
            };

            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: JSON.stringify(updateData)
            };

            const partiallyUpdatedItem = {
                ...mockUpdatedItem,
                price: 99.99
            };

            ddbMock.on(UpdateCommand).resolves({
                Attributes: partiallyUpdatedItem
            });

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(200);
            expect(JSON.parse(result.body)).toEqual(partiallyUpdatedItem);

            // Verify only price and updatedAt are in the update expression
            const updateCall = ddbMock.commandCalls(UpdateCommand)[0].args[0].input;
            expect(updateCall.UpdateExpression).toContain('#price = :price');
            expect(updateCall.UpdateExpression).toContain('#updatedAt = :updatedAt');
            expect(updateCall.ExpressionAttributeValues[':price']).toBe(99.99);
        });

        test('should update description to empty string when provided', async () => {
            // Arrange
            const updateData = {
                description: ''
            };

            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: JSON.stringify(updateData)
            };

            const partiallyUpdatedItem = {
                ...mockUpdatedItem,
                description: ''
            };

            ddbMock.on(UpdateCommand).resolves({
                Attributes: partiallyUpdatedItem
            });

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(200);
            expect(JSON.parse(result.body)).toEqual(partiallyUpdatedItem);

            // Verify description is updated to empty string
            const updateCall = ddbMock.commandCalls(UpdateCommand)[0].args[0].input;
            expect(updateCall.ExpressionAttributeValues[':description']).toBe('');
        });

        test('should handle multiple field updates', async () => {
            // Arrange
            const updateData = {
                name: 'Multi-field Update',
                category: 'books'
            };

            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: JSON.stringify(updateData)
            };

            const partiallyUpdatedItem = {
                ...mockUpdatedItem,
                name: 'Multi-field Update',
                category: 'books'
            };

            ddbMock.on(UpdateCommand).resolves({
                Attributes: partiallyUpdatedItem
            });

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(200);
            expect(JSON.parse(result.body)).toEqual(partiallyUpdatedItem);

            // Verify both fields are updated
            const updateCall = ddbMock.commandCalls(UpdateCommand)[0].args[0].input;
            expect(updateCall.UpdateExpression).toContain('#name = :name');
            expect(updateCall.UpdateExpression).toContain('#category = :category');
            expect(updateCall.ExpressionAttributeValues[':name']).toBe('Multi-field Update');
            expect(updateCall.ExpressionAttributeValues[':category']).toBe('books');
        });
    });

    describe('Item not found scenarios', () => {
        test('should return 404 when item does not exist', async () => {
            // Arrange
            const updateData = {
                name: 'Updated Name'
            };

            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: JSON.stringify(updateData)
            };

            const error = new Error('Conditional check failed');
            error.name = 'ConditionalCheckFailedException';
            ddbMock.on(UpdateCommand).rejects(error);

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
    });

    describe('Validation error scenarios', () => {
        test('should return 400 when item ID is missing', async () => {
            // Arrange
            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: null,
                body: JSON.stringify({ name: 'Test' })
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

        test('should return 400 when item ID is not a valid UUID', async () => {
            // Arrange
            const invalidIds = [
                'invalid-id',
                '123',
                'not-a-uuid',
                '123e4567-e89b-42d3-a456-42661417400', // too short
                '123e4567-e89b-22d3-a456-426614174000', // invalid version
                ''
            ];

            for (const invalidId of invalidIds) {
                const event = {
                    httpMethod: 'PUT',
                    resource: '/items/{id}',
                    pathParameters: {
                        id: invalidId
                    },
                    body: JSON.stringify({ name: 'Test' })
                };

                // Act
                const result = await handler(event, mockContext);

                // Assert
                expect(result.statusCode).toBe(400);
                const responseBody = JSON.parse(result.body);
                expect(responseBody.error).toBe('Validation Error');
            }
        });

        test('should return 400 when request body is invalid JSON', async () => {
            // Arrange
            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: 'invalid json {'
            };

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(400);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Validation Error');
            expect(responseBody.message).toBe('Invalid JSON in request body');
            expect(responseBody.details).toContain('body: Request body must be valid JSON');
        });

        test('should return 400 when no fields are provided for update', async () => {
            // Arrange
            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: JSON.stringify({})
            };

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(400);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Validation Error');
            expect(responseBody.message).toBe('Validation failed');
            expect(responseBody.details).toContain('body: At least one field (name, description, category, price) must be provided for update');
        });

        test('should return 400 when name is too long', async () => {
            // Arrange
            const longName = 'a'.repeat(101); // Exceeds 100 character limit
            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: JSON.stringify({ name: longName })
            };

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(400);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Validation Error');
            expect(responseBody.details).toContain('name: Name must not exceed 100 characters');
        });

        test('should return 400 when name is empty string', async () => {
            // Arrange
            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: JSON.stringify({ name: '' })
            };

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(400);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Validation Error');
            expect(responseBody.details).toContain('name: Name must be at least 1 character long');
        });

        test('should return 400 when description is too long', async () => {
            // Arrange
            const longDescription = 'a'.repeat(501); // Exceeds 500 character limit
            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: JSON.stringify({ description: longDescription })
            };

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(400);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Validation Error');
            expect(responseBody.details).toContain('description: Description must not exceed 500 characters');
        });

        test('should return 400 when category is invalid', async () => {
            // Arrange
            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: JSON.stringify({ category: 'invalid-category' })
            };

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(400);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Validation Error');
            expect(responseBody.details).toContain('category: Category must be one of: electronics, clothing, books, home, sports, other');
        });

        test('should return 400 when price is negative', async () => {
            // Arrange
            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: JSON.stringify({ price: -10.00 })
            };

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(400);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Validation Error');
            expect(responseBody.details).toContain('price: Price must be at least 0.01');
        });

        test('should return 400 when price is not a number', async () => {
            // Arrange
            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: JSON.stringify({ price: 'not-a-number' })
            };

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(400);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Validation Error');
            expect(responseBody.details).toContain('price: Price must be a number');
        });

        test('should return 400 when unexpected fields are provided', async () => {
            // Arrange
            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: JSON.stringify({
                    name: 'Valid Name',
                    unexpectedField: 'should not be here',
                    anotherBadField: 'also bad'
                })
            };

            // No need to mock DynamoDB since validation should fail before reaching it

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(400);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Validation Error');
            expect(responseBody.details).toContain('body: Unexpected fields: unexpectedField, anotherBadField');
        });
    });

    describe('DynamoDB error handling', () => {
        test('should return 500 when DynamoDB table does not exist', async () => {
            // Arrange
            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: JSON.stringify({ name: 'Test' })
            };

            const error = new Error('Table not found');
            error.name = 'ResourceNotFoundException';
            ddbMock.on(UpdateCommand).rejects(error);

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
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: JSON.stringify({ name: 'Test' })
            };

            const error = new Error('Throughput exceeded');
            error.name = 'ProvisionedThroughputExceededException';
            ddbMock.on(UpdateCommand).rejects(error);

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
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: JSON.stringify({ name: 'Test' })
            };

            const error = new Error('Generic DynamoDB error');
            error.name = 'InternalServerError';
            ddbMock.on(UpdateCommand).rejects(error);

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(500);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Internal Server Error');
            expect(responseBody.message).toBe('An unexpected error occurred while updating the item');
            expect(responseBody.requestId).toBe('test-request-id');
        });
    });

    describe('Edge cases', () => {
        test('should handle event with undefined pathParameters', async () => {
            // Arrange
            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: undefined,
                body: JSON.stringify({ name: 'Test' })
            };

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(400);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Validation Error');
            expect(responseBody.message).toBe('Item ID is required');
        });

        test('should handle event with null body', async () => {
            // Arrange
            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: null
            };

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(400);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Validation Error');
            expect(responseBody.details).toContain('body: At least one field (name, description, category, price) must be provided for update');
        });

        test('should handle event with undefined body', async () => {
            // Arrange
            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: undefined
            };

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(400);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Validation Error');
            expect(responseBody.details).toContain('body: At least one field (name, description, category, price) must be provided for update');
        });

        test('should trim whitespace from string fields', async () => {
            // Arrange
            const updateData = {
                name: '  Trimmed Name  ',
                description: '  Trimmed Description  ',
                category: '  electronics  '
            };

            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: JSON.stringify(updateData)
            };

            ddbMock.on(UpdateCommand).resolves({
                Attributes: {
                    ...mockUpdatedItem,
                    name: 'Trimmed Name',
                    description: 'Trimmed Description',
                    category: 'electronics'
                }
            });

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(200);

            // Verify trimmed values were sent to DynamoDB
            const updateCall = ddbMock.commandCalls(UpdateCommand)[0].args[0].input;
            expect(updateCall.ExpressionAttributeValues[':name']).toBe('Trimmed Name');
            expect(updateCall.ExpressionAttributeValues[':description']).toBe('Trimmed Description');
            expect(updateCall.ExpressionAttributeValues[':category']).toBe('electronics');
        });

        test('should include CORS headers in all responses', async () => {
            // Test successful response
            const successEvent = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: { id: validItemId },
                body: JSON.stringify({ name: 'Test' })
            };

            ddbMock.on(UpdateCommand).resolves({ Attributes: mockUpdatedItem });
            const successResult = await handler(successEvent, mockContext);

            expect(successResult.headers['Access-Control-Allow-Origin']).toBe('*');
            expect(successResult.headers['Access-Control-Allow-Headers']).toBeDefined();
            expect(successResult.headers['Access-Control-Allow-Methods']).toBeDefined();

            // Test error response
            ddbMock.reset();
            const errorEvent = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: { id: 'invalid-id' },
                body: JSON.stringify({ name: 'Test' })
            };

            const errorResult = await handler(errorEvent, mockContext);
            expect(errorResult.headers['Access-Control-Allow-Origin']).toBe('*');
        });

        test('should include security headers in responses', async () => {
            // Arrange
            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: JSON.stringify({ name: 'Test' })
            };

            ddbMock.on(UpdateCommand).resolves({
                Attributes: mockUpdatedItem
            });

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.headers['X-Content-Type-Options']).toBe('nosniff');
            expect(result.headers['X-Frame-Options']).toBe('DENY');
            expect(result.headers['X-XSS-Protection']).toBe('1; mode=block');
            expect(result.headers['Strict-Transport-Security']).toBe('max-age=31536000; includeSubDomains');
            expect(result.headers['Cache-Control']).toBe('no-cache, no-store, must-revalidate');
            expect(result.headers['Pragma']).toBe('no-cache');
            expect(result.headers['Expires']).toBe('0');
        });

        test('should handle valid categories', async () => {
            // Arrange
            const validCategories = ['electronics', 'clothing', 'books', 'home', 'sports', 'other'];

            for (const category of validCategories) {
                ddbMock.reset();

                const event = {
                    httpMethod: 'PUT',
                    resource: '/items/{id}',
                    pathParameters: {
                        id: validItemId
                    },
                    body: JSON.stringify({ category })
                };

                ddbMock.on(UpdateCommand).resolves({
                    Attributes: { ...mockUpdatedItem, category }
                });

                // Act
                const result = await handler(event, mockContext);

                // Assert
                expect(result.statusCode).toBe(200);
                const responseBody = JSON.parse(result.body);
                expect(responseBody.category).toBe(category);
            }
        });

        test('should handle circuit breaker open state', async () => {
            // Arrange - Force circuit breaker to open by simulating failures
            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: validItemId
                },
                body: JSON.stringify({ name: 'Test' })
            };

            // Simulate multiple failures to trigger circuit breaker
            const error = new Error('Database error');
            ddbMock.on(UpdateCommand).rejects(error);

            // Trigger failures to open circuit breaker (threshold is 5)
            for (let i = 0; i < 6; i++) {
                await handler(event, mockContext);
            }

            // Reset mock for the actual test
            ddbMock.reset();
            ddbMock.on(UpdateCommand).resolves({
                Attributes: mockUpdatedItem
            });

            // Act - This should be rejected by circuit breaker
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(503);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Service Unavailable');
            expect(responseBody.message).toContain('temporarily unavailable due to high error rate');
        });

        test('should handle non-string item ID', async () => {
            // Arrange
            const event = {
                httpMethod: 'PUT',
                resource: '/items/{id}',
                pathParameters: {
                    id: 123 // Non-string ID
                },
                body: JSON.stringify({ name: 'Test' })
            };

            // Act
            const result = await handler(event, mockContext);

            // Assert
            expect(result.statusCode).toBe(400);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.error).toBe('Validation Error');
        });

    });
});
