# Serverless CRUD API Infrastructure

This directory contains the multi-stack AWS SAM templates and deployment scripts for the Serverless CRUD API.

## Multi-Stack Architecture

The infrastructure is organized into 3 separate CloudFormation stacks for better maintainability, independent deployments, and team ownership:

### 1. Foundation Stack (`01-foundation.yaml`)
- **DynamoDB Table**: Items table with GSI for category queries
- **IAM Roles**: Base Lambda execution roles with DynamoDB permissions
- **Purpose**: Core data layer and security foundation
- **Change Frequency**: Low (database schema changes)

### 2. API and Functions Stack (`02-api-and-functions.yaml`)
- **REST API**: Regional API Gateway with CORS and throttling
- **CRUD Functions**: Create (Go), Get (Node.js), Update (Node.js), Delete (Go)
- **API Integration**: Direct integration between API Gateway and Lambda functions
- **X-Ray Tracing**: Distributed tracing for debugging
- **Purpose**: API layer and business logic
- **Change Frequency**: High (feature development and API changes)

### 3. Monitoring Stack (`03-monitoring.yaml`)
- **CloudWatch Dashboard**: API and Lambda metrics visualization
- **Alarms**: Error rate and throttling alerts
- **Log Groups**: Centralized logging with retention policies
- **Purpose**: Observability and alerting
- **Change Frequency**: Low (monitoring configuration)

## Benefits of Multi-Stack Architecture

### 🔄 **Independent Deployments**
- Deploy database changes without affecting Lambda functions
- Update API Gateway configuration independently
- Deploy individual function updates without service disruption
- Add monitoring without touching core services

### 👥 **Team Ownership**
- **DevOps Team**: Foundation and monitoring stacks
- **Backend Team**: Lambda functions stack  
- **API Team**: API Gateway stack
- **Clear boundaries** for code reviews and responsibilities

### 🛡️ **Reduced Blast Radius**
- Function deployment failures don't affect database
- API changes don't impact existing functions
- Monitoring updates don't disrupt services
- **Safer deployments** with isolated failure domains

### 🔧 **Better Maintainability**
- **Smaller templates** are easier to understand and modify
- **Focused changes** reduce complexity
- **Reusable components** through cross-stack references
- **Clear dependencies** between infrastructure layers

### 📈 **Scalability**
- Easy to add new services or functions
- **Shared foundation** supports multiple applications
- **Standardized patterns** for consistent architecture
- **Environment promotion** with parameter files

## Prerequisites

- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- [SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html) installed
- [Go](https://golang.org/dl/) 1.21+ for building Go functions
- [Node.js](https://nodejs.org/) 18+ for Node.js functions

## Quick Start

### 1. Deploy All Stacks (Recommended)

```bash
cd infrastructure
./scripts/deploy-all.sh --stage dev --region us-east-1
```

This deploys all 3 stacks in the correct dependency order.

⏱️ **Time**: ~8-12 minutes | **Creates**: Complete infrastructure

### 2. Deploy Individual Stacks

```bash
# Deploy foundation first (required by others)
./scripts/deploy-foundation.sh --stage dev

# Deploy API and functions (requires foundation)
./scripts/deploy-api-and-functions.sh --stage dev

# Deploy monitoring (requires foundation + API)
./scripts/deploy-monitoring.sh --stage dev
```

### 3. Environment-Specific Deployment

```bash
# Development
./scripts/deploy-all.sh --stage dev --region us-east-1

# Staging
./scripts/deploy-all.sh --stage staging --region us-east-1

# Production
./scripts/deploy-all.sh --stage prod --region us-west-2
```

### 4. Development Workflow

```bash
# Most common: Update Lambda functions (~3-4 min)
./scripts/deploy-api-and-functions.sh --stage dev

# Rare: Database changes (~6-8 min)
./scripts/deploy-foundation.sh --stage dev

# Occasional: Monitoring updates (~2-3 min)
./scripts/deploy-monitoring.sh --stage dev
```

### 5. Cleanup

```bash
# Interactive cleanup
./scripts/cleanup.sh --stage dev

# Force cleanup (no confirmation)
./scripts/cleanup.sh --stage dev --force
```

> 📖 **For detailed deployment scenarios, troubleshooting, and best practices, see [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)**

## File Structure

```
infrastructure/
├── stacks/                         # Multi-stack templates
│   ├── 01-foundation.yaml          # DynamoDB + IAM roles
│   ├── 02-api-and-functions.yaml   # API Gateway + Lambda functions
│   └── 03-monitoring.yaml          # CloudWatch + alarms
├── nested-stacks/                  # Reusable templates (future)
├── parameters/                     # Environment-specific parameters
│   ├── dev.json                   # Development environment
│   ├── staging.json               # Staging environment
│   └── prod.json                  # Production environment
├── scripts/                       # Deployment scripts
│   ├── deploy-all.sh              # Deploy all stacks
│   ├── deploy-foundation.sh       # Deploy foundation only
│   ├── deploy-api-and-functions.sh # Deploy API + functions
│   ├── deploy-monitoring.sh       # Deploy monitoring only
│   └── cleanup.sh                 # Delete all stacks
├── DEPLOYMENT_GUIDE.md           # Comprehensive deployment guide
├── ARCHITECTURE.md               # Multi-stack architecture details
└── README.md                     # This file
```

## SAM Template Components

### API Gateway Configuration

- **CORS**: Configured for web client access
- **Request Validation**: JSON schema validation for request bodies
- **Access Logging**: Detailed request/response logging
- **Throttling**: Rate limiting and burst protection
- **Error Responses**: Standardized error response format

### Lambda Functions

| Function | Language | Runtime | Purpose |
|----------|----------|---------|---------|
| CreateItem | Go | provided.al2023 | Create new items |
| GetItem | Node.js | nodejs20.x | Retrieve items by ID |
| UpdateItem | Node.js | nodejs20.x | Update existing items |
| DeleteItem | Go | provided.al2023 | Delete items |

### DynamoDB Configuration

- **Table**: Auto-named based on stack name
- **Billing**: Pay-per-request (on-demand)
- **GSI**: Category-based queries with createdAt sort key
- **Backup**: Point-in-time recovery enabled
- **Streams**: Enabled for change tracking

## Environment Variables

All Lambda functions receive these environment variables:

- `DYNAMODB_TABLE_NAME`: Name of the DynamoDB table
- `STAGE`: Deployment stage (dev/staging/prod)
- `LOG_LEVEL`: Logging level (DEBUG/INFO/WARN/ERROR)
- `AWS_NODEJS_CONNECTION_REUSE_ENABLED`: Connection pooling for Node.js

## Monitoring and Logging

### CloudWatch Logs

- API Gateway access logs: `/aws/apigateway/{stack-name}-{stage}`
- Lambda function logs: `/aws/lambda/{function-name}`

### X-Ray Tracing

All Lambda functions have X-Ray tracing enabled for distributed debugging.

### Metrics

- API Gateway: Request count, latency, error rates
- Lambda: Invocation count, duration, error rates, cold starts
- DynamoDB: Read/write capacity, throttling

## Security

### IAM Roles

Each Lambda function has its own execution role with minimal permissions:

- **CreateItem**: DynamoDB PutItem permissions
- **GetItem**: DynamoDB GetItem permissions
- **UpdateItem**: DynamoDB GetItem and UpdateItem permissions
- **DeleteItem**: DynamoDB GetItem and DeleteItem permissions

### API Security

- CORS configured for web access
- Request validation at API Gateway level
- Input sanitization in Lambda functions
- Error messages don't leak sensitive information

## Deployment Outputs

After successful deployment, you'll get these outputs:

- **ApiUrl**: The API Gateway endpoint URL
- **ApiId**: API Gateway ID for further configuration
- **ItemsTableName**: DynamoDB table name
- **Function ARNs**: ARNs for all Lambda functions

## Troubleshooting

### Common Issues

1. **Go Build Errors**: Ensure Go 1.21+ is installed and `GOOS=linux GOARCH=amd64` is set
2. **Node.js Dependencies**: Run `npm install` in function directories
3. **Permission Errors**: Check AWS credentials and IAM permissions
4. **Stack Exists**: Use `--stack-name` to specify a unique name

### Logs and Debugging

```bash
# View API Gateway logs
aws logs tail /aws/apigateway/serverless-crud-api-dev --follow

# View Lambda function logs
aws logs tail /aws/lambda/serverless-crud-api-dev-create-item --follow

# Get stack events
aws cloudformation describe-stack-events --stack-name serverless-crud-api-dev
```

### Cleanup

To delete all stacks:

```bash
# Interactive cleanup (with confirmation)
./scripts/cleanup.sh --stage dev --region us-east-1

# Force cleanup (no confirmation)
./scripts/cleanup.sh --stage dev --region us-east-1 --force
```

Or manually delete in reverse dependency order:
```bash
aws cloudformation delete-stack --stack-name serverless-crud-api-dev-monitoring
aws cloudformation delete-stack --stack-name serverless-crud-api-dev-lambda
aws cloudformation delete-stack --stack-name serverless-crud-api-dev-api
aws cloudformation delete-stack --stack-name serverless-crud-api-dev-foundation
```

## Local Development

For local development and testing:

```bash
# Start local API
sam local start-api --template template.yaml

# Invoke specific function
sam local invoke CreateItemFunction --event ../events/create-item.json

# Start local DynamoDB
docker run -p 8000:8000 amazon/dynamodb-local
```

## API Documentation

The complete API documentation is available in `../docs/api-spec.yaml` (OpenAPI 3.0 format).

## Support

For issues and questions:

1. Check the troubleshooting section above
2. Review CloudWatch logs for error details
3. Validate the SAM template: `sam validate --template template.yaml --lint`
4. Check AWS service limits and quotas