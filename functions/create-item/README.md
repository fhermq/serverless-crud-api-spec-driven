# Create Item Function

## Overview
Lambda function written in Go that handles POST requests to create new items in the CRUD API.

## Language Choice
Go was selected for this function due to its:
- Fast execution and minimal cold start times
- Efficient memory usage for write operations
- Excellent performance for concurrent operations

## Responsibilities
- Validate input data for new items
- Generate UUID for new items
- Set creation and update timestamps
- Store item in DynamoDB
- Return created item with 201 status

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