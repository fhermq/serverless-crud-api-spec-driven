# Get Item Function

## Overview
Lambda function written in Node.js that handles GET requests to retrieve items by ID from the CRUD API.

## Language Choice
Node.js was selected for this function due to its:
- Fastest cold start times among supported runtimes
- Minimal overhead for simple read operations
- Excellent AWS SDK integration
- Optimal for I/O intensive operations like database reads

## Responsibilities
- Extract item ID from API Gateway path parameters
- Query DynamoDB by item ID
- Return item data with 200 status
- Handle item not found scenarios with 404 responses
- Provide appropriate error handling

## Local Development

### Prerequisites
- Node.js 18.x or 20.x
- npm or yarn
- AWS SAM CLI
- Docker (for local DynamoDB)

### Running Locally
```bash
# Install dependencies
npm install

# Run tests
npm test

# Run tests with coverage
npm run test:coverage

# Lint code
npm run lint

# Test with SAM CLI
sam local invoke GetItemFunction -e test-event.json
```

## Testing
```bash
# Run unit tests
npm test

# Run tests in watch mode
npm run test:watch

# Generate coverage report
npm run test:coverage
```

## Environment Variables
- `DYNAMODB_TABLE_NAME` - Name of the DynamoDB table
- `AWS_REGION` - AWS region for DynamoDB operations

## API Contract
- **Method**: GET
- **Path**: /items/{id}
- **Path Parameters**: id (UUID of the item)
- **Response**: Item data with 200 status or 404 if not found