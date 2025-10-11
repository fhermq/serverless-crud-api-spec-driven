# Development Guide

## Project Structure

This project follows a multi-language serverless architecture with the following structure:

```
├── functions/                 # Lambda functions
│   ├── create-item/          # Go - Create item function
│   ├── get-item/             # Node.js - Get item function
│   ├── update-item/          # Node.js - Update item function
│   └── delete-item/          # Go - Delete item function
├── shared/                   # Shared components and contracts
│   ├── models/              # TypeScript interfaces and types
│   ├── utils/               # Utility functions
│   └── contracts/           # API contracts and schemas
├── infrastructure/          # Multi-stack Infrastructure as Code
│   ├── stacks/              # CloudFormation stack templates
│   │   ├── 01-foundation.yaml     # DynamoDB + IAM roles
│   │   ├── 02-api-and-functions.yaml # API Gateway + Lambda functions
│   │   └── 04-monitoring.yaml     # CloudWatch + alarms
│   ├── scripts/             # Deployment automation scripts
│   ├── parameters/          # Environment-specific parameters
│   ├── DEPLOYMENT_GUIDE.md  # Complete deployment guide
│   └── ARCHITECTURE.md      # Multi-stack architecture details
├── .github/workflows/       # CI/CD pipelines
├── docs/                    # API documentation
└── events/                  # Test events for local development
```

## Getting Started

### Prerequisites

- **Node.js** 18.x or 20.x
- **Go** 1.21 or later
- **Docker** and Docker Compose
- **AWS CLI** configured with appropriate credentials
- **SAM CLI** for local development and deployment
- **AWS Toolkit for VS Code** extension installed

### Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd serverless-crud-api
   ```

2. **Start local development environment**
   ```bash
   docker-compose up -d
   ```

3. **Configure AWS credentials**
   ```bash
   # Configure AWS CLI
   aws configure
   
   # Or set environment variables
   export AWS_ACCESS_KEY_ID=your_access_key
   export AWS_SECRET_ACCESS_KEY=your_secret_key
   export AWS_DEFAULT_REGION=us-east-1
   ```

4. **Install dependencies**
   ```bash
   # Install root dependencies
   npm install
   
   # Install Node.js function dependencies
   cd functions/get-item && npm install
   cd ../update-item && npm install
   
   # Install Go dependencies
   cd ../create-item && go mod tidy
   cd ../delete-item && go mod tidy
   ```

4. **Start local API**
   ```bash
   ./scripts/start-local-api.sh
   ```

## Quality Assurance System

This project enforces Lambda function best practices through multiple layers to ensure consistency and prevent missing critical checks:

### 1. Best Practices Documentation
- **[Lambda Best Practices Guide](.kiro/steering/lambda-best-practices.md)** - Comprehensive checklist for all functions
- **Pull Request Template** - Automated checklist for code reviews  
- **Function Templates** - Use `functions/get-item/` as reference implementation

### 2. Automated Validation Tools
```bash
# Install pre-commit hooks (recommended)
pip install pre-commit
pre-commit install

# Validate all function structures
python3 scripts/validate-lambda-structure.py

# Check specific function before committing
./scripts/check-function.sh functions/get-item

# Validate package.json files
python3 scripts/validate-package-json.py
```

### 3. CI/CD Quality Gates
- **Structure validation** - Ensures proper file organization and required files
- **Code quality** - Linting, formatting, security scans for all functions
- **Test coverage** - Minimum 80% coverage required across all functions
- **Security scanning** - Vulnerability detection and hardcoded value checks
- **Performance benchmarks** - Cold start and execution time monitoring

### 4. Function Development Checklist
Before committing any Lambda function, ensure:

✅ **Structure**: Required files present (package.json/go.mod, main file, README.md, tests)  
✅ **Dependencies**: Uses shared utilities and proper AWS SDK versions  
✅ **Error Handling**: Comprehensive error handling with proper HTTP status codes  
✅ **Logging**: Structured logging with request context and timing  
✅ **Validation**: Input validation using shared utilities  
✅ **Testing**: >80% test coverage with happy path, error, and edge cases  
✅ **Security**: No hardcoded values, proper CORS, input sanitization  
✅ **Documentation**: Complete README with setup and API documentation  

### 5. Creating New Lambda Functions

Follow this workflow to ensure best practices compliance:

```bash
# 1. Create function directory using template
mkdir functions/new-function
cd functions/new-function

# 2. Copy structure from reference implementation
cp -r ../get-item/* .
# Modify files for your specific function

# 3. Run quality check before committing
cd ../..
./scripts/check-function.sh functions/new-function

# 4. Commit only after all checks pass
git add functions/new-function
git commit -m "feat: add new-function Lambda"
```

## Development Workflow

### Language-Specific Development

#### Go Functions (create-item, delete-item)

```bash
# Navigate to function directory
cd functions/create-item  # or delete-item

# Install dependencies
go mod tidy

# Run tests
go test -v

# Run linting
golangci-lint run

# Build function
go build -o main main.go

# Test locally with SAM
sam local invoke CreateItemFunction -e ../../events/create-item-event.json
```

#### Node.js Functions (get-item, update-item)

```bash
# Navigate to function directory
cd functions/get-item  # or update-item

# Install dependencies
npm install

# Run tests
npm test

# Run tests with coverage
npm run test:coverage

# Run linting
npm run lint

# Fix linting issues
npm run lint:fix

# Test locally with SAM
sam local invoke GetItemFunction -e ../../events/get-item-event.json
```

### Code Quality Standards

#### ESLint Configuration
- Extends recommended ESLint and TypeScript rules
- Enforces consistent code style across Node.js functions
- Configured for Lambda-specific best practices

#### Go Linting
- Uses golangci-lint with comprehensive rule set
- Enforces Go best practices and performance optimizations
- Configured for AWS Lambda Go runtime

#### Prettier Configuration
- Consistent code formatting across all files
- Integrated with ESLint for seamless development
- Supports multiple file types (JS, TS, JSON, YAML)

### Testing Strategy

#### Unit Testing
- **Go**: Use built-in `go test` framework
- **Node.js**: Use Jest testing framework
- **Coverage**: Minimum 80% code coverage target
- **Mocking**: Mock AWS services for isolated testing

#### Integration Testing
- API-level testing with real AWS services
- Cross-function workflow testing
- Database integration testing with local DynamoDB

#### Local Testing
```bash
# Test all functions
npm run test:all

# Test specific language
npm run test:node
npm run test:go

# Test individual function
cd functions/create-item && go test -v
cd functions/get-item && npm test
```

## Local Development Environment

### Docker Compose Services

- **DynamoDB Local**: Local DynamoDB instance on port 8000
- **DynamoDB Admin**: Web UI for DynamoDB on port 8001
- **LocalStack**: Local AWS services simulation on port 4566

### Development Containers

The project includes VS Code dev containers for consistent development:

```bash
# Start with Go development container
docker-compose --profile go-dev up -d

# Start with Node.js development container
docker-compose --profile node-dev up -d
```

### Local API Testing

```bash
# Start local API server
./scripts/start-local-api.sh

# Seed test data
./scripts/seed-test-data.sh

# Test individual functions
./scripts/test-functions.sh
```

## API Development

### OpenAPI Specification

The API is fully documented using OpenAPI 3.0 specification:
- **Location**: `docs/api-spec.yaml`
- **Validation**: Run `npm run validate:api` to validate the spec
- **Documentation**: Auto-generated from the OpenAPI spec

### API Contract Testing

```bash
# Validate API specification
npm run validate:api

# Test API contracts (requires running API)
newman run postman/api-tests.json --environment postman/local-env.json
```

## Deployment

### Environment Configuration

Three environments are supported:
- **dev**: Development environment for feature testing
- **staging**: Pre-production environment for integration testing
- **prod**: Production environment

### Multi-Stack Deployment Commands

```bash
# Deploy all stacks (recommended for first time)
cd infrastructure
./scripts/deploy-all.sh --stage dev --region us-east-1

# Deploy individual stacks (for targeted updates)
./scripts/deploy-foundation.sh --stage dev        # DynamoDB + IAM
./scripts/deploy-api-and-functions.sh --stage dev # API + Lambda functions
./scripts/deploy-monitoring.sh --stage dev       # CloudWatch + alarms

# Environment-specific deployments
./scripts/deploy-all.sh --stage staging --region us-east-1
./scripts/deploy-all.sh --stage prod --region us-west-2

# Cleanup all stacks
./scripts/cleanup.sh --stage dev
```

> 📖 **For detailed deployment scenarios and troubleshooting, see [infrastructure/DEPLOYMENT_GUIDE.md](./infrastructure/DEPLOYMENT_GUIDE.md)**

### CI/CD Pipeline

GitHub Actions workflows handle:
- **Code Quality**: Linting, formatting, type checking
- **Testing**: Unit tests, integration tests, coverage reporting
- **Building**: Language-specific builds and packaging
- **Deployment**: Environment-specific deployments
- **Monitoring**: Post-deployment health checks

## Team Collaboration

### Branch Strategy

- `main`: Production-ready code
- `develop`: Integration branch for development
- `feature/*`: Individual feature development
- `hotfix/*`: Production hotfixes

### Function-Specific Development

Each team member can work independently on their assigned function:

1. **Create Item** (Go) - Team Member A
2. **Get Item** (Node.js) - Team Member B
3. **Update Item** (Node.js) - Team Member C
4. **Delete Item** (Go) - Team Member D

### Code Review Process

- All changes require pull request review
- Language-specific experts review their domain
- Architecture reviews for cross-function changes
- Automated quality gates in CI/CD

### Communication

- **Daily Standups**: Coordinate integration points
- **Sprint Planning**: Align function development with API milestones
- **Architecture Decisions**: Document in ADRs (Architecture Decision Records)

## Troubleshooting

### Common Issues

#### Local Development
```bash
# DynamoDB connection issues
docker-compose restart dynamodb-local

# SAM build issues
sam build --use-container

# Port conflicts
docker-compose down && docker-compose up -d
```

#### Function Development
```bash
# Go module issues
go mod tidy && go mod download

# Node.js dependency issues
rm -rf node_modules package-lock.json && npm install

# AWS credentials
aws configure list
```

### Debugging

#### Local Function Debugging
```bash
# Debug Go function
dlv debug --headless --listen=:2345 --api-version=2

# Debug Node.js function
node --inspect-brk=0.0.0.0:9229 index.js
```

#### CloudWatch Logs
```bash
# View function logs
aws logs tail /aws/lambda/serverless-crud-api-dev-create-item --follow

# View API Gateway logs
aws logs tail API-Gateway-Execution-Logs_<api-id>/<stage> --follow
```

## Performance Optimization

### Lambda Optimization
- **Go**: Compile with optimizations, minimize binary size
- **Node.js**: Use AWS SDK v3, minimize dependencies
- **Cold Starts**: Implement connection pooling, lazy loading

### DynamoDB Optimization
- **Single Table Design**: Minimize cross-table operations
- **GSI Usage**: Optimize query patterns
- **Batch Operations**: Use batch reads/writes where possible

### Monitoring
- **CloudWatch Metrics**: Monitor function duration, memory usage
- **X-Ray Tracing**: Distributed tracing for performance analysis
- **Custom Metrics**: Business-specific performance indicators

## Security Best Practices

### Function Security
- **IAM Roles**: Least privilege access
- **Environment Variables**: Use AWS Secrets Manager for sensitive data
- **Input Validation**: Validate all inputs at function entry points

### API Security
- **Authentication**: API key or JWT token validation
- **CORS**: Proper CORS configuration
- **Rate Limiting**: Implement throttling and usage plans

### Data Security
- **Encryption**: Encrypt data in transit and at rest
- **Access Logging**: Log all data access operations
- **Data Validation**: Sanitize and validate all data inputs