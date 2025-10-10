# Update Item Lambda Function

This Lambda function handles updating existing items in the DynamoDB table via HTTP PUT requests.

## Overview

- **Runtime**: Node.js 18.x
- **Handler**: `index.handler`
- **HTTP Method**: PUT
- **Endpoint**: `/items/{id}`
- **Database**: DynamoDB UpdateItem operation

## Features

- ✅ Input validation and sanitization
- ✅ UUID v4 validation for item IDs
- ✅ Conditional updates (item must exist)
- ✅ Partial updates (only provided fields are updated)
- ✅ Automatic timestamp management
- ✅ Circuit breaker pattern for resilience
- ✅ Structured logging with request correlation
- ✅ Custom CloudWatch metrics
- ✅ Security headers
- ✅ Error handling with appropriate HTTP status codes

## Request Format

### Path Parameters
- `id` (required): UUID v4 of the item to update

### Request Body
```json
{
  "name": "string (optional, 1-100 characters)",
  "description": "string (optional, max 500 characters)",
  "category": "string (optional, one of: electronics, clothing, books, home, sports, other)",
  "price": "number (optional, minimum 0.01)"
}
```

**Note**: At least one field must be provided for the update.

## Response Format

### Success Response (200 OK)
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Updated Item Name",
  "description": "Updated description",
  "category": "electronics",
  "price": 29.99,
  "createdAt": "2023-01-01T00:00:00.000Z",
  "updatedAt": "2023-01-02T12:00:00.000Z"
}
```

### Error Responses

#### 400 Bad Request - Validation Error
```json
{
  "error": "Validation Error",
  "message": "Validation failed",
  "details": [
    "name: Name must not exceed 100 characters",
    "price: Price must be at least 0.01"
  ],
  "requestId": "12345678-1234-1234-1234-123456789012",
  "timestamp": "2023-01-01T12:00:00.000Z"
}
```

#### 404 Not Found
```json
{
  "error": "Not Found",
  "message": "Item with id '550e8400-e29b-41d4-a716-446655440000' not found",
  "requestId": "12345678-1234-1234-1234-123456789012",
  "timestamp": "2023-01-01T12:00:00.000Z"
}
```

#### 500 Internal Server Error
```json
{
  "error": "Internal Server Error",
  "message": "An unexpected error occurred while updating the item",
  "requestId": "12345678-1234-1234-1234-123456789012",
  "timestamp": "2023-01-01T12:00:00.000Z"
}
```

#### 503 Service Unavailable
```json
{
  "error": "Service Unavailable",
  "message": "Service is temporarily unavailable due to high error rate. Please try again later.",
  "requestId": "12345678-1234-1234-1234-123456789012",
  "timestamp": "2023-01-01T12:00:00.000Z"
}
```

## Environment Variables

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `DYNAMODB_TABLE_NAME` | Yes | Name of the DynamoDB table | - |
| `AWS_REGION` | Yes | AWS region for DynamoDB | - |
| `CIRCUIT_BREAKER_THRESHOLD` | No | Number of failures before circuit breaker opens | 5 |

## Dependencies

### Production Dependencies
- `@aws-sdk/client-dynamodb`: AWS DynamoDB client
- `@aws-sdk/lib-dynamodb`: DynamoDB document client
- `@serverless-crud-api/shared`: Shared utilities and models
- `aws-xray-sdk-core`: AWS X-Ray tracing

### Development Dependencies
- `jest`: Testing framework
- `eslint`: Code linting
- `aws-sdk-client-mock`: AWS SDK mocking for tests

## Local Development

### Install Dependencies
```bash
npm install
```

### Run Tests
```bash
# Run all tests
npm test

# Run tests in watch mode
npm run test:watch

# Run tests with coverage
npm run test:coverage
```

### Linting
```bash
# Check for linting errors
npm run lint

# Fix linting errors automatically
npm run lint:fix
```

### Local Testing with SAM
```bash
# Test the function locally
sam local invoke UpdateItemFunction -e ../../events/update-item-event.json

# Start local API Gateway
sam local start-api
```

## Testing

The function includes comprehensive unit tests covering:

- ✅ Successful item updates
- ✅ Partial updates (individual fields)
- ✅ Item not found scenarios
- ✅ Validation error handling
- ✅ DynamoDB error scenarios
- ✅ Circuit breaker functionality
- ✅ Security header validation

## Performance Considerations

- **Cold Start Optimization**: DynamoDB client is initialized outside the handler
- **Connection Reuse**: DynamoDB client connection is reused across invocations
- **Circuit Breaker**: Prevents cascading failures during high error rates
- **Retry Logic**: Built-in AWS SDK retry with adaptive mode
- **Monitoring**: Custom CloudWatch metrics for performance tracking

## Security Features

- **Input Validation**: All inputs are validated and sanitized
- **SQL Injection Prevention**: Uses parameterized DynamoDB operations
- **Security Headers**: Comprehensive security headers in responses
- **Error Information**: No sensitive data leaked in error messages
- **X-Ray Tracing**: Request tracing for security monitoring

## Monitoring and Observability

### CloudWatch Logs
- Structured logging with request correlation IDs
- Database operation timing and results
- Error details with context
- Circuit breaker state changes

### Custom Metrics
- `UpdateItemDuration`: Operation execution time
- `UpdateItemCount`: Success/error counts
- `CircuitBreakerState`: Circuit breaker status

### X-Ray Tracing
- End-to-end request tracing
- DynamoDB operation tracing
- Performance bottleneck identification

## Error Handling

The function implements comprehensive error handling:

1. **Input Validation**: Validates all inputs before processing
2. **Business Logic Errors**: Handles item not found scenarios
3. **Database Errors**: Specific handling for DynamoDB errors
4. **Circuit Breaker**: Prevents system overload during failures
5. **Generic Errors**: Fallback error handling for unexpected issues

## Architecture Decisions

### Why Node.js?
- Fast cold starts for API operations
- Excellent AWS SDK support
- Good balance of performance and development speed
- Suitable for data manipulation operations

### Why UpdateItem over PutItem?
- Conditional updates ensure item exists
- Atomic operations prevent race conditions
- Partial updates reduce bandwidth
- Better performance for update operations

### Circuit Breaker Pattern
- Prevents cascading failures
- Improves system resilience
- Provides graceful degradation
- Enables faster recovery

## Integration

This function integrates with:
- **API Gateway**: HTTP PUT requests to `/items/{id}`
- **DynamoDB**: Items table for data persistence
- **CloudWatch**: Logging and custom metrics
- **X-Ray**: Distributed tracing
- **Shared Package**: Common utilities and models

## Deployment

The function is deployed as part of the SAM template:

```yaml
UpdateItemFunction:
  Type: AWS::Serverless::Function
  Properties:
    CodeUri: functions/update-item/
    Handler: index.handler
    Runtime: nodejs18.x
    Environment:
      Variables:
        DYNAMODB_TABLE_NAME: !Ref ItemsTable
    Events:
      UpdateItem:
        Type: Api
        Properties:
          Path: /items/{id}
          Method: put
```

## Contributing

When modifying this function:

1. Follow the established patterns from other functions
2. Update tests for any new functionality
3. Ensure all linting rules pass
4. Update this README for any API changes
5. Test locally before deploying