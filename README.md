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
├── src/                       # Source code (to be created)
├── infrastructure/            # IaC templates (to be created)
└── .github/workflows/         # GitHub Actions (to be created)
```

## Getting Started

This project is currently in the specification phase. See the `.kiro/specs/serverless-crud-api/` directory for detailed requirements and design documentation.

## Development

Built with Kiro AI assistant for enhanced development productivity.