# Design Document

## Overview

This design implements a serverless CRUD API using AWS services with a polyglot approach to Lambda functions. The architecture leverages API Gateway as the entry point, multiple Lambda functions written in different languages optimized for their specific operations, and a database backend. The entire system is deployed and managed through GitHub Actions CI/CD pipeline.

## Architecture

### High-Level Architecture

```
GitHub Repository
       ↓
GitHub Actions Pipeline
       ↓
AWS CloudFormation/SAM
       ↓
┌─────────────────────────────────────────────────────────────┐
│                    AWS Cloud                                │
│                                                             │
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │   API Gateway   │    │        Lambda Functions         │ │
│  │                 │    │                                 │ │
│  │  POST /items    │────┤  Create Item (Go)              │ │
│  │  GET /items/{id}│────┤  Get Item (Node.js)            │ │
│  │  PUT /items/{id}│────┤  Update Item (Node.js)         │ │
│  │  DELETE /items  │────┤  Delete Item (Go)              │ │
│  └─────────────────┘    └─────────────────────────────────┘ │
│                                        ↓                    │
│                         ┌─────────────────────────────────┐ │
│                         │        Database Layer          │ │
│                         │                                 │ │
│                         │  DynamoDB (Primary)             │ │
│                         │  - Items Table                  │ │
│                         │  - GSI for queries              │ │
│                         └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Language Selection Rationale

| Operation | Language | Rationale |
|-----------|----------|-----------|
| Create Item | Go | Fast execution, efficient memory usage, excellent for write operations |
| Get Item | Node.js | Fastest cold starts, minimal overhead for simple read operations |
| Update Item | Node.js | Good balance of performance and development speed for data manipulation |
| Delete Item | Go | Minimal resource usage, fast execution for simple operations |

## Components and Interfaces

### API Gateway Configuration

**Base URL**: `https://api.{domain}/v1`

**Endpoints**:
- `POST /items` - Create new item
- `GET /items/{id}` - Retrieve item by ID
- `PUT /items/{id}` - Update existing item
- `DELETE /items/{id}` - Delete item by ID

**Request/Response Format**:
```json
// Item Schema
{
  "id": "string (UUID)",
  "name": "string",
  "description": "string",
  "category": "string",
  "price": "number",
  "createdAt": "string (ISO 8601)",
  "updatedAt": "string (ISO 8601)"
}
```

### Lambda Functions

#### 1. Create Item Function (Go)
```go
// Handler signature
func HandleRequest(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error)
```

**Responsibilities**:
- Validate input data
- Generate UUID for new item
- Set timestamps
- Store in DynamoDB
- Return created item

#### 2. Get Item Function (Node.js)
```javascript
// Handler signature
exports.handler = async (event, context) => { ... }
```

**Responsibilities**:
- Extract item ID from path parameters
- Query DynamoDB by ID
- Return item or 404 error

#### 3. Update Item Function (Node.js)
```javascript
// Handler signature
exports.handler = async (event, context) => { ... }
```

**Responsibilities**:
- Validate input data
- Check if item exists
- Update item with new data
- Update timestamp
- Return updated item

#### 4. Delete Item Function (Go)
```go
// Handler signature
func HandleRequest(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error)
```

**Responsibilities**:
- Extract item ID from path parameters
- Delete item from DynamoDB
- Return 204 No Content

### Database Layer

**Primary Database**: Amazon DynamoDB

**Table Structure**:
```
Table Name: Items
Partition Key: id (String)
Attributes:
- id: String (UUID)
- name: String
- description: String
- category: String
- price: Number
- createdAt: String (ISO 8601)
- updatedAt: String (ISO 8601)

Global Secondary Index (Optional):
- GSI Name: CategoryIndex
- Partition Key: category
- Sort Key: createdAt
```

## Data Models

### Item Model
```typescript
interface Item {
  id: string;           // UUID v4
  name: string;         // Required, 1-100 characters
  description?: string; // Optional, max 500 characters
  category: string;     // Required, predefined categories
  price: number;        // Required, positive number
  createdAt: string;    // ISO 8601 timestamp
  updatedAt: string;    // ISO 8601 timestamp
}
```

### API Request/Response Models

**Create Item Request**:
```json
{
  "name": "string",
  "description": "string",
  "category": "string",
  "price": number
}
```

**Update Item Request**:
```json
{
  "name": "string",
  "description": "string",
  "category": "string",
  "price": number
}
```

**Error Response**:
```json
{
  "error": "string",
  "message": "string",
  "details": ["string"]
}
```

## Error Handling

### HTTP Status Codes
- `200 OK` - Successful GET/PUT operations
- `201 Created` - Successful POST operations
- `204 No Content` - Successful DELETE operations
- `400 Bad Request` - Invalid input data
- `401 Unauthorized` - Missing or invalid authentication
- `403 Forbidden` - Insufficient permissions
- `404 Not Found` - Item not found
- `500 Internal Server Error` - Server-side errors
- `503 Service Unavailable` - Database unavailable

### Error Response Strategy
1. **Client Errors (4xx)**: Return detailed error messages with validation details
2. **Server Errors (5xx)**: Return generic error messages, log detailed errors internally
3. **Database Errors**: Map DynamoDB errors to appropriate HTTP status codes
4. **Validation Errors**: Return field-specific error messages

### Logging Strategy
- **Request/Response Logging**: Log all API requests and responses
- **Error Logging**: Detailed error logs with stack traces
- **Performance Logging**: Execution time and memory usage
- **Security Logging**: Authentication and authorization events

## Testing Strategy

### Unit Testing
- **Go Functions**: Use Go's built-in testing framework
- **Node.js Functions**: Use Jest testing framework
- **Coverage Target**: Minimum 80% code coverage
- **Test Categories**: Happy path, error cases, edge cases

### Integration Testing
- **API Testing**: Test complete request/response cycles
- **Database Testing**: Test DynamoDB operations
- **Cross-Function Testing**: Test data consistency across operations

### End-to-End Testing
- **Postman Collections**: Automated API testing
- **GitHub Actions Integration**: Run tests in CI/CD pipeline
- **Environment Testing**: Test against deployed infrastructure

### Performance Testing
- **Load Testing**: Test API under various load conditions
- **Cold Start Testing**: Measure Lambda cold start times
- **Database Performance**: Test DynamoDB read/write performance

## DevOps Pipeline Design

### OIDC Security Architecture

**Authentication Flow**:
```
GitHub Actions Workflow
       ↓
OIDC Token Request to GitHub
       ↓
AWS STS AssumeRoleWithWebIdentity
       ↓
Temporary AWS Credentials (1 hour expiry)
       ↓
AWS Resource Access (Deployment)
```

**OIDC Configuration**:
- **Identity Provider**: `https://token.actions.githubusercontent.com`
- **Audience**: `sts.amazonaws.com`
- **Trust Policy**: Repository and branch specific
- **IAM Role**: Least privilege deployment permissions
- **Credential Expiry**: Maximum 1 hour

### GitHub Actions Workflow

```yaml
# Workflow stages with OIDC Security
1. OIDC Authentication
   - Configure AWS credentials using OIDC
   - Assume deployment role with temporary credentials
   - Validate authentication success

2. Code Quality Checks
   - Linting (language-specific)
   - Security scanning
   - Dependency vulnerability checks

3. Unit Testing
   - Go: go test
   - Node.js: npm test
   - Coverage reporting

4. Build & Package
   - Go: Build binaries
   - Node.js: Install dependencies
   - Create deployment packages

5. Infrastructure Deployment (Secure)
   - Deploy CloudFormation/SAM templates using OIDC credentials
   - Update API Gateway configuration
   - Deploy Lambda functions with temporary credentials

6. Integration Testing
   - Run API tests against deployed environment
   - Validate database operations
   - Performance benchmarks

7. Deployment Verification
   - CloudFormation stack validation
   - API endpoint accessibility
   - Basic functionality testing
```

### Environment Strategy
- **Development**: Feature branch deployments with OIDC
- **Staging**: Main branch deployments for testing with OIDC
- **Production**: Tagged releases with manual approval and OIDC

### Complete IAM Role Architecture

#### Role Types and Responsibilities

**1. OIDC Deployment Role** (`GitHubActions-ServerlessCRUD-DeployRole`)
- **Purpose**: Used by GitHub Actions for deployment
- **Authentication**: OIDC temporary credentials (1 hour max)
- **Permissions**: Infrastructure deployment, role creation, Lambda deployment
- **Usage**: CI/CD pipeline only

**2. Lambda Execution Roles** (Function-specific)
- **CreateItemExecutionRole**: Runtime role for create-item function
- **GetItemExecutionRole**: Runtime role for get-item function  
- **UpdateItemExecutionRole**: Runtime role for update-item function
- **DeleteItemExecutionRole**: Runtime role for delete-item function

#### Role Assignment Flow
```
GitHub Actions (OIDC) → Deployment Role → Creates/Updates Lambda Functions → Assigns Execution Roles
                                    ↓
                            Lambda Functions at Runtime → Use Execution Roles → Access DynamoDB
```

### OIDC Implementation Details

#### AWS Setup Requirements
1. **OIDC Identity Provider Creation**:
   - Provider URL: `https://token.actions.githubusercontent.com`
   - Thumbprint: GitHub's certificate thumbprint
   - Audience: `sts.amazonaws.com`

2. **IAM Role Configuration**:
   - Trust relationship with OIDC provider
   - Repository-specific conditions
   - Branch-specific restrictions
   - Time-limited session duration (1 hour max)

3. **Permission Boundaries**:
   - CloudFormation stack operations
   - Lambda function deployment
   - API Gateway configuration
   - DynamoDB table management
   - S3 bucket access for artifacts

#### GitHub Actions Configuration
```yaml
name: Deploy Serverless CRUD API
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  id-token: write   # Required for OIDC
  contents: read    # Required for checkout

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Configure AWS credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOYMENT_ROLE_ARN }}
          role-session-name: GitHubActions-ServerlessCRUD
          aws-region: us-east-1
          
      - name: Verify OIDC authentication
        run: aws sts get-caller-identity
```

#### Security Validation
- **Pre-deployment Checks**: Validate OIDC token before deployment
- **Credential Expiry**: Ensure credentials expire within 1 hour
- **Access Logging**: Log all AWS API calls via CloudTrail
- **Failure Handling**: Fail deployment if OIDC authentication fails
- **Rollback Security**: Secure rollback procedures using OIDC

### Security Considerations

#### Deployment Security (OIDC)
- **No Long-lived Credentials**: Zero AWS access keys stored in GitHub
- **OIDC Authentication**: OpenID Connect for secure AWS access
- **Temporary Credentials**: 1-hour maximum credential lifetime
- **Repository Restrictions**: Trust policy limited to specific repo/branch
- **Least Privilege IAM**: Deployment role with minimal required permissions
- **Audit Trail**: CloudTrail logging of all OIDC-based deployments

#### Runtime Security
- **API Authentication**: API Keys or JWT tokens
- **Lambda Execution Roles**: Function-specific IAM roles for runtime operations
- **Database Security**: IAM roles and policies for DynamoDB access
- **Secrets Management**: AWS Secrets Manager for sensitive data
- **Network Security**: VPC configuration if required
- **Data Encryption**: Encryption in transit and at rest

#### Lambda Execution Roles Design
Each Lambda function will have its own execution role with minimal permissions:

**Base Lambda Execution Role**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

**DynamoDB Access Policy (attached to each function role)**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": [
        "arn:aws:dynamodb:*:*:table/Items",
        "arn:aws:dynamodb:*:*:table/Items/index/*"
      ]
    }
  ]
}
```

**Function-Specific Roles**:
- **CreateItemRole**: PutItem permissions only
- **GetItemRole**: GetItem and Query permissions only  
- **UpdateItemRole**: GetItem and UpdateItem permissions only
- **DeleteItemRole**: GetItem and DeleteItem permissions only

#### OIDC IAM Role Design
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:ORG/REPO:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

#### Deployment Permissions Policy (OIDC Role)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:*",
        "lambda:*",
        "apigateway:*",
        "dynamodb:*",
        "iam:PassRole",
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:DeleteRole",
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": ["us-east-1", "us-west-2"]
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": [
        "arn:aws:iam::*:role/ServerlessCRUD-*-ExecutionRole"
      ],
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "lambda.amazonaws.com"
        }
      }
    }
  ]
}
```

#### Role Separation Strategy
1. **OIDC Deployment Role**: Used by GitHub Actions to deploy infrastructure
   - Can create/update Lambda functions
   - Can create/manage execution roles
   - Can pass execution roles to Lambda functions
   
2. **Lambda Execution Roles**: Used by Lambda functions at runtime
   - Function-specific permissions (least privilege)
   - DynamoDB access based on operation type
   - CloudWatch Logs access for monitoring

### Monitoring and Observability
- **CloudWatch Logs**: Centralized logging
- **CloudWatch Metrics**: Performance monitoring
- **X-Ray Tracing**: Distributed tracing
- **Custom Dashboards**: Business metrics and KPIs

## Team Collaboration Strategy

### Project Structure for Multi-Developer Teams

```
├── shared/                    # Shared components and contracts
│   ├── models/               # Common data models and interfaces
│   ├── utils/                # Shared utility functions
│   ├── contracts/            # API contracts and schemas
│   └── testing/              # Shared testing utilities
├── functions/                # Individual Lambda functions
│   ├── create-item/          # Go - Team Member A
│   │   ├── main.go
│   │   ├── go.mod
│   │   ├── handler_test.go
│   │   └── README.md
│   ├── get-item/             # Node.js - Team Member B
│   │   ├── index.js
│   │   ├── package.json
│   │   ├── handler.test.js
│   │   └── README.md
│   ├── update-item/          # Node.js - Team Member C
│   │   ├── index.js
│   │   ├── package.json
│   │   ├── handler.test.js
│   │   └── README.md
│   └── delete-item/          # Go - Team Member D
│       ├── main.go
│       ├── go.mod
│       ├── handler_test.go
│       └── README.md
├── infrastructure/           # Infrastructure as Code
│   ├── template.yaml         # SAM template
│   ├── parameters/           # Environment-specific parameters
│   └── scripts/              # Deployment scripts
└── .github/workflows/        # CI/CD pipelines (optional)
    └── (no workflows currently configured)
```

### Development Workflow for Teams

#### 1. Contract-First Development
- **API Contracts**: Define OpenAPI specifications before implementation
- **Data Models**: Establish shared TypeScript interfaces in `shared/models/`
- **Error Handling**: Standardized error response formats
- **Testing Contracts**: Shared test utilities and mock data

#### 2. Independent Function Development
Each developer can work independently on their assigned Lambda function:

**Branch Strategy**:
- `main` - Production-ready code
- `develop` - Integration branch
- `feature/create-item` - Individual function development
- `feature/get-item` - Individual function development
- `feature/update-item` - Individual function development
- `feature/delete-item` - Individual function development

#### 3. Decoupled CI/CD Pipeline

**Function-Specific Pipelines**:
```yaml
# Triggered only when specific function code changes
on:
  push:
    paths:
      - 'functions/create-item/**'
      - 'shared/**'
```

**Deployment Strategy**:
- **Individual Function Deployment**: Deploy only changed functions
- **Shared Component Updates**: Trigger all function rebuilds
- **Infrastructure Changes**: Coordinate team-wide deployments

#### 4. Local Development Environment

**Docker Compose Setup**:
```yaml
version: '3.8'
services:
  dynamodb-local:
    image: amazon/dynamodb-local
    ports:
      - "8000:8000"
  
  api-gateway-local:
    image: localstack/localstack
    environment:
      - SERVICES=apigateway,lambda
    ports:
      - "4566:4566"
```

**Function-Specific Development**:
- Each function has its own `docker-compose.override.yml`
- Local testing with SAM CLI: `sam local start-api`
- Independent function testing: `sam local invoke CreateItemFunction`

#### 5. Integration Testing Strategy

**Contract Testing**:
- **Pact Testing**: Consumer-driven contract testing between functions
- **Schema Validation**: Ensure API responses match contracts
- **Mock Services**: Mock external dependencies for isolated testing

**Cross-Function Integration**:
- **End-to-End Tests**: Test complete CRUD workflows
- **Data Consistency Tests**: Verify data integrity across operations
- **Performance Tests**: Load testing with multiple functions

#### 6. Code Quality and Standards

**Language-Specific Standards**:
- **Go**: Use `gofmt`, `golint`, and `go vet`
- **Node.js**: Use ESLint, Prettier, and Jest
- **Shared Standards**: EditorConfig for consistent formatting

**Code Review Process**:
- **Function-Specific Reviews**: Domain experts review their language
- **Cross-Function Reviews**: Architecture and integration reviews
- **Automated Checks**: Pre-commit hooks and CI quality gates

#### 7. Communication and Coordination

**Documentation Strategy**:
- **Function README**: Each function has comprehensive documentation
- **API Documentation**: Auto-generated from OpenAPI specs
- **Architecture Decision Records (ADRs)**: Document major decisions

**Team Coordination**:
- **Daily Standups**: Coordinate integration points
- **Sprint Planning**: Align function development with API milestones
- **Integration Windows**: Scheduled times for cross-function testing

### Conflict Resolution and Dependencies

#### Shared Component Changes
- **Semantic Versioning**: Version shared components
- **Backward Compatibility**: Maintain compatibility during transitions
- **Migration Guides**: Document breaking changes and migration paths

#### Database Schema Changes
- **Migration Scripts**: Coordinate database changes
- **Feature Flags**: Enable gradual rollout of schema changes
- **Rollback Strategy**: Plan for reverting schema changes

#### API Contract Changes
- **Versioning Strategy**: API versioning for breaking changes
- **Deprecation Policy**: Gradual deprecation of old endpoints
- **Consumer Notification**: Alert consuming teams of changes