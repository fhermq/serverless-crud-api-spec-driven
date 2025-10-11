# 🚀 Step-by-Step Deployment Guide

Complete guide for deploying, managing, and troubleshooting the Serverless CRUD API using shell scripts.

## 📋 Prerequisites

### Required Tools
```bash
# Check AWS CLI
aws --version
# Expected: aws-cli/2.x.x or higher

# Check SAM CLI  
sam --version
# Expected: SAM CLI, version 1.x.x or higher

# Check Go
go version
# Expected: go version go1.21.x or higher

# Check Node.js
node --version
npm --version
# Expected: v18.x.x or v20.x.x
```

### AWS Configuration
```bash
# Configure AWS credentials
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-east-1), Output format (json)

# Verify configuration
aws sts get-caller-identity
# Should show your AWS account details
```

## 🏗️ Step 1: Complete Deployment

### Navigate to Project Directory
```bash
cd /path/to/your/serverless-crud-api
cd infrastructure
```

### Deploy All Stacks (Recommended)
```bash
# Deploy everything at once
./scripts/deploy-all.sh --stage dev --region us-east-1
```

**Expected Output:**
```
🚀 Deploying Complete Serverless CRUD API
Project: serverless-crud-api
Stage: dev
Region: us-east-1

📋 Deployment Plan:
1. Foundation Stack (DynamoDB, IAM roles)
2. API and Functions Stack (API Gateway + Lambda functions)  
3. Monitoring Stack (CloudWatch, alarms)

🏗️  Step 1/3: Deploying Foundation Stack...
[Foundation deployment progress...]

🌐⚡ Step 2/3: Deploying API and Functions Stack...
[API deployment progress...]

📊 Step 3/3: Deploying Monitoring Stack...
[Monitoring deployment progress...]

🎉 Deployment Complete!
==================================
📡 API Endpoint: https://abc123.execute-api.us-east-1.amazonaws.com/dev
```

### Alternative: Step-by-Step Deployment
If you prefer more control:

```bash
# Step 1: Deploy Foundation (DynamoDB + IAM)
./scripts/deploy-foundation.sh --stage dev --region us-east-1

# Step 2: Deploy API & Functions (API Gateway + Lambda)
./scripts/deploy-api-and-functions.sh --stage dev --region us-east-1

# Step 3: Deploy Monitoring (CloudWatch + Alarms)
./scripts/deploy-monitoring.sh --stage dev --region us-east-1
```

### Verify Deployment
```bash
# Check all stacks are deployed
aws cloudformation list-stacks --region us-east-1 \
  --query 'StackSummaries[?contains(StackName, `serverless-crud-api-dev`) && StackStatus != `DELETE_COMPLETE`].[StackName,StackStatus]' \
  --output table
```

**Expected Output:**
```
+-------------------------------------+------------------+
|              ListStacks             |                  |
+-------------------------------------+------------------+
|  serverless-crud-api-dev-foundation |  CREATE_COMPLETE |
|  serverless-crud-api-dev-api        |  CREATE_COMPLETE |
|  serverless-crud-api-dev-monitoring |  CREATE_COMPLETE |
+-------------------------------------+------------------+
```

## 🌐 Step 2: Get Your API Endpoint

### Get API URL
```bash
# Get the API endpoint URL
aws cloudformation describe-stacks \
  --stack-name serverless-crud-api-dev-api \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text
```

**Example Output:**
```
https://c8yf75taj1.execute-api.us-east-1.amazonaws.com/dev
```

### Save API URL for Testing
```bash
# Save API URL to environment variable
export API_URL=$(aws cloudformation describe-stacks \
  --stack-name serverless-crud-api-dev-api \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text)

echo "API URL: $API_URL"
```

## 🧪 Step 3: Test Your API (Public Access)

### Test GET Request (should return 404)
```bash
curl -X GET "$API_URL/items/test-123"
```

**Expected Response:**
```json
{
  "error": "Item not found",
  "message": "Item with id 'test-123' does not exist"
}
```

### Test POST Request (create item)
```bash
curl -X POST "$API_URL/items" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Item",
    "description": "My first API test",
    "category": "electronics",
    "price": 29.99,
    "tags": ["test", "api"]
  }'
```

**Expected Response:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Test Item",
  "description": "My first API test",
  "category": "electronics",
  "price": 29.99,
  "tags": ["test", "api"],
  "createdAt": "2024-01-15T10:30:00.000Z",
  "updatedAt": "2024-01-15T10:30:00.000Z"
}
```

### Test GET Request (retrieve created item)
```bash
# Save the item ID from the previous response
export ITEM_ID="550e8400-e29b-41d4-a716-446655440000"

curl -X GET "$API_URL/items/$ITEM_ID"
```

### Test PUT Request (update item)
```bash
curl -X PUT "$API_URL/items/$ITEM_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Test Item",
    "description": "Updated via API",
    "category": "electronics",
    "price": 39.99,
    "tags": ["test", "api", "updated"]
  }'
```

### Test DELETE Request (delete item)
```bash
curl -X DELETE "$API_URL/items/$ITEM_ID"
```

**Expected Response:** HTTP 204 No Content (empty response body)

## 🔑 Step 4: Enable API Key Authentication

### Enable API Key Authentication
```bash
cd infrastructure
./scripts/manage-api-key.sh enable-auth --stage dev
```

**Expected Output:**
```
[INFO] Enabling API key authentication for stage: dev
[INFO] Using SAM to update the stack with API key authentication...
[INFO] Building Go functions...
[INFO] Installing Node.js dependencies...
[INFO] Building API and Functions stack with SAM...
[INFO] Deploying stack update with API key authentication...
[SUCCESS] API key authentication enabled successfully

[INFO] Retrieving API key for stage: dev
[SUCCESS] API Key retrieved successfully

API Key ID: abc123def456
API Key Value: your-secret-api-key-here

[INFO] Usage instructions:
Include the API key in your requests using the X-API-Key header:
  curl -H 'X-API-Key: your-secret-api-key-here' https://your-api-url/items

[WARNING] Keep this API key secure and do not share it publicly
```

### Save API Key for Testing
```bash
# Save API key to environment variable
export API_KEY="your-secret-api-key-here"
echo "API Key: $API_KEY"
```

## 🔐 Step 5: Test Secured API

### Test WITHOUT API Key (should fail)
```bash
curl -X GET "$API_URL/items/test-123"
```

**Expected Response:**
```json
{
  "message": "Forbidden"
}
```

### Test WITH API Key (should work)
```bash
# Test GET with API key
curl -X GET "$API_URL/items/test-123" \
  -H "X-API-Key: $API_KEY"

# Test POST with API key
curl -X POST "$API_URL/items" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  -d '{
    "name": "Secured Item",
    "description": "Created with API key",
    "category": "secure",
    "price": 99.99
  }'
```

## 📊 Step 6: Monitor Your API

### Get CloudWatch Dashboard URL
```bash
aws cloudformation describe-stacks \
  --stack-name serverless-crud-api-dev-monitoring \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`DashboardUrl`].OutputValue' \
  --output text
```

### View Lambda Function Logs
```bash
# View Create Item function logs
aws logs tail /aws/lambda/serverless-crud-api-dev-create-item --follow

# View Get Item function logs  
aws logs tail /aws/lambda/serverless-crud-api-dev-get-item --follow

# View API Gateway logs
aws logs tail /aws/apigateway/serverless-crud-api-dev --follow
```

### Check API Usage Statistics
```bash
./scripts/manage-api-key.sh get-usage --stage dev
```

## 🗑️ Step 7: Cleanup (When Done)

### Complete Cleanup
```bash
# Clean up all stacks (with confirmation)
./scripts/cleanup.sh --stage dev --region us-east-1
```

**Expected Output:**
```
🗑️  Cleanup Serverless CRUD API Stacks
Project: serverless-crud-api
Stage: dev
Region: us-east-1

⚠️  This will delete the following stacks:
  - serverless-crud-api-dev-monitoring
  - serverless-crud-api-dev-api
  - serverless-crud-api-dev-foundation

Are you sure you want to delete all stacks? (y/N): y

🚀 Starting cleanup process...

🗑️  Deleting Monitoring Stack...
✅ Monitoring Stack deleted successfully

🗑️  Deleting API and Functions Stack...
✅ API and Functions Stack deleted successfully

🗑️  Deleting Foundation Stack...
✅ Foundation Stack deleted successfully

🎉 Cleanup completed successfully!
```

### Force Cleanup (No Confirmation)
```bash
# Clean up without confirmation prompt
./scripts/cleanup.sh --stage dev --region us-east-1 --force
```

### Verify Cleanup
```bash
# Check that all stacks are deleted
aws cloudformation list-stacks --region us-east-1 \
  --query 'StackSummaries[?contains(StackName, `serverless-crud-api-dev`) && StackStatus != `DELETE_COMPLETE`]'
```

**Expected Output:** `[]` (empty array)

## 🔧 API Key Management Commands

### Get Existing API Key
```bash
./scripts/manage-api-key.sh get-key --stage dev
```

### Create Additional API Key
```bash
./scripts/manage-api-key.sh create-key --stage dev --api-key-name "postman-testing-key"
```

### Disable API Key Authentication
```bash
./scripts/manage-api-key.sh disable-auth --stage dev
```

### Get API Usage Statistics
```bash
./scripts/manage-api-key.sh get-usage --stage dev
```

## 🌍 Multi-Environment Deployment

### Deploy to Different Environments
```bash
# Development
./scripts/deploy-all.sh --stage dev --region us-east-1

# Staging
./scripts/deploy-all.sh --stage staging --region us-east-1

# Production (different region)
./scripts/deploy-all.sh --stage prod --region us-west-2
```

### Environment-Specific API Keys
```bash
# Enable API key for production
./scripts/manage-api-key.sh enable-auth --stage prod --region us-west-2

# Get production API key
./scripts/manage-api-key.sh get-key --stage prod --region us-west-2
```

## 🔍 Troubleshooting Commands

### Check Stack Status
```bash
# Check specific stack status
aws cloudformation describe-stacks \
  --stack-name serverless-crud-api-dev-foundation \
  --region us-east-1 \
  --query 'Stacks[0].StackStatus'

# Check all project stacks
aws cloudformation list-stacks --region us-east-1 \
  --query 'StackSummaries[?contains(StackName, `serverless-crud-api-dev`)].[StackName,StackStatus,CreationTime]' \
  --output table
```

### View Stack Events (for errors)
```bash
# View recent stack events
aws cloudformation describe-stack-events \
  --stack-name serverless-crud-api-dev-api \
  --region us-east-1 \
  --query 'StackEvents[0:10].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId,ResourceStatusReason]' \
  --output table

# View only failed events
aws cloudformation describe-stack-events \
  --stack-name serverless-crud-api-dev-api \
  --region us-east-1 \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED` || ResourceStatus==`UPDATE_FAILED`].[Timestamp,ResourceType,LogicalResourceId,ResourceStatusReason]' \
  --output table
```

### Check Stack Outputs
```bash
# Get all stack outputs
aws cloudformation describe-stacks \
  --stack-name serverless-crud-api-dev-api \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
  --output table

# Get specific output (API URL)
aws cloudformation describe-stacks \
  --stack-name serverless-crud-api-dev-api \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text
```

### Check Cross-Stack References
```bash
# List all exports (for cross-stack references)
aws cloudformation list-exports --region us-east-1 \
  --query 'Exports[?contains(Name, `serverless-crud-api-dev`)].[Name,Value]' \
  --output table

# Check specific export exists
aws cloudformation describe-stacks \
  --stack-name serverless-crud-api-dev-foundation \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`ItemsTableName`]'
```

### Lambda Function Diagnostics
```bash
# Get function configuration
aws lambda get-function-configuration \
  --function-name serverless-crud-api-dev-create-item \
  --region us-east-1

# Test function directly
aws lambda invoke \
  --function-name serverless-crud-api-dev-get-item \
  --region us-east-1 \
  --payload '{"pathParameters":{"id":"test-123"}}' \
  response.json

cat response.json
```

### DynamoDB Diagnostics
```bash
# Check table exists
aws dynamodb describe-table \
  --table-name serverless-crud-api-dev-items \
  --region us-east-1

# List items in table (for testing)
aws dynamodb scan \
  --table-name serverless-crud-api-dev-items \
  --region us-east-1 \
  --max-items 5
```

### API Gateway Diagnostics
```bash
# Get API Gateway details
aws apigateway get-rest-api \
  --rest-api-id c8yf75taj1 \
  --region us-east-1

# Test API Gateway directly
aws apigateway test-invoke-method \
  --rest-api-id c8yf75taj1 \
  --resource-id abc123 \
  --http-method GET \
  --path-with-query-string "/items/test-123" \
  --region us-east-1
```

## 🚨 Common Issues and Solutions

### Issue 1: Stack Update Failed
```bash
# Check what failed
aws cloudformation describe-stack-events \
  --stack-name serverless-crud-api-dev-api \
  --region us-east-1 \
  --query 'StackEvents[?ResourceStatus==`UPDATE_FAILED`]'

# If stack is in UPDATE_ROLLBACK_COMPLETE, try deployment again
./scripts/deploy-api-and-functions.sh --stage dev --region us-east-1
```

### Issue 2: Lambda Function Errors
```bash
# Check function logs for errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/serverless-crud-api-dev-create-item \
  --region us-east-1 \
  --filter-pattern "ERROR"

# Check function configuration
aws lambda get-function-configuration \
  --function-name serverless-crud-api-dev-create-item \
  --region us-east-1
```

### Issue 3: API Key Not Working
```bash
# Verify API key exists
./scripts/manage-api-key.sh get-key --stage dev

# Check if API key authentication is enabled
aws cloudformation describe-stacks \
  --stack-name serverless-crud-api-dev-api \
  --region us-east-1 \
  --query 'Stacks[0].Parameters[?ParameterKey==`EnableApiKeyAuth`].ParameterValue'
```

### Issue 4: Cross-Stack Reference Errors
```bash
# Check foundation stack exports
aws cloudformation list-exports --region us-east-1 \
  --query 'Exports[?contains(Name, `foundation`)]'

# Verify foundation stack is deployed
aws cloudformation describe-stacks \
  --stack-name serverless-crud-api-dev-foundation \
  --region us-east-1 \
  --query 'Stacks[0].StackStatus'
```

### Issue 5: Go Build Failures
```bash
# Check Go version
go version

# Clean and rebuild Go functions
cd functions/create-item
go mod tidy
go clean
GOOS=linux GOARCH=amd64 go build -o bootstrap main.go logger.go

# Verify binary
file bootstrap
```

### Issue 6: Node.js Dependency Issues
```bash
# Check Node.js version
node --version
npm --version

# Clean and reinstall
cd functions/get-item
rm -rf node_modules package-lock.json
npm cache clean --force
npm install --production
```

## 📚 Useful Commands Reference

### Quick Status Check
```bash
# One-liner to check all stacks
aws cloudformation list-stacks --region us-east-1 --query 'StackSummaries[?contains(StackName, `serverless-crud-api-dev`) && StackStatus != `DELETE_COMPLETE`].[StackName,StackStatus]' --output table
```

### Quick API Test
```bash
# Set variables and test
export API_URL=$(aws cloudformation describe-stacks --stack-name serverless-crud-api-dev-api --region us-east-1 --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' --output text)
curl -X GET "$API_URL/items/test" -H "X-API-Key: $API_KEY"
```

### Quick Logs Check
```bash
# Check recent errors across all functions
aws logs filter-log-events --log-group-name /aws/lambda/serverless-crud-api-dev-create-item --region us-east-1 --start-time $(date -d '1 hour ago' +%s)000 --filter-pattern "ERROR"
```

### Environment Variables Setup
```bash
# Create a setup script for easy environment switching
cat > setup-env.sh << 'EOF'
#!/bin/bash
export STAGE="dev"
export REGION="us-east-1"
export API_URL=$(aws cloudformation describe-stacks --stack-name serverless-crud-api-${STAGE}-api --region $REGION --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' --output text)
export API_KEY=$(aws apigateway get-api-key --api-key $(aws cloudformation describe-stacks --stack-name serverless-crud-api-${STAGE}-api --region $REGION --query 'Stacks[0].Outputs[?OutputKey==`ApiKeyId`].OutputValue' --output text) --include-value --region $REGION --query 'value' --output text 2>/dev/null || echo "")
echo "Environment: $STAGE"
echo "API URL: $API_URL"
echo "API Key: $API_KEY"
EOF

chmod +x setup-env.sh
source setup-env.sh
```

This comprehensive guide covers everything you need to deploy, manage, and troubleshoot your serverless CRUD API using the shell scripts! 🚀