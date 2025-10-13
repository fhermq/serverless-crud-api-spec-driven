# Serverless CRUD API

Multi-language serverless CRUD API built with AWS SAM, Lambda, API Gateway, and DynamoDB.

## Quick Start

```bash
# Deploy
./infrastructure/scripts/deploy.sh dev

# Get API credentials  
./infrastructure/scripts/get-api-key.sh dev

# Test all CRUD operations
./infrastructure/scripts/test-api.sh dev

# Clean up
./infrastructure/scripts/cleanup.sh dev
```

## API Endpoints

- `POST /items` - Create item
- `GET /items/{id}` - Get item  
- `PUT /items/{id}` - Update item
- `DELETE /items/{id}` - Delete item

All endpoints require an API key in the `X-API-Key` header.

## Architecture

- **Lambda Functions**: Go (create/delete) + Node.js (get/update)
- **API Gateway**: REST API with usage plans and throttling
- **DynamoDB**: Single table with GSI for category queries
- **SAM**: Infrastructure as Code with multi-stack deployment

## Project Structure

```
├── functions/             # Lambda function code
│   ├── create-item/      # Go - Create operations
│   ├── get-item/         # Node.js - Read operations  
│   ├── update-item/      # Node.js - Update operations
│   └── delete-item/      # Go - Delete operations
├── infrastructure/
│   ├── stacks/           # SAM templates
│   │   ├── 01-foundation.yaml    # DynamoDB + IAM
│   │   └── 02-api-and-functions.yaml # API + Lambda
│   ├── scripts/          # Deployment scripts (4 total)
│   │   ├── deploy.sh     # Deploy everything
│   │   ├── get-api-key.sh # Get API credentials
│   │   ├── test-api.sh   # Test CRUD operations
│   │   └── cleanup.sh    # Delete everything
│   └── parameters/       # Environment-specific configs
└── docs/                 # API documentation
```

## Development

Built with AWS SAM for local development and testing:

```bash
# Local API
sam local start-api --template infrastructure/stacks/02-api-and-functions.yaml

# Local function testing
sam local invoke GetItemFunction --event events/get-item.json
```