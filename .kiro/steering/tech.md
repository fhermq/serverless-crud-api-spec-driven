# Technology Stack

## AWS Serverless Architecture
- **Compute**: AWS Lambda (Multi-language: Go + Node.js)
- **API Layer**: AWS API Gateway (REST API with CORS)
- **Database**: Amazon DynamoDB (NoSQL document store with GSI)
- **Infrastructure**: AWS SAM (Multi-stack CloudFormation)
- **Monitoring**: CloudWatch (Dashboards, Alarms, X-Ray tracing)

## Multi-Language Build System
- **Go Functions**: Native Go build with `provided.al2023` runtime
- **Node.js Functions**: npm with Node.js 20.x runtime
- **Deployment**: AWS SAM CLI with multi-stack templates
- **Automation**: Bash scripts for orchestrated deployments

## Tech Stack by Function
| Function | Language | Runtime | Purpose |
|----------|----------|---------|---------|
| Create Item | Go | provided.al2023 | High-performance writes |
| Get Item | Node.js | nodejs20.x | Fast cold starts for reads |
| Update Item | Node.js | nodejs20.x | Balanced performance for updates |
| Delete Item | Go | provided.al2023 | Minimal overhead for deletes |

## Database & API
- **Database Client**: AWS SDK v3 DynamoDB (Go: aws-sdk-go, Node.js: @aws-sdk/client-dynamodb)
- **API Framework**: Native Lambda handlers with API Gateway integration
- **Validation**: JSON Schema validation at API Gateway level
- **CORS**: Configured for web client access with proper headers

## Common Commands

### Multi-Stack Deployment
```bash
# Deploy all stacks (first time or full deployment)
cd infrastructure
./scripts/deploy-all.sh --stage dev --region us-east-1

# Deploy individual stacks
./scripts/deploy-foundation.sh --stage dev        # DynamoDB + IAM
./scripts/deploy-api-and-functions.sh --stage dev # API + Lambda functions  
./scripts/deploy-monitoring.sh --stage dev       # CloudWatch + alarms

# Cleanup all stacks
./scripts/cleanup.sh --stage dev
```

### Development & Testing
```bash
# Go functions
cd functions/create-item
go mod tidy
go test -v
go build -o bootstrap main.go logger.go

# Node.js functions  
cd functions/get-item
npm install
npm test
npm run lint

# Local testing with SAM
sam local start-api --template infrastructure/stacks/02-api-and-functions.yaml
sam local invoke CreateItemFunction --event events/create-item.json
```

### Multi-Language Build Process
```bash
# Automated by deployment scripts:
# 1. Go functions: GOOS=linux GOARCH=amd64 go build -o bootstrap
# 2. Node.js functions: npm install --production
# 3. SAM build: sam build --template-file stacks/02-api-and-functions.yaml
# 4. SAM deploy: sam deploy with cross-stack parameters
```

### Monitoring & Operations
```bash
# View stack status
aws cloudformation describe-stacks --stack-name serverless-crud-api-dev-foundation

# View function logs
aws logs tail /aws/lambda/serverless-crud-api-dev-create-item --follow
aws logs tail /aws/lambda/serverless-crud-api-dev-get-item --follow

# View API Gateway logs
aws logs tail /aws/apigateway/serverless-crud-api-dev --follow

# Get API endpoint
aws cloudformation describe-stacks \
  --stack-name serverless-crud-api-dev-api \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text
```

## Development Guidelines

### Multi-Language Best Practices
- **Go Functions**: Use structured logging, proper error handling, minimal dependencies
- **Node.js Functions**: Use async/await, connection reuse, comprehensive error handling
- **Cross-Language**: Consistent error response format, environment variable usage
- **Testing**: Language-specific testing frameworks (Go: built-in, Node.js: Jest)

### Infrastructure Guidelines  
- **Multi-stack deployment**: Deploy foundation first, then API+functions, then monitoring
- **Cross-stack references**: Use CloudFormation exports/imports for resource sharing
- **Environment isolation**: Separate stacks per environment (dev/staging/prod)
- **Rollback strategy**: Independent stack rollbacks for isolated failure recovery

### API & Database Guidelines
- **DynamoDB**: Single-table design with GSI for category queries
- **API Gateway**: JSON schema validation, CORS configuration, proper error responses
- **Lambda integration**: Direct integration between API Gateway and Lambda functions
- **Monitoring**: Structured logging with request IDs, CloudWatch dashboards and alarms

### Security & Performance
- **IAM**: Least privilege roles per function, no hardcoded credentials
- **Environment variables**: Configuration through CloudFormation parameters
- **Cold start optimization**: Minimal dependencies, connection reuse (Node.js)
- **Request validation**: API Gateway level validation before Lambda execution