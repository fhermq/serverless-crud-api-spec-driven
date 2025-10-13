# Delete Item Function

Go Lambda function that deletes items from DynamoDB.

## Handler

- **Runtime**: provided.al2023 (Go)
- **Handler**: `bootstrap`
- **Method**: DELETE `/items/{id}`

## Local Testing

```bash
# Build
go mod tidy
GOOS=linux GOARCH=amd64 go build -o bootstrap main.go logger.go

# Test locally
sam local invoke DeleteItemFunction --event ../../events/delete-item.json

# Run tests
go test -v
```

## Environment Variables

- `DYNAMODB_TABLE_NAME` - DynamoDB table name
- `STAGE` - Deployment stage
- `LOG_LEVEL` - Logging level

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