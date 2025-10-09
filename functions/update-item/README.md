# Update Item Function

## Overview
Lambda function written in Node.js that handles PUT requests to update existing items in the CRUD API.

## Language Choice
Node.js was selected for this function due to its:
- Good balance of performance and development speed
- Excellent for data manipulation operations
- Strong JSON processing capabilities
- Optimal AWS SDK integration

## Responsibilities
- Validate update request data
- Check if item exists before updating
- Implement conditional DynamoDB UpdateItem operation
- Update timestamp fields
- Return updated item with 200 status
- Handle validation and not found errors appropriately

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
sam local invoke UpdateItemFunction -e test-event.json
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
- **Method**: PUT
- **Path**: /items/{id}
- **Path Parameters**: id (UUID of the item)
- **Request Body**: JSON with fields to update (name, description, category, price)
- **Response**: Updated item with 200 status or error with appropriate status code