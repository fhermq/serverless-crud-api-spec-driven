# Create Item Function

Go Lambda function that creates new items in DynamoDB.

## Handler

- **Runtime**: provided.al2023 (Go)
- **Handler**: `bootstrap`
- **Method**: POST `/items`

## Local Testing

```bash
# Build
go mod tidy
GOOS=linux GOARCH=amd64 go build -o bootstrap main.go logger.go

# Test locally
sam local invoke CreateItemFunction --event ../../events/create-item.json

# Run tests
go test -v
```

## Environment Variables

- `DYNAMODB_TABLE_NAME` - DynamoDB table name
- `STAGE` - Deployment stage
- `LOG_LEVEL` - Logging level

# Run tests
go test ./...

# Build function
go build -o main main.go

# Test with SAM CLI
sam local invoke CreateItemFunction -e test-event.json
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
- **Method**: POST
- **Path**: /items
- **Request Body**: JSON with name, description, category, price
- **Response**: Created item with 201 status or error with appropriate status code