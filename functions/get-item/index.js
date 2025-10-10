const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand } = require('@aws-sdk/lib-dynamodb');
const AWSXRay = require('aws-xray-sdk-core');
const {
    successResponse,
    notFoundResponse,
    internalServerErrorResponse,
    validationErrorResponse
} = require('@serverless-crud-api/shared/dist/utils/response');
const { createRequestLogger } = require('@serverless-crud-api/shared/dist/utils/logger');
const { validateItemId, sanitizeString } = require('@serverless-crud-api/shared/dist/utils/validation');
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
const MAX_RETRY_ATTEMPTS = parseInt(process.env.MAX_RETRY_ATTEMPTS || '3');
const CIRCUIT_BREAKER_THRESHOLD = parseInt(process.env.CIRCUIT_BREAKER_THRESHOLD || '5');

// Validate required environment variables
if (!TABLE_NAME) {
    throw new Error('DYNAMODB_TABLE_NAME environment variable is required');
}

// Simple circuit breaker state (in production, use Redis or DynamoDB for shared state)
let circuitBreakerState = {
    failures: 0,
    lastFailureTime: null,
    isOpen: false
};

/**
 * Lambda handler for getting an item by ID
 * @param {Object} event - API Gateway event
 * @param {Object} context - Lambda context
 * @returns {Object} API Gateway response
 */
exports.handler = async (event, context) => {
    const requestId = context.awsRequestId;
    const logger = createRequestLogger(requestId, {
        functionName: context.functionName,
        operation: 'getItem'
    });

    let startTime;

    logger.info('Get item request received', {
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

        logger.info('Retrieving item from DynamoDB', { itemId: validatedId, tableName: TABLE_NAME });

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

        // Get item from DynamoDB with circuit breaker
        startTime = Date.now();
        let result;
        try {
            const command = new GetCommand({
                TableName: TABLE_NAME,
                Key: {
                    id: validatedId
                }
            });

            result = await docClient.send(command);

            // Reset circuit breaker on success
            resetCircuitBreaker();
        } catch (dbError) {
            recordCircuitBreakerFailure();
            throw dbError;
        }

        const duration = Date.now() - startTime;

        logger.logDatabaseOperation('GetItem', TABLE_NAME, { id: validatedId }, duration);

        // Check if item was found
        if (!result.Item) {
            logger.info('Item not found', { itemId: validatedId });
            return notFoundResponse('Item', validatedId, requestId);
        }

        logger.info('Item retrieved successfully', {
            itemId: validatedId,
            itemName: result.Item.name,
            duration: `${duration}ms`
        });

        // Add custom metrics for monitoring
        await publishCustomMetrics('GetItem', 'Success', duration, requestId);

        // Return the item with security headers
        const response = successResponse(result.Item, 200);
        return addSecurityHeaders(response);

    } catch (error) {
        const errorStartTime = startTime || Date.now();
        logger.error('Error retrieving item', error, {
            itemId: event.pathParameters?.id,
            tableName: TABLE_NAME
        });

        // Handle known error types
        if (error instanceof ValidationApiError) {
            return validationErrorResponse(
                error.message,
                error.details || [],
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
        await publishCustomMetrics('GetItem', 'Error', Date.now() - errorStartTime, requestId);
        return addSecurityHeaders(internalServerErrorResponse(
            'An unexpected error occurred while retrieving the item',
            requestId
        ));
    }
};

/**
 * Add security headers to response
 * @param {Object} response - Lambda response object
 * @returns {Object} Response with security headers
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