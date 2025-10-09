# Delete Item Function

## Overview
Lambda function written in Go that handles DELETE requests to remove items from the CRUD API.

## Language Choice
Go was selected for this function due to its:
- Minimal resource usage for simple operations
- Fast execution times
- Excellent performance for straightforward delete operations
- Low memory footprint

## Responsibilities
- Extract item ID from API Gateway path parameters
- Delete item from DynamoDB using DeleteItem operation
- Return 204 No Content for successful deletions
- Handle item not found scenarios appropriately
- Provide proper error handling and logging

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
go build -o main main.go

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

## API Contract
- **Method**: DELETE
- **Path**: /items/{id}
- **Path Parameters**: id (UUID of the item)
- **Response**: 204 No Content for successful deletion or error with appropriate status code