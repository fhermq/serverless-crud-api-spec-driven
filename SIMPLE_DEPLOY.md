# Simple Deployment Guide

Quick deployment guide for the Serverless CRUD API.

## Prerequisites

- AWS CLI configured with appropriate permissions
- AWS SAM CLI installed
- Go 1.21+ (for building Go functions)
- Node.js 20+ (for building Node.js functions)

## Deploy

```bash
# Deploy to dev (default)
./infrastructure/scripts/deploy.sh dev

# Deploy to staging
./infrastructure/scripts/deploy.sh staging

# Deploy to production (different region)
./infrastructure/scripts/deploy.sh prod us-west-2
```

This single command:
1. Creates environment-specific S3 bucket if needed
2. Deploys the foundation stack (DynamoDB + IAM)
3. Builds all Lambda functions (Go + Node.js)
4. Deploys the API stack with environment-specific throttling
5. Enables API key authentication

## Get API Credentials

```bash
# Dev environment
./infrastructure/scripts/get-api-key.sh dev

# Production environment
./infrastructure/scripts/get-api-key.sh prod us-west-2
```

Returns:
- API Gateway URL
- API Key for authentication
- Sample curl command

## Test

```bash
# Test dev environment
./infrastructure/scripts/test-api.sh dev

# Test production environment
./infrastructure/scripts/test-api.sh prod us-west-2
```

Tests all CRUD operations:
- Create item
- Read item
- Update item
- Delete item

## Clean Up

```bash
# Clean up dev environment
./infrastructure/scripts/cleanup.sh dev

# Clean up production environment
./infrastructure/scripts/cleanup.sh prod us-west-2
```

Deletes both stacks in the correct order (API first, then foundation).

## Environment Configuration

Each environment has different API limits configured in `infrastructure/parameters/`:

| Environment | Rate Limit | Burst Limit | Daily Quota |
|-------------|------------|-------------|-------------|
| **dev** | 5 req/sec | 10 requests | 500/day |
| **staging** | 25 req/sec | 50 requests | 2,500/day |
| **prod** | 100 req/sec | 200 requests | 10,000/day |

## Troubleshooting

### Common Issues

**S3 Bucket Errors**
```bash
# Clean SAM cache and retry
rm -rf infrastructure/.aws-sam/
./infrastructure/scripts/deploy.sh dev
```

**Stack Already Exists**
```bash
# Check stack status
aws cloudformation describe-stacks --stack-name serverless-crud-api-dev-foundation

# Delete if needed
./infrastructure/scripts/cleanup.sh dev
```

**Go Build Errors**
```bash
# Ensure correct Go version and build
cd functions/create-item
go version  # Should be 1.21+
GOOS=linux GOARCH=amd64 go build -o bootstrap main.go logger.go
```

**Node.js Dependency Issues**
```bash
# Clean and reinstall
cd functions/get-item
rm -rf node_modules package-lock.json
npm install
```

**API Key Not Working**
```bash
# Get fresh API key
./infrastructure/scripts/get-api-key.sh dev

# Test with curl (use the exact command from output)
curl -X GET {API_URL}/items/test-id -H "X-API-Key: {API_KEY}"
```

### Debug Commands

```bash
# View Lambda logs
aws logs tail /aws/lambda/serverless-crud-api-dev-get-item --follow

# Check stack events
aws cloudformation describe-stack-events --stack-name serverless-crud-api-dev-api

# Validate SAM template
sam validate --template infrastructure/stacks/02-api-and-functions.yaml

# Test function locally
sam local invoke GetItemFunction --event events/get-item.json
```

### Quick Fixes

**Complete Reset**
```bash
# Nuclear option - delete everything and start fresh
./infrastructure/scripts/cleanup.sh dev
rm -rf infrastructure/.aws-sam/
./infrastructure/scripts/deploy.sh dev
```

**Check Prerequisites**
```bash
# Verify tools are installed
aws --version
sam --version
go version
node --version
```