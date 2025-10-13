# Infrastructure

AWS SAM templates and deployment scripts for the Serverless CRUD API.

## Architecture

Two-stack deployment:

1. **Foundation Stack** (`01-foundation.yaml`) - DynamoDB + IAM roles
2. **API Stack** (`02-api-and-functions.yaml`) - API Gateway + Lambda functions

## Deployment

```bash
# Deploy everything
./scripts/deploy.sh dev

# Get API credentials
./scripts/get-api-key.sh dev

# Test API
./scripts/test-api.sh dev

# Clean up
./scripts/cleanup.sh dev
```

## Structure

```
infrastructure/
├── stacks/           # SAM templates
├── scripts/          # Deployment scripts (4 total)
└── parameters/       # Environment configs
```

## Lambda Functions

| Function | Language | Purpose |
|----------|----------|---------|
| create-item | Go | Create operations |
| get-item | Node.js | Read operations |
| update-item | Node.js | Update operations |
| delete-item | Go | Delete operations |

## Local Development

```bash
# Local API
sam local start-api --template stacks/02-api-and-functions.yaml

# Test function
sam local invoke GetItemFunction --event ../events/get-item.json
```