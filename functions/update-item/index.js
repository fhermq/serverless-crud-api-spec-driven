const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, UpdateCommand } = require('@aws-sdk/lib-dynamodb');
const AWSXRay = require('aws-xray-sdk-core');
const {
    successResponse,
    notFoundResponse,
    internalServerErrorResponse,
    validationErrorResponse
} = require('@serverless-crud-api/shared/dist/utils/response');
const { createRequestLogger } = require('@serverless-crud-api/shared/dist/utils/logger');
const {
    validateItemId,
    sanitizeString,
    validateUpdateItemRequest,
    sanitizeUpdateItemRequest
} = require('@serverless-crud-api/shared/dist/utils/validation');
const { ValidationApiError, NotFoundError, ApiError } = require('@serverless-crud-api/shared/dist/models/error');

// Initialize DynamoDB client with X-Ray tracing (connection reuse for performance)
const client = AWSXRay.captureAWSv3Client(new DynamoDBClient({
    region: process.env.AWS_REGION,
    maxAttempts: 3, // Built-in retry logic
    retryMode: 'adaptive'
}));
const docClient = DynamoDBDocumentClient.from(client);

// Environment variables with validation
const TABLE_NAME = process.env.DYNAMODB_TABLE_NAME;
const CIRCUIT_BREAKER_THRESHOLD = parseInt(process.env.CIRCUIT_BREAKER_THRESHOLD || '5');

// Validate required environment variables
if (!TABLE_NAME) {
    throw new Error('DYNAMODB_TABLE_NAME environment variable is required');
}

// Simple circuit breaker state (in production, use Redis or DynamoDB for shared state)
const circuitBreakerState = {
    failures: 0,
    lastFailureTime: null,
    isOpen: false
};

/**
 * Lambda handler for updating an item by ID
 * @param {import('aws-lambda').APIGatewayProxyEvent} event - API Gateway event
 * @param {import('aws-lambda').Context} context - Lambda context
 * @returns {Promise<import('aws-lambda').APIGatewayProxyResult>} API Gateway response
 */
exports.handler = async (event, context) => {
    const requestId = context.awsRequestId;
    const logger = createRequestLogger(requestId, {
        functionName: context.functionName,
        operation: 'updateItem'
    });

    let startTime;

    logger.info('Update item request received', {
        pathParameters: event.pathParameters,
        httpMethod: event.httpMethod,
        resource: event.resource
    });

    try {
        // Extract and sanitize item ID from path parameters
        const rawItemId = event.pathParameters?.id;

        if (rawItemId === undefined || rawItemId === null) {
            logger.warn('Missing item ID in path parameters');
            return validationErrorResponse(
                'Item ID is required',
                ['id: Item ID must be provided in the URL path'],
                requestId
            );
        }

        // Sanitize input to prevent injection attacks
        const itemId = typeof rawItemId === 'string' ? sanitizeString(rawItemId) : rawItemId;

        // Validate item ID format
        let validatedId;
        try {
            validatedId = validateItemId(itemId, requestId);
        } catch (error) {
            if (error instanceof ValidationApiError) {
                logger.warn('Invalid item ID format', { itemId, error: error.message });
                return validationErrorResponse(
                    error.message,
                    error.details || [],
                    requestId
                );
            }
            throw error;
        }

        // Parse and validate request body
        let requestBody;
        try {
            requestBody = event.body ? JSON.parse(event.body) : {};
        } catch (parseError) {
            logger.warn('Invalid JSON in request body', { body: event.body, error: parseError.message });
            return validationErrorResponse(
                'Invalid JSON in request body',
                ['body: Request body must be valid JSON'],
                requestId
            );
        }

        // Pre-sanitize data for validation (trim whitespace) and copy all fields for validation
        const preSanitizedData = {};

        // Copy all fields from requestBody, but sanitize string fields
        for (const [key, value] of Object.entries(requestBody)) {
            if (typeof value === 'string') {
                preSanitizedData[key] = value.trim();
            } else {
                preSanitizedData[key] = value;
            }
        }

        // Validate update request data
        let validatedUpdateData;
        try {
            validatedUpdateData = validateUpdateItemRequest(preSanitizedData, requestId);
        } catch (error) {
            if (error instanceof ValidationApiError) {
                logger.warn('Invalid update request data', {
                    requestBody,
                    error: error.message,
                    details: error.details
                });
                return validationErrorResponse(
                    error.message,
                    error.details?.map(detail => {
                        if (typeof detail === 'string') return detail;
                        if (detail.field && detail.message) return `${detail.field}: ${detail.message}`;
                        return detail.message || 'Validation error';
                    }) || [],
                    requestId
                );
            }
            throw error;
        }

        // Sanitize the validated data (already done above, but keep for consistency)
        const sanitizedData = sanitizeUpdateItemRequest(validatedUpdateData);

        logger.info('Updating item in DynamoDB', {
            itemId: validatedId,
            tableName: TABLE_NAME,
            updateFields: Object.keys(sanitizedData)
        });

        // Check circuit breaker state
        if (isCircuitBreakerOpen()) {
            logger.warn('Circuit breaker is open, rejecting request');
            return {
                statusCode: 503,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({
                    error: 'Service Unavailable',
                    message: 'Service is temporarily unavailable due to high error rate. Please try again later.',
                    requestId,
                    timestamp: new Date().toISOString()
                })
            };
        }

        // Update item in DynamoDB with circuit breaker
        startTime = Date.now();
        let result;
        try {
            // Build update expression and attribute values
            const updateExpression = buildUpdateExpression(sanitizedData);
            const expressionAttributeNames = buildExpressionAttributeNames(sanitizedData);
            const expressionAttributeValues = buildExpressionAttributeValues(sanitizedData);

            const command = new UpdateCommand({
                TableName: TABLE_NAME,
                Key: {
                    id: validatedId
                },
                UpdateExpression: updateExpression,
                ExpressionAttributeNames: expressionAttributeNames,
                ExpressionAttributeValues: expressionAttributeValues,
                ConditionExpression: 'attribute_exists(id)', // Ensure item exists
                ReturnValues: 'ALL_NEW'
            });

            result = await docClient.send(command);

            // Reset circuit breaker on success
            resetCircuitBreaker();
        } catch (dbError) {
            recordCircuitBreakerFailure();

            // Handle conditional check failed (item not found)
            if (dbError.name === 'ConditionalCheckFailedException') {
                logger.info('Item not found for update', { itemId: validatedId });
                return notFoundResponse('Item', validatedId, requestId);
            }

            throw dbError;
        }

        const duration = Date.now() - startTime;

        logger.logDatabaseOperation('UpdateItem', TABLE_NAME, {
            id: validatedId,
            updateFields: Object.keys(sanitizedData)
        }, duration);

        logger.info('Item updated successfully', {
            itemId: validatedId,
            itemName: result.Attributes?.name,
            updatedFields: Object.keys(sanitizedData),
            duration: `${duration}ms`
        });

        // Add custom metrics for monitoring
        await publishCustomMetrics('UpdateItem', 'Success', duration, requestId);

        // Return the updated item with security headers
        const response = successResponse(result.Attributes, 200);
        return addSecurityHeaders(response);

    } catch (error) {
        const errorStartTime = startTime || Date.now();
        logger.error('Error updating item', error, {
            itemId: event.pathParameters?.id,
            tableName: TABLE_NAME
        });

        // Handle known error types
        if (error instanceof ValidationApiError) {
            return validationErrorResponse(
                error.message,
                error.details?.map(detail => `${detail.field}: ${detail.message}`) || [],
                requestId
            );
        }

        if (error instanceof NotFoundError) {
            return notFoundResponse('Item', event.pathParameters?.id || 'unknown', requestId);
        }

        if (error instanceof ApiError) {
            return internalServerErrorResponse(error.message, requestId);
        }

        // Handle DynamoDB specific errors
        if (error.name === 'ResourceNotFoundException') {
            logger.error('DynamoDB table not found', error, { tableName: TABLE_NAME });
            return internalServerErrorResponse(
                'Database configuration error',
                requestId
            );
        }

        if (error.name === 'ProvisionedThroughputExceededException') {
            logger.error('DynamoDB throughput exceeded', error);
            return {
                statusCode: 503,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({
                    error: 'Service Unavailable',
                    message: 'Database is temporarily unavailable. Please try again later.',
                    requestId,
                    timestamp: new Date().toISOString()
                })
            };
        }

        // Generic error handling
        await publishCustomMetrics('UpdateItem', 'Error', Date.now() - errorStartTime, requestId);
        return addSecurityHeaders(internalServerErrorResponse(
            'An unexpected error occurred while updating the item',
            requestId
        ));
    }
};

/**
 * Build DynamoDB update expression from sanitized data
 * @param {import('@serverless-crud-api/shared/dist/models/item').UpdateItemRequest} data - Sanitized update data
 * @returns {string} Update expression
 */
function buildUpdateExpression(data) {
    const setParts = [];

    if (data.name !== undefined) setParts.push('#name = :name');
    if (data.description !== undefined) setParts.push('#description = :description');
    if (data.category !== undefined) setParts.push('#category = :category');
    if (data.price !== undefined) setParts.push('#price = :price');

    // Always update the updatedAt timestamp
    setParts.push('#updatedAt = :updatedAt');

    return `SET ${setParts.join(', ')}`;
}

/**
 * Build expression attribute names for DynamoDB update
 * @param {import('@serverless-crud-api/shared/dist/models/item').UpdateItemRequest} data - Sanitized update data
 * @returns {Record<string, string>} Expression attribute names
 */
function buildExpressionAttributeNames(data) {
    const names = {
        '#updatedAt': 'updatedAt'
    };

    if (data.name !== undefined) names['#name'] = 'name';
    if (data.description !== undefined) names['#description'] = 'description';
    if (data.category !== undefined) names['#category'] = 'category';
    if (data.price !== undefined) names['#price'] = 'price';

    return names;
}

/**
 * Build expression attribute values for DynamoDB update
 * @param {import('@serverless-crud-api/shared/dist/models/item').UpdateItemRequest} data - Sanitized update data
 * @returns {Record<string, any>} Expression attribute values
 */
function buildExpressionAttributeValues(data) {
    const values = {
        ':updatedAt': new Date().toISOString()
    };

    if (data.name !== undefined) values[':name'] = data.name;
    if (data.description !== undefined) values[':description'] = data.description;
    if (data.category !== undefined) values[':category'] = data.category;
    if (data.price !== undefined) values[':price'] = data.price;

    return values;
}

/**
 * Add security headers to response
 * @param {import('aws-lambda').APIGatewayProxyResult} response - Lambda response object
 * @returns {import('aws-lambda').APIGatewayProxyResult} Response with security headers
 */
function addSecurityHeaders(response) {
    return {
        ...response,
        headers: {
            ...response.headers,
            'X-Content-Type-Options': 'nosniff',
            'X-Frame-Options': 'DENY',
            'X-XSS-Protection': '1; mode=block',
            'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0'
        }
    };
}

/**
 * Check if circuit breaker is open
 * @returns {boolean} True if circuit breaker is open
 */
function isCircuitBreakerOpen() {
    if (!circuitBreakerState.isOpen) {
        return false;
    }

    // Check if enough time has passed to try again (half-open state)
    const timeSinceLastFailure = Date.now() - circuitBreakerState.lastFailureTime;
    const cooldownPeriod = 60000; // 1 minute

    if (timeSinceLastFailure > cooldownPeriod) {
        circuitBreakerState.isOpen = false;
        return false;
    }

    return true;
}

/**
 * Record a circuit breaker failure
 */
function recordCircuitBreakerFailure() {
    circuitBreakerState.failures++;
    circuitBreakerState.lastFailureTime = Date.now();

    if (circuitBreakerState.failures >= CIRCUIT_BREAKER_THRESHOLD) {
        circuitBreakerState.isOpen = true;
        console.log('Circuit breaker opened due to high failure rate');
    }
}

/**
 * Reset circuit breaker on successful operation
 */
function resetCircuitBreaker() {
    circuitBreakerState.failures = 0;
    circuitBreakerState.isOpen = false;
    circuitBreakerState.lastFailureTime = null;
}

/**
 * Publish custom metrics to CloudWatch
 * @param {string} operation - Operation name
 * @param {string} status - Success or Error
 * @param {number} duration - Operation duration in ms
 * @param {string} requestId - Request ID for correlation
 */
async function publishCustomMetrics(operation, status, duration, requestId) {
    try {
        // In a real implementation, you would use AWS CloudWatch SDK
        // For now, we'll log structured metrics that can be parsed by CloudWatch Insights
        console.log(JSON.stringify({
            MetricType: 'Custom',
            MetricName: `${operation}Duration`,
            Value: duration,
            Unit: 'Milliseconds',
            Dimensions: {
                Operation: operation,
                Status: status,
                FunctionName: process.env.AWS_LAMBDA_FUNCTION_NAME
            },
            RequestId: requestId,
            Timestamp: new Date().toISOString()
        }));

        console.log(JSON.stringify({
            MetricType: 'Custom',
            MetricName: `${operation}Count`,
            Value: 1,
            Unit: 'Count',
            Dimensions: {
                Operation: operation,
                Status: status,
                FunctionName: process.env.AWS_LAMBDA_FUNCTION_NAME
            },
            RequestId: requestId,
            Timestamp: new Date().toISOString()
        }));

        // Circuit breaker metrics
        console.log(JSON.stringify({
            MetricType: 'Custom',
            MetricName: 'CircuitBreakerState',
            Value: circuitBreakerState.isOpen ? 1 : 0,
            Unit: 'Count',
            Dimensions: {
                Operation: operation,
                FunctionName: process.env.AWS_LAMBDA_FUNCTION_NAME
            },
            RequestId: requestId,
            Timestamp: new Date().toISOString()
        }));
    } catch (error) {
        // Don't let metrics publishing fail the main operation
        console.error('Failed to publish custom metrics:', error);
    }
}
