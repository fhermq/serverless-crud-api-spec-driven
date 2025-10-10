# Lambda Function Best Practices Checklist

This document defines the mandatory best practices that every Lambda function in this project must follow. Use this as a checklist during development and code reviews.

## Code Structure & Organization

### ✅ Function Structure
- [ ] Single responsibility principle - function does one thing well
- [ ] Proper separation of concerns (handler, business logic, data access)
- [ ] Consistent file naming and directory structure
- [ ] Clear function and variable naming conventions

### ✅ Dependencies & Imports
- [ ] Minimal dependencies - only import what's needed
- [ ] Shared utilities imported from `@serverless-crud-api/shared`
- [ ] AWS SDK v3 used (not v2)
- [ ] Dependencies declared in package.json/go.mod with specific versions

## Error Handling & Validation

### ✅ Input Validation
- [ ] All inputs validated using shared validation utilities
- [ ] Path parameters validated (e.g., UUID format for IDs)
- [ ] Request body validated against schema
- [ ] Proper error messages for validation failures

### ✅ Error Handling
- [ ] Try-catch blocks around all async operations
- [ ] Specific error handling for different error types
- [ ] DynamoDB-specific error handling (ResourceNotFound, ThroughputExceeded, etc.)
- [ ] Proper HTTP status codes returned
- [ ] Error responses use shared response utilities
- [ ] No sensitive information leaked in error messages

## Logging & Monitoring

### ✅ Structured Logging
- [ ] Uses shared logger utility with request context
- [ ] Request ID included in all log entries
- [ ] Function name and operation included in log context
- [ ] Appropriate log levels (DEBUG, INFO, WARN, ERROR)
- [ ] Database operations logged with timing
- [ ] No sensitive data logged (passwords, tokens, etc.)

### ✅ Performance Monitoring
- [ ] Database operation timing tracked
- [ ] Function execution metrics available
- [ ] Error rates and types tracked

## Security

### ✅ Data Protection
- [ ] Input sanitization implemented
- [ ] No hardcoded secrets or credentials
- [ ] Environment variables used for configuration
- [ ] Proper IAM permissions (least privilege)

### ✅ Response Security
- [ ] CORS headers properly configured
- [ ] No sensitive data in response headers
- [ ] Consistent response format using shared utilities

## Testing

### ✅ Unit Tests
- [ ] Comprehensive test coverage (>80%)
- [ ] Happy path scenarios tested
- [ ] Error scenarios tested
- [ ] Edge cases covered
- [ ] Mock external dependencies (DynamoDB, etc.)
- [ ] Tests run in CI/CD pipeline

### ✅ Test Quality
- [ ] Tests are independent and can run in any order
- [ ] Proper test data setup and cleanup
- [ ] Clear test descriptions and assertions
- [ ] Performance tests for critical paths

## Performance & Optimization

### ✅ Cold Start Optimization
- [ ] Minimal initialization code in handler
- [ ] Connection pooling for database clients
- [ ] Shared resources initialized outside handler
- [ ] Minimal package size and dependencies

### ✅ Runtime Efficiency
- [ ] Async/await used properly
- [ ] Database queries optimized
- [ ] Proper memory allocation configured
- [ ] Timeout values appropriately set

## Documentation

### ✅ Code Documentation
- [ ] Function purpose clearly documented
- [ ] Complex logic explained with comments
- [ ] API contract documented (inputs/outputs)
- [ ] README.md with setup and usage instructions

### ✅ API Documentation
- [ ] OpenAPI specification updated
- [ ] Request/response examples provided
- [ ] Error codes documented

## Deployment & Configuration

### ✅ Infrastructure as Code
- [ ] Function defined in SAM template
- [ ] Environment variables configured
- [ ] IAM roles and policies defined
- [ ] Resource limits set appropriately

### ✅ Environment Configuration
- [ ] Different configurations for dev/staging/prod
- [ ] No environment-specific code in function
- [ ] Proper resource tagging

## Code Quality

### ✅ Code Standards
- [ ] Linting rules followed (ESLint for Node.js, gofmt for Go)
- [ ] Code formatting consistent
- [ ] No unused imports or variables
- [ ] Proper TypeScript types (for Node.js functions)

### ✅ Code Review
- [ ] Peer review completed
- [ ] Security review for sensitive operations
- [ ] Performance review for critical paths

## Compliance Checklist by Language

### Node.js Specific
- [ ] Uses Node.js 18.x or 20.x runtime
- [ ] Package.json has proper scripts (test, lint, build)
- [ ] Uses ES6+ features appropriately
- [ ] Proper async/await error handling
- [ ] TypeScript types for shared interfaces

### Go Specific
- [ ] Uses Go 1.x runtime
- [ ] Proper error handling with Go conventions
- [ ] Context passed through function calls
- [ ] Proper struct tags for JSON marshaling
- [ ] Go modules properly configured

## Automated Checks

The following checks should be automated in CI/CD:

### Pre-commit Hooks
- [ ] Linting (ESLint/gofmt)
- [ ] Unit tests
- [ ] Security scanning
- [ ] Dependency vulnerability checks

### CI/CD Pipeline
- [ ] Build verification
- [ ] Test execution with coverage reporting
- [ ] Integration tests
- [ ] Security scans
- [ ] Performance benchmarks

### Deployment Gates
- [ ] All tests passing
- [ ] Code coverage above threshold
- [ ] Security scan clean
- [ ] Performance benchmarks within limits

## Review Process

### Development Phase
1. Developer uses this checklist during development
2. Automated checks run on every commit
3. Pull request created with checklist in description

### Code Review Phase
1. Reviewer verifies checklist items
2. Automated CI/CD checks must pass
3. Manual testing in development environment
4. Security review for sensitive functions

### Deployment Phase
1. All checklist items verified
2. Deployment pipeline runs automated tests
3. Post-deployment smoke tests
4. Monitoring alerts configured

## Enforcement

### Required Tools
- ESLint configuration for Node.js
- gofmt for Go formatting
- Jest for Node.js testing
- Go testing framework
- AWS SDK client mocks
- Security scanning tools

### Quality Gates
- Minimum 80% test coverage
- Zero high-severity security vulnerabilities
- All linting rules pass
- Performance benchmarks met
- Documentation complete

### Continuous Improvement
- Regular review of best practices
- Update checklist based on lessons learned
- Share knowledge across team
- Automate more checks over time

## Templates and Examples

Refer to the implemented `get-item` function as a reference implementation that follows all these best practices:
- `functions/get-item/index.js` - Handler implementation
- `functions/get-item/index.test.js` - Comprehensive test suite
- `functions/get-item/package.json` - Dependency management
- `functions/get-item/README.md` - Documentation

Use this as a template for implementing other Lambda functions in the project.