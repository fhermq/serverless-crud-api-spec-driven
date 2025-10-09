# Project Structure

## Current Organization
```
.
├── .kiro/                 # Kiro AI assistant configuration
│   └── steering/          # AI guidance documents
│       ├── product.md     # Product overview and purpose
│       ├── tech.md        # Technology stack and commands
│       └── structure.md   # Project organization (this file)
```

## Serverless REST API Structure
```
.
├── src/
│   ├── handlers/          # Lambda function handlers
│   │   ├── users/         # User-related endpoints
│   │   │   ├── create.js  # POST /users
│   │   │   ├── get.js     # GET /users/{id}
│   │   │   ├── list.js    # GET /users
│   │   │   ├── update.js  # PUT /users/{id}
│   │   │   └── delete.js  # DELETE /users/{id}
│   │   └── health/        # Health check endpoints
│   │       └── check.js   # GET /health
│   ├── services/          # Business logic layer
│   │   ├── userService.js # User operations
│   │   └── dbService.js   # DynamoDB operations
│   ├── models/            # Data models and schemas
│   │   ├── user.js        # User model definition
│   │   └── validation.js  # Input validation schemas
│   ├── middleware/        # Lambda middleware
│   │   ├── auth.js        # Authentication middleware
│   │   ├── cors.js        # CORS handling
│   │   └── errorHandler.js # Error handling
│   └── utils/             # Utility functions
│       ├── response.js    # HTTP response helpers
│       ├── logger.js      # Logging utilities
│       └── constants.js   # Application constants
├── tests/                 # Test files
│   ├── unit/              # Unit tests
│   ├── integration/       # Integration tests
│   └── fixtures/          # Test data
├── infrastructure/        # IaC templates
│   ├── template.yaml      # SAM template
│   └── serverless.yml     # Serverless Framework config
├── docs/                  # API documentation
│   └── api-spec.yaml      # OpenAPI specification
└── scripts/               # Deployment and utility scripts
    ├── deploy.sh          # Deployment script
    └── seed-data.js       # Database seeding
```

## File Naming Conventions
- Use kebab-case for directories: `user-profile/`
- Use camelCase for JavaScript files: `userService.js`
- Use lowercase for Lambda handlers: `create.js`, `update.js`
- Use PascalCase for classes: `UserModel.js`
- Use lowercase for config files: `template.yaml`, `package.json`

## Lambda Handler Organization
- One handler per HTTP method per resource
- Group related handlers in resource folders
- Keep handlers thin - delegate to services
- Use consistent naming: `{action}.js` (create, get, list, update, delete)

## DynamoDB Design Principles
- Single table design when possible
- Use composite keys (PK/SK) for relationships
- Implement GSIs for query patterns
- Follow access patterns over normalization
- Use consistent naming for keys and attributes

## API Design Guidelines
- Follow REST conventions for endpoints
- Use proper HTTP status codes
- Implement consistent error response format
- Add request/response validation
- Include API versioning strategy
- Document all endpoints with OpenAPI spec