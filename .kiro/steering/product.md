# Product Overview

Multi-language serverless CRUD API built on AWS infrastructure for scalable, cost-effective item management operations.

## Purpose
- Provide RESTful API endpoints for item CRUD operations
- Demonstrate multi-language serverless architecture best practices
- Leverage serverless architecture for automatic scaling and cost optimization
- Enable efficient document-based data operations with DynamoDB

## Key Features
- **Multi-Language Lambda Functions**: Go for performance-critical operations, Node.js for balanced development
- **RESTful API**: Complete CRUD operations (Create, Read, Update, Delete) for items
- **Auto-Scaling**: Serverless compute with AWS Lambda functions
- **Document Storage**: DynamoDB with Global Secondary Index for category-based queries
- **Multi-Stack Architecture**: Independent deployment of foundation, API, and monitoring components
- **Comprehensive Monitoring**: CloudWatch dashboards, alarms, and X-Ray tracing
- **CORS Support**: Web client access with proper CORS configuration
- **Request Validation**: JSON schema validation at API Gateway level

## Architecture Highlights
- **3-Stack Deployment**: Foundation (DynamoDB + IAM) → API & Functions → Monitoring
- **Cross-Stack References**: CloudFormation exports/imports for resource sharing
- **Language Optimization**: Go for create/delete operations, Node.js for get/update operations
- **Independent Deployments**: Each stack can be deployed separately for faster iterations
- **Environment Isolation**: Separate stacks per environment (dev/staging/prod)

## API Endpoints
- `POST /items` - Create new item (Go Lambda)
- `GET /items/{id}` - Retrieve item by ID (Node.js Lambda)  
- `PUT /items/{id}` - Update existing item (Node.js Lambda)
- `DELETE /items/{id}` - Delete item by ID (Go Lambda)

## Target Users
- **Frontend Developers**: Building web applications that need backend APIs
- **Mobile Developers**: Creating mobile apps requiring data services
- **DevOps Engineers**: Learning multi-stack serverless deployment patterns
- **Backend Developers**: Understanding multi-language Lambda function architecture
- **Third-Party Integrators**: Consuming REST APIs for item management
- **Students/Learners**: Studying AWS serverless best practices and multi-language implementations