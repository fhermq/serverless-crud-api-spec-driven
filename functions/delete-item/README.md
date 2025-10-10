# Delete Item Function

## Overview
Lambda function written in Go that handles DELETE requests to remove items from the CRUD API.

## Language Choice
Go was selected for this function due to its:
- Fast execution and minimal cold start times
- Minimal resource usage for simple operations
- Excellent performance for delete operations

## Responsibilities
- Extract item ID from path parameters
- Validate UUID format
- Check if item exists before deletion
- Delete item from DynamoDB
- Return 204 No Content for successful deletions
- Handle item not found scenarios appropriately

## Local Development

### Prerequisites
- Go 1.21 or later
- AWS SAM CLI
- Docker (for local DynamoDB)

### Running Locally
```bash
# Install dependencies
go mod tidy

# Run tests
go test ./...

# Build function
go build -o main main.go logger.go

# Test with SAM CLI
sam local invoke DeleteItemFunction -e test-event.json
```

## Testing
```bash
# Run unit tests
go test -v

# Run with coverage
go test -cover
```

## Environment Variables
- `DYNAMODB_TABLE_NAME` - Name of the DynamoDB table
- `AWS_REGION` - AWS region for DynamoDB operations
- `LOG_LEVEL` - Logging level (DEBUG, INFO, WARN, ERROR)

## API Contract
- **Method**: DELETE
- **Path**: /items/{id}
- **Path Parameters**: id (UUID format)
- **Response**: 204 No Content for successful deletion, or error with appropriate status code

## Error Handling
- **400 Bad Request**: Missing or invalid item ID format
- **404 Not Found**: Item does not exist
- **500 Internal Server Error**: Database or server errors