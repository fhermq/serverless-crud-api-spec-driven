# 🚨 Orphaned Resources Management Guide

**Critical for Serverless Cost Control and Team Collaboration**

## 🎯 Why This Matters

In a **serverless mindset**, we expect:
- ✅ **Zero cost when not in use**
- ✅ **Clean resource lifecycle management**
- ✅ **No surprise bills from forgotten resources**
- ✅ **Team members can safely experiment without leaving expensive resources**

**Orphaned resources violate these principles and can lead to unexpected costs!**

## 🔍 What Are Orphaned Resources?

**Orphaned resources** are AWS resources that:
- Were created by CloudFormation/SAM but are **no longer managed** by any stack
- Remain active and **continue to incur costs** even after stack deletion
- Are **invisible to normal cleanup processes**
- Can accumulate over time, especially during development and troubleshooting

### Common Causes in Our Project:
1. **CloudFormation rollbacks** during failed deployments
2. **Stack update failures** that leave resources behind
3. **Manual resource modifications** outside of CloudFormation
4. **Incomplete cleanup** during troubleshooting
5. **Team members experimenting** with different configurations

## 💰 Cost Impact Examples

### Potential Orphaned Resources and Their Costs:
| Resource Type | Typical Cost | Risk Level |
|---------------|--------------|------------|
| **API Gateway** | $3.50/million requests + $0.09/GB data transfer | 🟡 Medium |
| **Lambda Functions** | $0.20/1M requests + $0.0000166667/GB-second | 🟢 Low |
| **DynamoDB Tables** | $0.25/GB storage + $1.25/million RCU/WCU | 🔴 High |
| **CloudWatch Log Groups** | $0.50/GB ingested + $0.03/GB stored | 🟡 Medium |
| **S3 Buckets** | $0.023/GB storage + requests costs | 🟡 Medium |
| **SAM CLI Managed S3 Bucket** | $0.023/GB storage (often 100-500MB) | 🟡 Medium |
| **IAM Roles/Policies** | Free (but security risk) | 🟢 Low |

### Real-World Scenario:
- **Orphaned DynamoDB table** with provisioned capacity: **$50-200/month**
- **Orphaned API Gateway** with high traffic: **$10-50/month**
- **SAM CLI managed S3 bucket** with deployment artifacts: **$2-10/month**
- **Multiple orphaned resources** across team: **$100-500/month**

### SAM CLI Managed Bucket - Hidden Cost:
The `aws-sam-cli-managed-default-*` bucket is **automatically created** by SAM CLI and often **forgotten after cleanup**. It contains:
- Lambda deployment packages (ZIP files, often 5-15MB each)
- CloudFormation templates
- Multiple versions due to S3 versioning
- **Typical size:** 100-500MB after multiple deployments
- **Cost impact:** $2-10/month that continues even after stack deletion

## 🔍 How to Detect Orphaned Resources

### 1. Regular Audit Commands

#### Check API Gateway APIs
```bash
# List all APIs and their creation dates
aws apigateway get-rest-apis --region us-east-1 \
  --query 'items[*].[id,name,createdDate]' \
  --output table

# Check if API is managed by CloudFormation
aws apigateway get-rest-api --rest-api-id YOUR_API_ID --region us-east-1 \
  --query 'tags'
```

#### Check Lambda Functions
```bash
# List all Lambda functions
aws lambda list-functions --region us-east-1 \
  --query 'Functions[*].[FunctionName,LastModified,Runtime]' \
  --output table

# Check if function is managed by CloudFormation
aws lambda list-tags --resource YOUR_FUNCTION_ARN --region us-east-1
```

#### Check DynamoDB Tables
```bash
# List all DynamoDB tables
aws dynamodb list-tables --region us-east-1

# Check table details and tags
aws dynamodb describe-table --table-name YOUR_TABLE_NAME --region us-east-1 \
  --query 'Table.{Name:TableName,Status:TableStatus,Created:CreationDateTime,Billing:BillingModeSummary}'
```

#### Check CloudWatch Log Groups
```bash
# List log groups with retention and size
aws logs describe-log-groups --region us-east-1 \
  --query 'logGroups[*].[logGroupName,retentionInDays,storedBytes]' \
  --output table
```

#### Check S3 Buckets (Including SAM CLI Managed)
```bash
# List all S3 buckets
aws s3 ls

# Check for SAM CLI managed buckets (common orphaned resource)
aws s3 ls | grep "aws-sam-cli-managed"

# Check bucket size and contents
aws s3 ls s3://your-bucket-name --recursive --human-readable --summarize

# Check SAM CLI managed bucket contents and size
aws s3 ls s3://aws-sam-cli-managed-default-* --recursive --human-readable --summarize

# Check if bucket has versioning (increases storage costs)
aws s3api get-bucket-versioning --bucket aws-sam-cli-managed-default-XXXXXX

# Check bucket tags to see if it's managed by CloudFormation
aws s3api get-bucket-tagging --bucket YOUR_BUCKET_NAME --region us-east-1
```

### 2. Automated Detection Script

Create `scripts/detect-orphaned-resources.sh`:

```bash
#!/bin/bash

# Detect Orphaned Resources Script
set -e

REGION="us-east-1"
PROJECT_PREFIX="serverless-crud-api"

echo "🔍 Scanning for orphaned resources..."
echo "Project: $PROJECT_PREFIX"
echo "Region: $REGION"
echo ""

# Check API Gateway
echo "📡 Checking API Gateway..."
APIS=$(aws apigateway get-rest-apis --region $REGION \
  --query "items[?contains(name, '$PROJECT_PREFIX') || contains(description, '$PROJECT_PREFIX')].[id,name,createdDate]" \
  --output text)

if [[ -n "$APIS" ]]; then
  echo "⚠️  Found potential orphaned APIs:"
  echo "$APIS"
else
  echo "✅ No orphaned APIs found"
fi
echo ""

# Check Lambda Functions
echo "⚡ Checking Lambda Functions..."
FUNCTIONS=$(aws lambda list-functions --region $REGION \
  --query "Functions[?contains(FunctionName, '$PROJECT_PREFIX')].[FunctionName,LastModified]" \
  --output text)

if [[ -n "$FUNCTIONS" ]]; then
  echo "⚠️  Found potential orphaned Lambda functions:"
  echo "$FUNCTIONS"
else
  echo "✅ No orphaned Lambda functions found"
fi
echo ""

# Check DynamoDB Tables
echo "🗄️  Checking DynamoDB Tables..."
TABLES=$(aws dynamodb list-tables --region $REGION \
  --query "TableNames[?contains(@, '$PROJECT_PREFIX')]" \
  --output text)

if [[ -n "$TABLES" ]]; then
  echo "⚠️  Found potential orphaned DynamoDB tables:"
  echo "$TABLES"
else
  echo "✅ No orphaned DynamoDB tables found"
fi
echo ""

# Check CloudWatch Log Groups
echo "📊 Checking CloudWatch Log Groups..."
LOG_GROUPS=$(aws logs describe-log-groups --region $REGION \
  --query "logGroups[?contains(logGroupName, '$PROJECT_PREFIX')].[logGroupName,storedBytes]" \
  --output text)

if [[ -n "$LOG_GROUPS" ]]; then
  echo "⚠️  Found potential orphaned Log Groups:"
  echo "$LOG_GROUPS"
else
  echo "✅ No orphaned Log Groups found"
fi
echo ""

echo "🎯 Scan complete!"
echo ""
echo "💡 Next steps:"
echo "1. Verify which resources are actually orphaned"
echo "2. Use cleanup commands to remove confirmed orphaned resources"
echo "3. Update team processes to prevent future orphaned resources"
```

## 🧹 How to Clean Up Orphaned Resources

### 1. Safe Cleanup Process

#### Step 1: Verify Resource is Orphaned
```bash
# Check if resource has CloudFormation tags
aws apigateway get-rest-api --rest-api-id YOUR_API_ID --region us-east-1 \
  --query 'tags."aws:cloudformation:stack-name"'

# If returns null or empty, it's likely orphaned
```

#### Step 2: Document Before Deletion
```bash
# Save resource details before deletion
aws apigateway get-rest-api --rest-api-id YOUR_API_ID --region us-east-1 > orphaned-api-backup.json
```

#### Step 3: Delete Orphaned Resource
```bash
# Delete orphaned API Gateway
aws apigateway delete-rest-api --rest-api-id YOUR_API_ID --region us-east-1

# Delete orphaned Lambda function
aws lambda delete-function --function-name YOUR_FUNCTION_NAME --region us-east-1

# Delete orphaned DynamoDB table (CAREFUL!)
aws dynamodb delete-table --table-name YOUR_TABLE_NAME --region us-east-1

# Delete orphaned Log Group
aws logs delete-log-group --log-group-name YOUR_LOG_GROUP --region us-east-1

# Delete orphaned S3 bucket (CAREFUL!)
aws s3 rm s3://YOUR_BUCKET_NAME --recursive --region us-east-1
aws s3 rb s3://YOUR_BUCKET_NAME --region us-east-1

# Delete SAM CLI managed bucket (common after cleanup)
aws s3 rm s3://aws-sam-cli-managed-default-XXXXXX --recursive --region us-east-1
aws s3 rb s3://aws-sam-cli-managed-default-XXXXXX --region us-east-1
```

### 2. SAM CLI Managed Bucket Cleanup (Critical!)

The SAM CLI managed bucket often contains **versioned objects** that require special cleanup:

```bash
# Step 1: Get the SAM bucket name
SAM_BUCKET=$(aws s3 ls | grep "aws-sam-cli-managed-default" | awk '{print $3}')
echo "Found SAM bucket: $SAM_BUCKET"

# Step 2: Delete all current objects
aws s3 rm s3://$SAM_BUCKET --recursive --region us-east-1

# Step 3: Delete all object versions (if versioning is enabled)
aws s3api delete-objects --bucket $SAM_BUCKET --region us-east-1 \
  --delete "$(aws s3api list-object-versions --bucket $SAM_BUCKET --region us-east-1 \
  --output json --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}')"

# Step 4: Delete all delete markers
aws s3api delete-objects --bucket $SAM_BUCKET --region us-east-1 \
  --delete "$(aws s3api list-object-versions --bucket $SAM_BUCKET --region us-east-1 \
  --output json --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')"

# Step 5: Delete the empty bucket
aws s3 rb s3://$SAM_BUCKET --region us-east-1

echo "✅ SAM CLI managed bucket completely removed"
```

### 3. Bulk Cleanup Script

Create `scripts/cleanup-orphaned-resources.sh`:

```bash
#!/bin/bash

# Cleanup Orphaned Resources Script
set -e

REGION="us-east-1"
PROJECT_PREFIX="serverless-crud-api"
DRY_RUN=true

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --execute)
      DRY_RUN=false
      shift
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --project)
      PROJECT_PREFIX="$2"
      shift 2
      ;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

if [[ "$DRY_RUN" == "true" ]]; then
  echo "🔍 DRY RUN MODE - No resources will be deleted"
  echo "Use --execute to actually delete resources"
else
  echo "⚠️  EXECUTE MODE - Resources will be deleted!"
  read -p "Are you sure? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

echo ""
echo "🧹 Cleaning orphaned resources for project: $PROJECT_PREFIX"
echo "Region: $REGION"
echo ""

# Clean orphaned API Gateways
echo "📡 Cleaning orphaned API Gateways..."
ORPHANED_APIS=$(aws apigateway get-rest-apis --region $REGION \
  --query "items[?!tags.\"aws:cloudformation:stack-name\" && (contains(name, '$PROJECT_PREFIX') || contains(description, '$PROJECT_PREFIX'))].id" \
  --output text)

for API_ID in $ORPHANED_APIS; do
  if [[ -n "$API_ID" ]]; then
    echo "  Found orphaned API: $API_ID"
    if [[ "$DRY_RUN" == "false" ]]; then
      aws apigateway delete-rest-api --rest-api-id $API_ID --region $REGION
      echo "  ✅ Deleted API: $API_ID"
    fi
  fi
done

# Clean orphaned Lambda functions
echo "⚡ Cleaning orphaned Lambda functions..."
ORPHANED_FUNCTIONS=$(aws lambda list-functions --region $REGION \
  --query "Functions[?contains(FunctionName, '$PROJECT_PREFIX')].FunctionName" \
  --output text)

for FUNCTION_NAME in $ORPHANED_FUNCTIONS; do
  if [[ -n "$FUNCTION_NAME" ]]; then
    # Check if function has CloudFormation tags
    TAGS=$(aws lambda list-tags --resource arn:aws:lambda:$REGION:$(aws sts get-caller-identity --query Account --output text):function:$FUNCTION_NAME --region $REGION \
      --query 'Tags."aws:cloudformation:stack-name"' --output text 2>/dev/null || echo "")
    
    if [[ -z "$TAGS" || "$TAGS" == "None" ]]; then
      echo "  Found orphaned function: $FUNCTION_NAME"
      if [[ "$DRY_RUN" == "false" ]]; then
        aws lambda delete-function --function-name $FUNCTION_NAME --region $REGION
        echo "  ✅ Deleted function: $FUNCTION_NAME"
      fi
    fi
  fi
done

echo ""
echo "🎯 Cleanup complete!"
```

## 🛡️ Prevention Strategies

### 1. Enhanced Cleanup Script

Update the main cleanup script to detect and warn about orphaned resources:

```bash
# Add to cleanup.sh
echo "🔍 Checking for orphaned resources..."
./scripts/detect-orphaned-resources.sh

if [[ $? -ne 0 ]]; then
  echo "⚠️  Orphaned resources detected!"
  echo "Run './scripts/cleanup-orphaned-resources.sh --execute' to clean them up"
fi
```

### 2. Team Best Practices

#### For New Team Members:
1. **Always use the provided scripts** for deployment and cleanup
2. **Never manually create resources** that should be managed by CloudFormation
3. **Run orphaned resource detection** before and after major changes
4. **Document any manual interventions** in team chat/tickets

#### For Team Leads:
1. **Regular audits** (weekly/monthly) for orphaned resources
2. **Cost monitoring alerts** for unexpected resource usage
3. **Team training** on proper resource lifecycle management
4. **Code review requirements** for infrastructure changes

### 3. Automated Monitoring

#### CloudWatch Billing Alerts
```bash
# Create billing alarm for unexpected costs
aws cloudwatch put-metric-alarm \
  --alarm-name "serverless-crud-api-unexpected-costs" \
  --alarm-description "Alert when costs exceed expected serverless usage" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --threshold 10.0 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=Currency,Value=USD \
  --evaluation-periods 1 \
  --region us-east-1
```

#### Scheduled Orphaned Resource Detection
```yaml
# GitHub Actions workflow for regular audits
name: Orphaned Resource Audit
on:
  schedule:
    - cron: '0 9 * * MON'  # Every Monday at 9 AM
  workflow_dispatch:

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1
      - name: Detect orphaned resources
        run: ./scripts/detect-orphaned-resources.sh
      - name: Create issue if orphaned resources found
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: 'Orphaned AWS Resources Detected',
              body: 'Automated scan found orphaned resources. Please review and clean up.',
              labels: ['infrastructure', 'cost-optimization']
            })
```

## 📋 Team Checklist

### Before Starting Work:
- [ ] Run `./scripts/detect-orphaned-resources.sh` to check current state
- [ ] Verify no unexpected resources exist in AWS console
- [ ] Check recent AWS billing for unusual charges

### During Development:
- [ ] Use only the provided deployment scripts
- [ ] If deployment fails, check for orphaned resources immediately
- [ ] Document any manual AWS console changes in team chat

### After Completing Work:
- [ ] Run proper cleanup script: `./scripts/cleanup.sh --stage dev --force`
- [ ] Verify cleanup with: `./scripts/detect-orphaned-resources.sh`
- [ ] Check AWS console to confirm resources are gone
- [ ] **Special attention to SAM CLI managed S3 buckets** - these are commonly left behind
- [ ] If orphaned resources found, clean them up: `./scripts/cleanup-orphaned-resources.sh --execute`
- [ ] Verify S3 buckets are completely removed: `aws s3 ls | grep aws-sam-cli-managed`

### Weekly Team Audit:
- [ ] Run orphaned resource detection across all environments
- [ ] Review AWS billing for unexpected charges
- [ ] Update team on any orphaned resources found and cleaned
- [ ] Discuss any process improvements needed

## 🎯 Cost Optimization Benefits

### Implementing This Guide Provides:
- ✅ **Predictable costs** - No surprise bills from forgotten resources
- ✅ **True serverless economics** - Pay only for what you use
- ✅ **Team confidence** - Members can experiment without fear of leaving expensive resources
- ✅ **Operational excellence** - Clean, manageable infrastructure
- ✅ **Compliance** - Proper resource lifecycle management

### Expected Cost Savings:
- **Small team (2-5 developers):** $50-200/month in prevented orphaned resource costs
- **Medium team (5-15 developers):** $200-500/month in prevented costs
- **Large team (15+ developers):** $500-2000/month in prevented costs

## 🚨 Emergency Procedures

### If You Discover Expensive Orphaned Resources:
1. **Immediate action:** Stop/delete the resource if safe to do so
2. **Document:** Take screenshots and save resource configurations
3. **Notify team:** Alert team lead and other developers
4. **Root cause analysis:** Determine how the resource became orphaned
5. **Process improvement:** Update procedures to prevent recurrence

### If Unsure About a Resource:
1. **Don't delete immediately** - investigate first
2. **Check CloudFormation tags** to see if it's managed
3. **Ask team members** if anyone recognizes the resource
4. **Check git history** for recent infrastructure changes
5. **When in doubt, ask for help** rather than risk deleting important resources

## 📚 Additional Resources

- [AWS Cost Management Best Practices](https://docs.aws.amazon.com/cost-management/)
- [CloudFormation Resource Lifecycle](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/resource-import.html)
- [AWS Billing and Cost Management](https://docs.aws.amazon.com/awsaccountbilling/)
- [Serverless Cost Optimization](https://aws.amazon.com/lambda/pricing/)

---

**Remember: In serverless architecture, orphaned resources are the enemy of cost efficiency!** 💰

This guide helps maintain the **true serverless promise**: pay only for what you use, when you use it. 🚀