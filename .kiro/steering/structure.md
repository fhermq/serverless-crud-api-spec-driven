# Project Structure

## Current Organization
```
.
├── .kiro/                 # Kiro AI assistant configuration
│   ├── steering/          # AI guidance documents
│   │   ├── product.md     # Product overview and purpose
│   │   ├── tech.md        # Technology stack and commands
│   │   ├── structure.md   # Project organization (this file)
│   │   └── lambda-best-practices.md # Lambda development standards
│   └── specs/             # Feature specifications
│       └── serverless-crud-api/
│           ├── requirements.md # Feature requirements
│           ├── design.md      # Technical design
│           └── tasks.md       # Implementation tasks
├── functions/             # Lambda function implementations
├── infrastructure/        # Multi-stack AWS SAM templates
├── docs/                  # API documentation
├── scripts/               # Utility scripts
└── .github/workflows/     # GitHub Actions CI/CD
```

## Multi-Language Lambda Functions Structure
```
functions/
├── create-item/           # Go - Create operations
│   ├── main.go           # Handler implementation
│   ├── logger.go         # Structured logging utility
│   ├── main_test.go      # Unit tests
│   ├── go.mod            # Go module definition
│   └── README.md         # Function documentation
├── get-item/             # Node.js - Read operations
│   ├── index.js          # Handler implementation
│   ├── index.test.js     # Unit tests
│   ├── package.json      # Node.js dependencies
│   └── README.md         # Function documentation
├── update-item/          # Node.js - Update operations
│   ├── index.js          # Handler implementation
│   ├── index.test.js     # Unit tests
│   ├── package.json      # Node.js dependencies
│   └── README.md         # Function documentation
└── delete-item/          # Go - Delete operations
    ├── main.go           # Handler implementation
    ├── logger.go         # Structured logging utility
    ├── main_test.go      # Unit tests
    ├── go.mod            # Go module definition
    └── README.md         # Function documentation
```

## Multi-Stack Infrastructure
```
infrastructure/
├── stacks/                    # CloudFormation stack templates
│   ├── 01-foundation.yaml     # DynamoDB + IAM roles
│   ├── 02-api-and-functions.yaml # API Gateway + Lambda functions
│   └── 04-monitoring.yaml     # CloudWatch + alarms
├── scripts/                   # Deployment automation
│   ├── deploy-all.sh          # Deploy all stacks
│   ├── deploy-foundation.sh   # Deploy foundation only
│   ├── deploy-api-and-functions.sh # Deploy API + functions
│   ├── deploy-monitoring.sh   # Deploy monitoring only
│   └── cleanup.sh             # Delete all stacks
├── parameters/                # Environment-specific parameters
│   ├── dev.json              # Development environment
│   ├── staging.json          # Staging environment
│   └── prod.json             # Production environment
├── DEPLOYMENT_GUIDE.md        # Complete deployment guide
├── ARCHITECTURE.md            # Multi-stack architecture details
└── README.md                  # Infrastructure overview
```

## File Naming Conventions
- Use kebab-case for directories: `user-profile/`
- Use camelCase for JavaScript files: `userService.js`
- Use lowercase for Lambda handlers: `create.js`, `update.js`
- Use PascalCase for classes: `UserModel.js`
- Use lowercase for config files: `template.yaml`, `package.json`

## Lambda Function Organization
- **One function per CRUD operation**: create, get, update, delete
- **Language optimization**: Go for performance-critical operations, Node.js for balanced development
- **Self-contained functions**: Each function includes its own dependencies and tests
- **Consistent structure**: Handler, tests, dependencies, documentation per function
- **Shared patterns**: Common logging and error handling across languages

## Multi-Stack Architecture Principles
- **Foundation Stack**: Core resources (DynamoDB, IAM) that change rarely
- **API & Functions Stack**: Application logic that changes frequently  
- **Monitoring Stack**: Observability resources that change occasionally
- **Cross-stack references**: Use CloudFormation exports/imports for resource sharing
- **Independent deployments**: Each stack can be deployed separately when needed

## API Design Guidelines
- **RESTful endpoints**: `/items` for collection, `/items/{id}` for individual resources
- **HTTP methods**: POST (create), GET (read), PUT (update), DELETE (delete)
- **Status codes**: 200/201 (success), 400 (validation), 404 (not found), 500 (server error)
- **CORS enabled**: Support for web client access
- **Request validation**: JSON schema validation at API Gateway level
- **Error responses**: Consistent error format with request IDs for tracing

## DynamoDB Design Principles
- **Single table design**: One table for all item operations
- **Partition key**: Item ID (UUID) for even distribution
- **Global Secondary Index**: Category + createdAt for category-based queries
- **Attribute naming**: Consistent camelCase naming convention
- **Timestamps**: ISO 8601 format for createdAt and updatedAt