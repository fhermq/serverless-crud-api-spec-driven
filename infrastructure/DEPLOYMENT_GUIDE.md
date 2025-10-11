# 🚀 Deployment Guide

Complete guide for deploying and managing the Serverless CRUD API infrastructure.

## 📋 Script Overview

Our 3-stack architecture uses **5 deployment scripts**:

```
deploy-all.sh (orchestrator)
├── deploy-foundation.sh
├── deploy-api-and-functions.sh
└── deploy-monitoring.sh

cleanup.sh (destroyer)
```

---

## 🆕 First Time Deployment (Fresh Environment)

### Quick Start
```bash
cd infrastructure
./scripts/deploy-all.sh --stage dev --region us-east-1
```

### What Happens Step by Step

#### **Step 1: Foundation Stack** (~3 minutes)
```bash
./scripts/deploy-foundation.sh --stage dev
```
**Creates:**
- DynamoDB table: `serverless-crud-api-dev-items`
- IAM role: `serverless-crud-api-dev-base-lambda-role`
- DynamoDB permissions policy
- Cross-stack exports for sharing resources

#### **Step 2: API & Functions Stack** (~4-6 minutes)
```bash
./scripts/deploy-api-and-functions.sh --stage dev
```
**Creates:**
- Builds Go functions (create-item, delete-item)
- Installs Node.js dependencies (get-item, update-item)
- API Gateway with CORS configuration
- 4 Lambda functions with API integration
- CloudWatch log groups

#### **Step 3: Monitoring Stack** (~2-3 minutes)
```bash
./scripts/deploy-monitoring.sh --stage dev
```
**Creates:**
- CloudWatch dashboard with API and Lambda metrics
- Error rate and throttling alarms
- Log groups with 14-day retention
- SNS topic for alerts

### **Total Time**: 8-12 minutes

### **Expected Output:**
```
🎉 Deployment Complete!
==================================
Project: serverless-crud-api
Stage: dev
Region: us-east-1

📡 API Endpoint: https://abc123.execute-api.us-east-1.amazonaws.com/dev

📋 Stack Names:
  Foundation: serverless-crud-api-dev-foundation
  API and Functions: serverless-crud-api-dev-api
  Monitoring: serverless-crud-api-dev-monitoring
```

---

## 🔄 Day-to-Day Development (Making Changes)

### **Scenario A: Lambda Function Changes** (Most Common)
**When**: Updating business logic, fixing bugs, adding features

```bash
./scripts/deploy-api-and-functions.sh --stage dev
```
**Time**: ~3-4 minutes  
**Rebuilds**: Go functions, Node.js dependencies, Lambda functions

### **Scenario B: Database Schema Changes** (Rare)
**When**: Adding DynamoDB indexes, changing table structure, updating IAM permissions

```bash
./scripts/deploy-foundation.sh --stage dev
./scripts/deploy-api-and-functions.sh --stage dev
```
**Time**: ~6-8 minutes  
**Note**: API & Functions must be redeployed to pick up foundation changes

### **Scenario C: Monitoring Changes** (Occasional)
**When**: Adding new alarms, updating dashboards, changing log retention

```bash
./scripts/deploy-monitoring.sh --stage dev
```
**Time**: ~2-3 minutes  
**Safe**: Won't affect running services

### **Scenario D: Full Redeploy** (After major changes)
**When**: Multiple stack changes, environment refresh, troubleshooting

```bash
./scripts/deploy-all.sh --stage dev
```
**Time**: ~8-12 minutes  
**Use**: When unsure which stacks need updates

---

## 🌍 Multi-Environment Deployment

### **Development Environment**
```bash
./scripts/deploy-all.sh --stage dev --region us-east-1
```

### **Staging Environment**
```bash
./scripts/deploy-all.sh --stage staging --region us-east-1
```

### **Production Environment**
```bash
./scripts/deploy-all.sh --stage prod --region us-west-2
```

### **Development Without Monitoring** (Faster)
```bash
./scripts/deploy-all.sh --stage dev --skip-monitoring
```

---

## 🗑️ Deleting Stacks

### **Complete Cleanup** (Recommended)
```bash
./scripts/cleanup.sh --stage dev --region us-east-1
```

**Interactive Process:**
1. Shows which stacks will be deleted
2. Asks for confirmation
3. Deletes in reverse dependency order:
   - Monitoring → API & Functions → Foundation
4. Waits for each deletion to complete

### **Force Cleanup** (No Confirmation)
```bash
./scripts/cleanup.sh --stage dev --force
```

### **Manual Stack Deletion** (Advanced)
```bash
# Delete in this exact order (respects dependencies)
aws cloudformation delete-stack --stack-name serverless-crud-api-dev-monitoring
aws cloudformation delete-stack --stack-name serverless-crud-api-dev-api
aws cloudformation delete-stack --stack-name serverless-crud-api-dev-foundation
```

---

## ⚙️ Script Parameters & Options

### **Common Parameters**
| Parameter | Description | Example |
|-----------|-------------|---------|
| `-s, --stage` | Deployment environment | `dev`, `staging`, `prod` |
| `-r, --region` | AWS region | `us-east-1`, `us-west-2` |
| `-p, --project-name` | Project identifier | `serverless-crud-api` |
| `-h, --help` | Show help message | |

### **Special Options**
| Script | Option | Description |
|--------|--------|-------------|
| `deploy-all.sh` | `--skip-monitoring` | Deploy without monitoring stack |
| `cleanup.sh` | `-f, --force` | Skip confirmation prompt |

### **Examples**
```bash
# Custom project name
./scripts/deploy-all.sh --stage dev --project-name my-api

# Different region for production
./scripts/deploy-all.sh --stage prod --region eu-west-1

# Quick development setup
./scripts/deploy-all.sh --stage dev --skip-monitoring

# Silent cleanup
./scripts/cleanup.sh --stage dev --force
```

---

## 🔗 Stack Dependencies & Cross-References

### **Dependency Chain**
```
Foundation Stack (Independent)
       ↓ (exports: table name, IAM role)
API & Functions Stack (Depends on Foundation)
       ↓ (exports: function names, API ID)
Monitoring Stack (Depends on API & Functions)
```

### **Cross-Stack Exports/Imports**
```yaml
# Foundation Stack Exports:
ItemsTableName: serverless-crud-api-dev-items
BaseLambdaExecutionRoleArn: arn:aws:iam::123456789:role/...
ProjectName: serverless-crud-api
Stage: dev

# API & Functions Stack Imports:
DYNAMODB_TABLE_NAME: 
  Fn::ImportValue: foundation-stack-ItemsTableName
Role: 
  Fn::ImportValue: foundation-stack-BaseLambdaExecutionRoleArn

# API & Functions Stack Exports:
CreateItemFunctionName: serverless-crud-api-dev-create-item
ApiUrl: https://abc123.execute-api.us-east-1.amazonaws.com/dev

# Monitoring Stack Imports:
FunctionName: 
  Fn::ImportValue: api-stack-CreateItemFunctionName
```

---

## 🚨 Troubleshooting & Error Recovery

### **Common Errors & Solutions**

#### **1. Stack Not Found**
```
❌ Foundation stack 'serverless-crud-api-dev-foundation' not found
```
**Solution**: Deploy foundation stack first
```bash
./scripts/deploy-foundation.sh --stage dev
```

#### **2. Cross-Stack Reference Missing**
```
❌ Export foundation-stack-ItemsTableName not found
```
**Solution**: Check foundation stack exists and has completed deployment
```bash
aws cloudformation describe-stacks --stack-name serverless-crud-api-dev-foundation
```

#### **3. Go Build Failure**
```
❌ go build failed in functions/create-item
```
**Solutions**:
```bash
# Check Go installation
go version

# Clean and rebuild
cd functions/create-item
go mod tidy
go clean
GOOS=linux GOARCH=amd64 go build -o bootstrap main.go logger.go
```

#### **4. Node.js Dependencies Issue**
```
❌ npm install failed in functions/get-item
```
**Solutions**:
```bash
# Clean and reinstall
cd functions/get-item
rm -rf node_modules package-lock.json
npm install
```

#### **5. AWS Credentials Not Configured**
```
❌ AWS CLI is not configured or credentials are invalid
```
**Solutions**:
```bash
# Configure AWS CLI
aws configure

# Or use environment variables
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
export AWS_DEFAULT_REGION=us-east-1

# Or use AWS profiles
aws configure --profile myprofile
export AWS_PROFILE=myprofile
```

### **Recovery Procedures**

#### **Complete Recovery** (Nuclear Option)
```bash
# 1. Clean up everything
./scripts/cleanup.sh --stage dev --force

# 2. Wait for completion (check AWS console)

# 3. Fresh deployment
./scripts/deploy-all.sh --stage dev
```

#### **Partial Recovery** (Targeted)
```bash
# 1. Check what exists
aws cloudformation list-stacks --region us-east-1 \
  --query 'StackSummaries[?contains(StackName, `serverless-crud-api-dev`)]'

# 2. Delete problematic stack
aws cloudformation delete-stack --stack-name problematic-stack-name

# 3. Redeploy specific stack
./scripts/deploy-foundation.sh --stage dev
```

---

## 📊 Monitoring Deployment Progress

### **Real-Time Monitoring**
```bash
# Watch CloudFormation events
aws cloudformation describe-stack-events \
  --stack-name serverless-crud-api-dev-foundation \
  --region us-east-1 \
  --query 'StackEvents[0:10].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId]' \
  --output table

# Follow CloudFormation logs
aws logs tail /aws/cloudformation/serverless-crud-api-dev-foundation --follow
```

### **Check Stack Status**
```bash
# List all stacks
aws cloudformation list-stacks --region us-east-1

# Check specific stack
aws cloudformation describe-stacks \
  --stack-name serverless-crud-api-dev-foundation \
  --query 'Stacks[0].{Status:StackStatus,Created:CreationTime}'
```

### **Get Stack Outputs**
```bash
# All outputs
aws cloudformation describe-stacks \
  --stack-name serverless-crud-api-dev-api \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
  --output table

# Specific output (API URL)
aws cloudformation describe-stacks \
  --stack-name serverless-crud-api-dev-api \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text
```

---

## 🧪 Testing Deployments

### **API Health Check**
```bash
# Get API URL
API_URL=$(aws cloudformation describe-stacks \
  --stack-name serverless-crud-api-dev-api \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text)

# Test API endpoints
curl -X GET $API_URL/items/test-id
curl -X POST $API_URL/items \
  -H 'Content-Type: application/json' \
  -d '{"name":"Test Item","category":"electronics","price":29.99}'
```

### **Function Testing**
```bash
# Invoke function directly
aws lambda invoke \
  --function-name serverless-crud-api-dev-get-item \
  --payload '{"pathParameters":{"id":"test-123"}}' \
  response.json

# Check function logs
aws logs tail /aws/lambda/serverless-crud-api-dev-get-item --follow
```

### **CloudWatch Dashboard**
```bash
# Get dashboard URL
echo "https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=serverless-crud-api-dev-api-dashboard"
```

---

## 📈 Performance & Cost Optimization

### **Deployment Time Optimization**
- **Skip monitoring** for development: `--skip-monitoring`
- **Deploy only changed stacks** instead of full deployment
- **Use parallel deployments** for independent environments

### **Cost Management**
```bash
# Check stack costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Clean up unused stacks
./scripts/cleanup.sh --stage old-feature --force
```

---

## 🔒 Security Best Practices

### **Credential Management**
- ✅ Use IAM roles instead of access keys when possible
- ✅ Use AWS profiles for different environments
- ✅ Never commit AWS credentials to git
- ✅ Use temporary credentials with MFA

### **Environment Isolation**
- ✅ Use different AWS accounts for prod/non-prod
- ✅ Use different regions for disaster recovery
- ✅ Apply least privilege IAM policies
- ✅ Enable CloudTrail for audit logging

### **Deployment Security**
```bash
# Use MFA for production deployments
aws sts get-session-token --serial-number arn:aws:iam::123456789:mfa/user --token-code 123456

# Verify deployment in non-prod first
./scripts/deploy-all.sh --stage staging
# Test thoroughly, then:
./scripts/deploy-all.sh --stage prod
```

This guide provides everything needed for safe, efficient deployments! 🚀