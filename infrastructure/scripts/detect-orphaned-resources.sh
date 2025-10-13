#!/bin/bash

# Detect Orphaned Resources Script
# Scans for AWS resources that may have been left behind after CloudFormation stack deletions
set -e

# Default values
REGION="us-east-1"
PROJECT_NAME="serverless-crud-api"
STAGE="dev"
QUIET=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

print_success() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    fi
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--stage)
      STAGE="$2"
      shift 2
      ;;
    -r|--region)
      REGION="$2"
      shift 2
      ;;
    -p|--project-name)
      PROJECT_NAME="$2"
      shift 2
      ;;
    -q|--quiet)
      QUIET=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  -s, --stage STAGE        Deployment stage (dev, staging, prod) [default: dev]"
      echo "  -r, --region REGION      AWS region [default: us-east-1]"
      echo "  -p, --project-name NAME  Project name [default: serverless-crud-api]"
      echo "  -q, --quiet              Suppress info messages, only show warnings/errors"
      echo "  -h, --help               Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    print_error "AWS CLI is not configured or credentials are invalid"
    exit 1
fi

ORPHANED_FOUND=false
PROJECT_PREFIX="$PROJECT_NAME-$STAGE"

print_status "🔍 Scanning for orphaned resources..."
print_status "Project: $PROJECT_NAME"
print_status "Stage: $STAGE"
print_status "Region: $REGION"
print_status "Looking for resources with prefix: $PROJECT_PREFIX"
echo ""

# Function to check if a resource has CloudFormation tags
has_cloudformation_tags() {
    local resource_type=$1
    local resource_id=$2
    
    case $resource_type in
        "api-gateway")
            local tags=$(aws apigateway get-rest-api --rest-api-id "$resource_id" --region "$REGION" \
                --query 'tags."aws:cloudformation:stack-name"' --output text 2>/dev/null || echo "")
            [[ -n "$tags" && "$tags" != "None" ]]
            ;;
        "lambda")
            local account_id=$(aws sts get-caller-identity --query Account --output text)
            local tags=$(aws lambda list-tags --resource "arn:aws:lambda:$REGION:$account_id:function:$resource_id" --region "$REGION" \
                --query 'Tags."aws:cloudformation:stack-name"' --output text 2>/dev/null || echo "")
            [[ -n "$tags" && "$tags" != "None" ]]
            ;;
        "dynamodb")
            local tags=$(aws dynamodb list-tags-of-resource --resource-arn "arn:aws:dynamodb:$REGION:$(aws sts get-caller-identity --query Account --output text):table/$resource_id" --region "$REGION" \
                --query 'Tags[?Key==`aws:cloudformation:stack-name`].Value' --output text 2>/dev/null || echo "")
            [[ -n "$tags" && "$tags" != "None" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

# Check API Gateway
print_status "📡 Checking API Gateway..."
APIS=$(aws apigateway get-rest-apis --region "$REGION" \
  --query "items[?contains(name, '$PROJECT_PREFIX') || contains(to_string(tags), '$PROJECT_NAME')].[id,name,createdDate]" \
  --output text 2>/dev/null || echo "")

if [[ -n "$APIS" && "$APIS" != "None" ]]; then
    while IFS=$'\t' read -r api_id api_name created_date; do
        if [[ -n "$api_id" ]]; then
            if ! has_cloudformation_tags "api-gateway" "$api_id"; then
                print_warning "Found orphaned API Gateway: $api_id ($api_name) - Created: $created_date"
                ORPHANED_FOUND=true
            else
                print_status "✅ API Gateway $api_id is managed by CloudFormation"
            fi
        fi
    done <<< "$APIS"
else
    print_success "✅ No API Gateway resources found with project prefix"
fi
echo ""

# Check Lambda Functions
print_status "⚡ Checking Lambda Functions..."
FUNCTIONS=$(aws lambda list-functions --region "$REGION" \
  --query "Functions[?contains(FunctionName, '$PROJECT_PREFIX')].[FunctionName,LastModified,Runtime]" \
  --output text 2>/dev/null || echo "")

if [[ -n "$FUNCTIONS" && "$FUNCTIONS" != "None" ]]; then
    while IFS=$'\t' read -r function_name last_modified runtime; do
        if [[ -n "$function_name" ]]; then
            if ! has_cloudformation_tags "lambda" "$function_name"; then
                print_warning "Found orphaned Lambda function: $function_name ($runtime) - Modified: $last_modified"
                ORPHANED_FOUND=true
            else
                print_status "✅ Lambda function $function_name is managed by CloudFormation"
            fi
        fi
    done <<< "$FUNCTIONS"
else
    print_success "✅ No Lambda functions found with project prefix"
fi
echo ""

# Check DynamoDB Tables
print_status "🗄️  Checking DynamoDB Tables..."
ALL_TABLES=$(aws dynamodb list-tables --region "$REGION" --query "TableNames" --output text 2>/dev/null || echo "")
PROJECT_TABLES=""

for table in $ALL_TABLES; do
    if [[ "$table" == *"$PROJECT_PREFIX"* ]]; then
        PROJECT_TABLES="$PROJECT_TABLES $table"
    fi
done

if [[ -n "$PROJECT_TABLES" ]]; then
    for table_name in $PROJECT_TABLES; do
        if [[ -n "$table_name" ]]; then
            if ! has_cloudformation_tags "dynamodb" "$table_name"; then
                # Get table details for cost estimation
                table_info=$(aws dynamodb describe-table --table-name "$table_name" --region "$REGION" \
                    --query 'Table.{Status:TableStatus,Billing:BillingModeSummary.BillingMode,Items:ItemCount}' \
                    --output text 2>/dev/null || echo "UNKNOWN UNKNOWN UNKNOWN")
                print_warning "Found orphaned DynamoDB table: $table_name - Status: $table_info"
                print_warning "  ⚠️  DynamoDB tables can be expensive! Check billing mode and provisioned capacity."
                ORPHANED_FOUND=true
            else
                print_status "✅ DynamoDB table $table_name is managed by CloudFormation"
            fi
        fi
    done
else
    print_success "✅ No DynamoDB tables found with project prefix"
fi
echo ""

# Check CloudWatch Log Groups
print_status "📊 Checking CloudWatch Log Groups..."
LOG_GROUPS=$(aws logs describe-log-groups --region "$REGION" \
  --query "logGroups[?contains(logGroupName, '$PROJECT_PREFIX')].[logGroupName,storedBytes,retentionInDays]" \
  --output text 2>/dev/null || echo "")

if [[ -n "$LOG_GROUPS" && "$LOG_GROUPS" != "None" ]]; then
    while IFS=$'\t' read -r log_group_name stored_bytes retention_days; do
        if [[ -n "$log_group_name" ]]; then
            # Log groups don't have CloudFormation tags, so we check if they're likely orphaned
            # by seeing if their associated Lambda functions exist
            if [[ "$log_group_name" == *"/aws/lambda/"* ]]; then
                function_name=$(echo "$log_group_name" | sed 's|/aws/lambda/||')
                if ! aws lambda get-function --function-name "$function_name" --region "$REGION" &>/dev/null; then
                    stored_mb=$((stored_bytes / 1024 / 1024))
                    print_warning "Found orphaned Log Group: $log_group_name - Size: ${stored_mb}MB - Retention: ${retention_days:-unlimited} days"
                    ORPHANED_FOUND=true
                fi
            else
                # For non-Lambda log groups, just report them for manual review
                stored_mb=$((stored_bytes / 1024 / 1024))
                print_warning "Found Log Group (manual review needed): $log_group_name - Size: ${stored_mb}MB"
            fi
        fi
    done <<< "$LOG_GROUPS"
else
    print_success "✅ No CloudWatch Log Groups found with project prefix"
fi
echo ""

# Check S3 Buckets (including SAM CLI managed buckets)
print_status "🪣 Checking S3 Buckets..."
BUCKETS=$(aws s3api list-buckets --region "$REGION" \
  --query "Buckets[?contains(Name, '$PROJECT_NAME') || contains(Name, 'sam-cli')].[Name,CreationDate]" \
  --output text 2>/dev/null || echo "")

if [[ -n "$BUCKETS" && "$BUCKETS" != "None" ]]; then
    while IFS=$'\t' read -r bucket_name creation_date; do
        if [[ -n "$bucket_name" ]]; then
            # Check if bucket has objects and get size
            object_count=$(aws s3api list-objects-v2 --bucket "$bucket_name" --query 'KeyCount' --output text 2>/dev/null || echo "0")
            if [[ "$object_count" -gt 0 ]]; then
                # Get bucket size
                bucket_size=$(aws s3 ls s3://"$bucket_name" --recursive --summarize 2>/dev/null | grep "Total Size" | awk '{print $3, $4}' || echo "Unknown size")
                print_warning "Found S3 bucket with objects: $bucket_name"
                print_warning "  📊 Objects: $object_count - Size: $bucket_size - Created: $creation_date"
                
                # Special handling for SAM CLI managed buckets
                if [[ "$bucket_name" == *"aws-sam-cli-managed"* ]]; then
                    print_warning "  🎯 This is a SAM CLI managed bucket (common orphaned resource)"
                    print_warning "  💰 Cost: ~\$0.023/GB/month for storage"
                    print_warning "  🧹 Safe to delete after stack cleanup"
                    ORPHANED_FOUND=true
                else
                    print_warning "  💡 Check if this bucket is still needed"
                fi
            else
                print_status "✅ S3 bucket $bucket_name is empty"
            fi
        fi
    done <<< "$BUCKETS"
else
    print_success "✅ No S3 buckets found with project prefix"
fi

# Special check for SAM CLI managed buckets (even without project prefix)
print_status "🔍 Checking for SAM CLI Managed Buckets..."
SAM_BUCKETS=$(aws s3 ls | grep "aws-sam-cli-managed" | awk '{print $3}' || echo "")

if [[ -n "$SAM_BUCKETS" ]]; then
    for bucket in $SAM_BUCKETS; do
        object_count=$(aws s3api list-objects-v2 --bucket "$bucket" --query 'KeyCount' --output text 2>/dev/null || echo "0")
        if [[ "$object_count" -gt 0 ]]; then
            bucket_size=$(aws s3 ls s3://"$bucket" --recursive --summarize 2>/dev/null | grep "Total Size" | awk '{print $3, $4}' || echo "Unknown size")
            print_warning "Found SAM CLI managed bucket: $bucket"
            print_warning "  📊 Objects: $object_count - Size: $bucket_size"
            print_warning "  💰 Ongoing storage cost: ~\$0.023/GB/month"
            print_warning "  🧹 Can be safely deleted after stack cleanup"
            ORPHANED_FOUND=true
        fi
    done
else
    print_success "✅ No SAM CLI managed buckets found"
fi
echo ""

# Summary
print_status "🎯 Scan complete!"
echo ""

if [[ "$ORPHANED_FOUND" == "true" ]]; then
    print_error "⚠️  ORPHANED RESOURCES DETECTED!"
    echo ""
    print_warning "💰 Cost Impact:"
    print_warning "  - Orphaned resources continue to incur charges"
    print_warning "  - DynamoDB tables can be especially expensive"
    print_warning "  - API Gateway has per-request costs"
    print_warning "  - Log Groups consume storage costs"
    echo ""
    print_warning "🧹 Cleanup Options:"
    print_warning "  1. Manual cleanup via AWS Console"
    print_warning "  2. Use cleanup script: ./scripts/cleanup-orphaned-resources.sh --execute"
    print_warning "  3. Delete individual resources with AWS CLI"
    echo ""
    print_warning "📚 For detailed cleanup instructions, see: docs/ORPHANED_RESOURCES_GUIDE.md"
    echo ""
    exit 1
else
    print_success "🎉 No orphaned resources found!"
    print_success "Your AWS account is clean and cost-optimized."
    echo ""
    exit 0
fi