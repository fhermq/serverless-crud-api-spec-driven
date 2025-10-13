# Testing Guide - Serverless CRUD API

This guide covers all testing aspects of the serverless CRUD API, including unit tests, integration tests, security tests, and performance tests.

## Table of Contents

- [Overview](#overview)
- [Test Types](#test-types)
- [OIDC Security Testing](#oidc-security-testing)
- [Running Tests](#running-tests)
- [CI/CD Integration](#cicd-integration)
- [Test Scripts](#test-scripts)
- [Troubleshooting](#troubleshooting)

## Overview

The testing strategy for this serverless CRUD API includes multiple layers of testing to ensure reliability, security, and performance:

1. **Unit Tests** - Test individual function logic
2. **Integration Tests** - Test API endpoints and database operations
3. **Security Tests** - Validate OIDC authentication and compliance
4. **Performance Tests** - Ensure acceptable response times and throughput
5. **Smoke Tests** - Quick validation of deployment health

## Test Types

### 1. Unit Tests

#### Go Functions (create-item, delete-item)
```bash
cd functions/create-item
go test -v -race -coverprofile=coverage.out ./...
go tool cover -html=coverage.out -o coverage.html
```

#### Node.js Functions (get-item, update-item)
```bash
cd functions/get-item
npm test
npm run test:coverage
```

**Coverage Requirements:**
- Minimum 80% code coverage for all functions
- All critical paths must be tested
- Error scenarios must be covered

### 2. Integration Tests

Integration tests validate the complete API workflow including:
- CRUD operations through API Gateway
- Database interactions
- Error handling
- CORS configuration

#### Manual Integration Testing
```bash
# Run comprehensive integration tests
cd infrastructure
./scripts/verify-deployment.sh --stage dev --verbose

# Run smoke tests for quick validation
./scripts/smoke-tests.sh --stage dev --verbose
```

#### Automated Integration Testing
Integration tests run automatically via GitHub Actions after successful deployments.

### 3. Security Tests

Security testing focuses on OIDC authentication and compliance:

#### OIDC Authentication Validation
- Verify temporary credentials are used
- Confirm credential expiry within 1 hour
- Validate IAM role assumptions
- Check for least privilege permissions

#### Security Compliance Checks
- No hardcoded secrets in code
- Proper CORS configuration
- Input validation testing
- Dependency vulnerability scanning

### 4. Performance Tests

Performance tests ensure the API meets response time requirements:

#### Load Testing
```bash
# Basic performance test
API_URL="https://your-api-url.com"
for i in {1..10}; do
  curl -w "Response time: %{time_total}s\n" -o /dev/null -s "$API_URL/items/test-id"
done
```

#### Concurrent Request Testing
The automated performance tests run concurrent requests to validate:
- Average response time < 5 seconds
- Successful handling of concurrent requests
- No timeout errors under normal load

### 5. Smoke Tests

Quick validation tests that run after deployment:
- CloudFormation stack health
- API Gateway accessibility
- DynamoDB table status
- Lambda function availability
- Basic API functionality

## OIDC Security Testing

### Authentication Verification

The OIDC security testing validates:

1. **Temporary Credentials**: Ensures no long-lived AWS credentials are used
2. **Role Assumption**: Verifies proper IAM role assumption via OIDC
3. **Credential Expiry**: Confirms credentials expire within 1 hour
4. **Permission Boundaries**: Validates least privilege access

### Security Test Commands

```bash
# Verify OIDC authentication
aws sts get-caller-identity

# Check credential expiry
aws sts get-session-token --duration-seconds 900

# Test permission boundaries
aws iam list-users  # Should fail with access denied
```

### Expected OIDC Patterns

**Valid OIDC ARN Pattern:**
```
arn:aws:sts::123456789012:assumed-role/GitHubActions-ServerlessCRUD-DeployRole/GitHubActions-Deploy-Dev-123456789
```

**Invalid Patterns:**
- `arn:aws:iam::123456789012:user/username` (IAM user)
- Long-lived credentials with no expiry

## Running Tests

### Local Development Testing

#### Prerequisites
```bash
# Install required tools
npm install -g aws-cli sam-cli
go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest
```

#### Unit Tests
```bash
# Test all Go functions
find functions -name "go.mod" -execdir go test -v ./... \;

# Test all Node.js functions
find functions -name "package.json" -execdir npm test \;
```

#### Integration Tests (Local)
```bash
# Start local API
sam local start-api --port 3001

# Run integration tests against local API
API_URL="http://localhost:3001" node integration-test.js
```

### Deployment Testing

#### After Deployment
```bash
# Run smoke tests
cd infrastructure
./scripts/smoke-tests.sh --stage dev

# Run full verification
./scripts/verify-deployment.sh --stage dev --verbose

# Run performance tests
./scripts/performance-test.sh --stage dev
```

### Environment-Specific Testing

#### Development Environment
```bash
./scripts/smoke-tests.sh --stage dev
```

#### Staging Environment
```bash
./scripts/verify-deployment.sh --stage staging --timeout 600
```

#### Production Environment
```bash
# Production uses read-only smoke tests only
./scripts/smoke-tests.sh --stage prod --timeout 120
```

## CI/CD Integration

### GitHub Actions Workflows

#### 1. Security Build Checks (`security-build-check.yml`)
- Runs on every push and PR
- Performs security scanning
- Validates dependencies
- Checks for hardcoded secrets

#### 2. Secure Deploy with OIDC (`secure-deploy-oidc.yml`)
- Deploys using OIDC authentication
- Runs build and security checks
- Performs deployment verification
- Includes rollback on failure

#### 3. Secure Integration Tests (`secure-integration-tests.yml`)
- Runs after successful deployment
- Comprehensive API testing
- Database integration testing
- Performance validation
- Security compliance checks

### Workflow Triggers

```yaml
# Automatic triggers
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 2 * * *'  # Daily security scans

# Manual triggers
workflow_dispatch:
  inputs:
    environment:
      type: choice
      options: [dev, staging, prod]
```

### Test Results

Test results are available in:
- GitHub Actions job logs
- Step summaries in GitHub UI
- Uploaded artifacts (coverage reports, security scans)
- CloudWatch logs for deployed functions

## Test Scripts

### Available Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `smoke-tests.sh` | Quick deployment validation | `./smoke-tests.sh --stage dev` |
| `verify-deployment.sh` | Comprehensive deployment check | `./verify-deployment.sh --stage dev --verbose` |
| `rollback-deployment.sh` | Rollback failed deployments | `./rollback-deployment.sh --stage dev` |
| `deploy-with-oidc-verification.sh` | Enhanced deployment with OIDC | `./deploy-with-oidc-verification.sh --stage dev` |

### Script Options

#### Common Options
- `--stage STAGE`: Environment (dev, staging, prod)
- `--region REGION`: AWS region (default: us-east-1)
- `--verbose`: Enable detailed output
- `--timeout SECONDS`: Set operation timeout

#### Security Options
- `--skip-oidc-verify`: Skip OIDC authentication checks
- `--no-rollback`: Disable automatic rollback on failure

### Custom Test Scripts

#### Create Custom Integration Test
```bash
#!/bin/bash
API_URL="$1"

# Test specific functionality
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"name":"Custom Test","category":"test","price":1.00}' \
  "$API_URL/items"
```

#### Create Performance Test
```bash
#!/bin/bash
API_URL="$1"
REQUESTS=100

for i in $(seq 1 $REQUESTS); do
  curl -w "%{time_total}\n" -o /dev/null -s "$API_URL/items/test-$i" &
done
wait
```

## Troubleshooting

### Common Issues

#### 1. OIDC Authentication Failures
```bash
# Check caller identity
aws sts get-caller-identity

# Verify role assumption
echo $AWS_ROLE_ARN
echo $AWS_WEB_IDENTITY_TOKEN_FILE
```

**Solutions:**
- Verify GitHub repository settings
- Check OIDC provider configuration
- Validate IAM role trust policy

#### 2. Test Timeouts
```bash
# Increase timeout for slow environments
./smoke-tests.sh --stage prod --timeout 300
```

#### 3. Permission Errors
```bash
# Check current permissions
aws sts get-caller-identity
aws iam simulate-principal-policy --policy-source-arn $(aws sts get-caller-identity --query Arn --output text) --action-names cloudformation:DescribeStacks
```

#### 4. API Gateway Issues
```bash
# Check API Gateway logs
aws logs tail /aws/apigateway/serverless-crud-api-dev --follow

# Test API directly
curl -v https://your-api-id.execute-api.us-east-1.amazonaws.com/Prod/items/test
```

#### 5. Lambda Function Issues
```bash
# Check function logs
aws logs tail /aws/lambda/serverless-crud-api-dev-create-item --follow

# Test function directly
aws lambda invoke --function-name serverless-crud-api-dev-create-item --payload '{}' output.json
```

### Debug Commands

#### Environment Debugging
```bash
# List all stacks
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE

# Get stack outputs
aws cloudformation describe-stacks --stack-name serverless-crud-api-dev-api --query 'Stacks[0].Outputs'

# Check DynamoDB table
aws dynamodb describe-table --table-name serverless-crud-api-dev-items
```

#### Security Debugging
```bash
# Check OIDC configuration
aws iam list-open-id-connect-providers

# Verify role trust policy
aws iam get-role --role-name GitHubActions-ServerlessCRUD-DeployRole --query 'Role.AssumeRolePolicyDocument'
```

### Getting Help

1. **Check GitHub Actions logs** for detailed error messages
2. **Review CloudWatch logs** for runtime issues
3. **Use verbose flags** on scripts for detailed output
4. **Check AWS CloudTrail** for API call history
5. **Validate OIDC setup** if authentication fails

### Test Data Cleanup

#### Manual Cleanup
```bash
# Remove test items from DynamoDB
aws dynamodb scan --table-name serverless-crud-api-dev-items --filter-expression "contains(#name, :test)" --expression-attribute-names '{"#name":"name"}' --expression-attribute-values '{":test":{"S":"test"}}' --query 'Items[].id.S' --output text | xargs -I {} aws dynamodb delete-item --table-name serverless-crud-api-dev-items --key '{"id":{"S":"{}"}}'
```

#### Automated Cleanup
Test scripts automatically clean up test data, but manual cleanup may be needed if tests are interrupted.

---

This testing guide ensures comprehensive validation of the serverless CRUD API with a focus on security, performance, and reliability. All tests are designed to work with OIDC authentication and follow security best practices.