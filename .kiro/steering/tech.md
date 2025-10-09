# Technology Stack

## AWS Serverless Architecture
- **Compute**: AWS Lambda (Node.js runtime)
- **API Layer**: AWS API Gateway (REST API)
- **Database**: Amazon DynamoDB (NoSQL document store)
- **Infrastructure**: AWS CloudFormation or AWS SAM

## Build System
- **Package Manager**: npm or yarn
- **Deployment**: AWS SAM CLI or Serverless Framework
- **Bundling**: esbuild or webpack for Lambda optimization

## Tech Stack
- **Language**: Node.js (JavaScript/TypeScript)
- **Runtime**: AWS Lambda Node.js 18.x or 20.x
- **Database Client**: AWS SDK v3 DynamoDB DocumentClient
- **API Framework**: Native Lambda handlers or Express.js with serverless-http

## Common Commands

### Development
```bash
# Install dependencies
npm install

# Start local development (SAM)
sam local start-api

# Start local development (Serverless Framework)
serverless offline
```

### Building & Deployment
```bash
# Build Lambda functions
npm run build

# Deploy to AWS (SAM)
sam build && sam deploy

# Deploy to AWS (Serverless Framework)
serverless deploy
```

### Testing
```bash
# Run unit tests
npm test

# Run integration tests
npm run test:integration

# Test Lambda locally
sam local invoke FunctionName
```

### AWS Operations
```bash
# View CloudFormation stack
aws cloudformation describe-stacks --stack-name your-stack-name

# View Lambda logs
aws logs tail /aws/lambda/your-function-name --follow
```

## Development Guidelines
- Use async/await for Lambda handlers
- Implement proper error handling with HTTP status codes
- Follow DynamoDB single-table design patterns
- Use environment variables for configuration
- Implement request validation and sanitization
- Add comprehensive logging for debugging
- Optimize Lambda cold starts with minimal dependencies