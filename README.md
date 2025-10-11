# Serverless CRUD API

A serverless CRUD API built with AWS Lambda, API Gateway, and DynamoDB, featuring a multi-language approach and complete CI/CD pipeline using GitHub Actions.

## Architecture

- **API Gateway**: RESTful API endpoints
- **Lambda Functions**: 
  - Create Item (Go) - Optimized for performance
  - Get Item (Node.js) - Fast cold starts
  - Update Item (Node.js) - Balanced performance
  - Delete Item (Go) - Minimal overhead
- **Database**: DynamoDB for scalable data storage
- **CI/CD**: GitHub Actions for automated deployment

## Project Structure

```
.
├── .kiro/                     # Kiro AI assistant configuration
│   ├── steering/              # AI guidance documents
│   └── specs/                 # Feature specifications
│       └── serverless-crud-api/
│           ├── requirements.md # Feature requirements
│           ├── design.md      # Technical design
│           └── tasks.md       # Implementation tasks
├── functions/                 # Lambda function implementations
│   ├── create-item/          # Go - Create operations
│   ├── get-item/             # Node.js - Read operations
│   ├── update-item/          # Node.js - Update operations
│   └── delete-item/          # Go - Delete operations
├── infrastructure/           # Multi-stack AWS SAM templates
│   ├── stacks/              # CloudFormation stack templates
│   ├── scripts/             # Deployment automation
│   ├── DEPLOYMENT_GUIDE.md  # 📖 Complete deployment guide
│   └── ARCHITECTURE.md      # 🏗️ Architecture documentation
├── docs/                    # API documentation
└── .github/workflows/       # GitHub Actions CI/CD
```

## 🚀 Quick Start

### Deploy the API
```bash
cd infrastructure
./scripts/deploy-all.sh --stage dev --region us-east-1
```

### Test the API
```bash
# Get the API URL from deployment output, then:
curl -X POST https://your-api-url/dev/items \
  -H 'Content-Type: application/json' \
  -d '{"name":"Test Item","category":"electronics","price":29.99}'
```

### Clean Up
```bash
./scripts/cleanup.sh --stage dev
```

## 📖 Documentation

- **[Deployment Guide](./infrastructure/DEPLOYMENT_GUIDE.md)** - Complete deployment scenarios and troubleshooting
- **[Architecture Guide](./infrastructure/ARCHITECTURE.md)** - Multi-stack architecture details
- **[API Documentation](./docs/api-spec.yaml)** - OpenAPI specification
- **[Requirements](./kiro/specs/serverless-crud-api/requirements.md)** - Feature requirements
- **[Design](./kiro/specs/serverless-crud-api/design.md)** - Technical design decisions

## Development

Built with Kiro AI assistant for enhanced development productivity.