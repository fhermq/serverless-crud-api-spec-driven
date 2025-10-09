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

### GitHub Actions Workflow

```yaml
# Workflow stages
1. Code Quality Checks
   - Linting (language-specific)
   - Security scanning
   - Dependency vulnerability checks

2. Unit Testing
   - Go: go test
   - Node.js: npm test
   - Coverage reporting

3. Build & Package
   - Go: Build binaries
   - Node.js: Install dependencies
   - Create deployment packages

4. Infrastructure Deployment
   - Deploy CloudFormation/SAM templates
   - Update API Gateway configuration
   - Deploy Lambda functions

5. Integration Testing
   - Run API tests against deployed environment
   - Validate database operations
   - Performance benchmarks

6. Deployment Verification
   - Health checks
   - Smoke tests
   - Rollback on failure
```

### Environment Strategy
- **Development**: Feature branch deployments
- **Staging**: Main branch deployments for testing
- **Production**: Tagged releases with manual approval

### Security Considerations
- **API Authentication**: API Keys or JWT tokens
- **Database Security**: IAM roles and policies
- **Secrets Management**: AWS Secrets Manager for sensitive data
- **Network Security**: VPC configuration if required
- **Data Encryption**: Encryption in transit and at rest

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
└── .github/workflows/        # CI/CD pipelines
    ├── deploy-functions.yml  # Function deployment
    └── integration-tests.yml # Cross-function testing
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