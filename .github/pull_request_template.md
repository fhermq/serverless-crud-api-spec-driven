# Pull Request: Lambda Function Implementation

## Description
Brief description of the changes and which Lambda function(s) are affected.

## Type of Change
- [ ] New Lambda function implementation
- [ ] Bug fix in existing function
- [ ] Performance improvement
- [ ] Documentation update
- [ ] Infrastructure/configuration change

## Lambda Function Best Practices Checklist

### Code Structure & Organization
- [ ] Function follows single responsibility principle
- [ ] Proper separation of concerns (handler, business logic, data access)
- [ ] Consistent file naming and directory structure
- [ ] Uses shared utilities from `@serverless-crud-api/shared`

### Error Handling & Validation
- [ ] All inputs validated using shared validation utilities
- [ ] Path parameters validated (UUID format for IDs)
- [ ] Request body validated against schema
- [ ] Comprehensive error handling with try-catch blocks
- [ ] DynamoDB-specific error handling implemented
- [ ] Proper HTTP status codes returned
- [ ] Error responses use shared response utilities

### Logging & Monitoring
- [ ] Uses shared logger utility with request context
- [ ] Request ID included in all log entries
- [ ] Appropriate log levels used (DEBUG, INFO, WARN, ERROR)
- [ ] Database operations logged with timing
- [ ] No sensitive data logged

### Security
- [ ] Input sanitization implemented
- [ ] No hardcoded secrets or credentials
- [ ] Environment variables used for configuration
- [ ] CORS headers properly configured
- [ ] Proper IAM permissions configured

### Testing
- [ ] Comprehensive unit tests written (>80% coverage)
- [ ] Happy path scenarios tested
- [ ] Error scenarios tested
- [ ] Edge cases covered
- [ ] Mock external dependencies properly
- [ ] All tests pass locally

### Performance & Optimization
- [ ] Minimal initialization code in handler
- [ ] Connection pooling for database clients
- [ ] Async/await used properly
- [ ] Database queries optimized

### Documentation
- [ ] Function purpose clearly documented
- [ ] README.md updated with setup instructions
- [ ] API documentation updated (if applicable)
- [ ] Code comments for complex logic

### Code Quality
- [ ] Linting rules followed (ESLint/gofmt)
- [ ] Code formatting consistent
- [ ] No unused imports or variables
- [ ] TypeScript types used (for Node.js functions)

## Testing Checklist
- [ ] Unit tests pass locally
- [ ] Integration tests pass (if applicable)
- [ ] Manual testing completed
- [ ] Performance testing completed (if applicable)

## Deployment Checklist
- [ ] SAM template updated (if needed)
- [ ] Environment variables configured
- [ ] IAM roles and policies updated
- [ ] Resource limits set appropriately

## Review Notes
Please provide any additional context for reviewers:

## Breaking Changes
- [ ] This PR introduces breaking changes
- [ ] API contract changes documented
- [ ] Migration guide provided (if needed)

## Related Issues
Closes #[issue number]

---

**Reviewer Instructions:**
1. Verify all checklist items are completed
2. Run automated tests locally
3. Review code against best practices document
4. Test the function manually if possible
5. Ensure documentation is complete and accurate