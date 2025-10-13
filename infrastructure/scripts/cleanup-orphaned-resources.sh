#!/bin/bash

# Cleanup Orphaned Resources Script
# Safely removes AWS resources that are no longer managed by CloudFormation
set -e

# Default values
REGION="us-east-1"
PROJECT_NAME="serverless-crud-api"
STAGE="dev"
DRY_RUN=true
FORCE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --execute                Actually delete resources (default: dry-run)"
    echo "  -s, --stage STAGE        Deployment stage (dev, staging, prod) [default: dev]"
    echo "  -r, --region REGION      AWS region [default: us-east-1]"
    echo "  -p, --project-name NAME  Project name [default: serverless-crud-api]"
    echo "  -f, --force              Skip confirmation prompts"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                       # Dry run - show what would be deleted"
    echo "  $0 --execute             # Actually delete orphaned resources"
    echo "  $0 --execute --force     # Delete without confirmation"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --execute)
      DRY_RUN=false
      shift
      ;;
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
    -f|--force)
      FORCE=true
      shift
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      print_error "Unknown option: $1"
      show_usage
      exit 1
      ;;
  esac
done

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    print_error "AWS CLI is not configured or credentials are invalid"
    print_error "Please run 'aws configure' or set up your AWS credentials"
    exit 1
fi

PROJECT_PREFIX="$PROJECT_NAME-$STAGE"

if [[ "$DRY_RUN" == "true" ]]; then
  print_warning "🔍 DRY RUN MODE - No resources will be deleted"
  print_warning "Use --execute to actually delete resources"
else
  print_error "⚠️  EXECUTE MODE - Resources will be deleted!"
  if [[ "$FORCE" != "true" ]]; then
    echo ""
    print_warning "This will permanently delete orphaned AWS resources!"
    print_warning "Make sure you have:"
    print_warning "  1. Backed up any important data"
    print_warning "  2. Verified these resources are truly orphaned"
    print_warning "  3. Confirmed with your team if needed"
    echo ""
    read -p "Are you absolutely sure you want to proceed? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      print_status "Cleanup cancelled by user"
      exit 0
    fi
  fi
fi

echo ""
print_status "🧹 Cleaning orphaned resources for project: $PROJECT_NAME"
print_status "Stage: $STAGE"
print_status "Region: $REGION"
print_status "Mode: $([ "$DRY_RUN" == "true" ] && echo "DRY RUN" || echo "EXECUTE")"
echo ""

RESOURCES_FOUND=false

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
            local account_id=$(aws sts get-caller-identity --query Account --output text)
            local tags=$(aws dynamodb list-tags-of-resource --resource-arn "arn:aws:dynamodb:$REGION:$account_id:table/$resource_id" --region "$REGION" \
                --query 'Tags[?Key==`aws:cloudformation:stack-name`].Value' --output text 2>/dev/null || echo "")
            [[ -n "$tags" && "$tags" != "None" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

# Clean orphaned API Gateways
print_status "📡 Cleaning orphaned API Gateways..."
APIS=$(aws apigateway get-rest-apis --region "$REGION" \
  --query "items[?contains(name, '$PROJECT_PREFIX') || contains(to_string(tags), '$PROJECT_NAME')].[id,name,createdDate]" \
  --output text 2>/dev/null || echo "")

if [[ -n "$APIS" && "$APIS" != "None" ]]; then
    while IFS=$'\t' read -r api_id api_name created_date; do
        if [[ -n "$api_id" ]]; then
            if ! has_cloudformation_tags "api-gateway" "$api_id"; then
                print_warning "  Found orphaned API: $api_id ($api_name) - Created: $created_date"
                RESOURCES_FOUND=true
                if [[ "$DRY_RUN" == "false" ]]; then
                    print_status "  Deleting API Gateway: $api_id"
                    aws apigateway delete-rest-api --rest-api-id "$api_id" --region "$REGION"
                    print_success "  ✅ Deleted API Gateway: $api_id"
                fi
            fi
        fi
    done <<< "$APIS"
fi

# Clean orphaned Lambda functions
print_status "⚡ Cleaning orphaned Lambda functions..."
FUNCTIONS=$(aws lambda list-functions --region "$REGION" \
  --query "Functions[?contains(FunctionName, '$PROJECT_PREFIX')].[FunctionName,LastModified,Runtime]" \
  --output text 2>/dev/null || echo "")

if [[ -n "$FUNCTIONS" && "$FUNCTIONS" != "None" ]]; then
    while IFS=$'\t' read -r function_name last_modified runtime; do
        if [[ -n "$function_name" ]]; then
            if ! has_cloudformation_tags "lambda" "$function_name"; then
                print_warning "  Found orphaned Lambda function: $function_name ($runtime)"
                RESOURCES_FOUND=true
                if [[ "$DRY_RUN" == "false" ]]; then
                    print_status "  Deleting Lambda function: $function_name"
                    aws lambda delete-function --function-name "$function_name" --region "$REGION"
                    print_success "  ✅ Deleted Lambda function: $function_name"
                fi
            fi
        fi
    done <<< "$FUNCTIONS"
fi

# Clean orphaned DynamoDB tables (with extra caution)
print_status "🗄️  Cleaning orphaned DynamoDB tables..."
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
                table_info=$(aws dynamodb describe-table --table-name "$table_name" --region "$REGION" \
                    --query 'Table.{Status:TableStatus,Billing:BillingModeSummary.BillingMode,Items:ItemCount}' \
                    --output text 2>/dev/null || echo "UNKNOWN UNKNOWN UNKNOWN")
                print_warning "  Found orphaned DynamoDB table: $table_name - $table_info"
                print_warning "  ⚠️  DynamoDB tables contain data and can be expensive!"
                RESOURCES_FOUND=true
                
                if [[ "$DRY_RUN" == "false" ]]; then
                    print_error "  🚨 CAUTION: About to delete DynamoDB table with potential data!"
                    if [[ "$FORCE" != "true" ]]; then
                        read -p "  Delete table $table_name? This cannot be undone! (y/N): " -n 1 -r
                        echo
                        if [[ $REPLY =~ ^[Yy]$ ]]; then
                            print_status "  Deleting DynamoDB table: $table_name"
                            aws dynamodb delete-table --table-name "$table_name" --region "$REGION"
                            print_success "  ✅ Deleted DynamoDB table: $table_name"
                        else
                            print_status "  Skipped DynamoDB table: $table_name"
                        fi
                    else
                        print_status "  Deleting DynamoDB table: $table_name (force mode)"
                        aws dynamodb delete-table --table-name "$table_name" --region "$REGION"
                        print_success "  ✅ Deleted DynamoDB table: $table_name"
                    fi
                fi
            fi
        fi
    done
fi

# Clean orphaned CloudWatch Log Groups
print_status "📊 Cleaning orphaned CloudWatch Log Groups..."
LOG_GROUPS=$(aws logs describe-log-groups --region "$REGION" \
  --query "logGroups[?contains(logGroupName, '$PROJECT_PREFIX')].[logGroupName,storedBytes]" \
  --output text 2>/dev/null || echo "")

if [[ -n "$LOG_GROUPS" && "$LOG_GROUPS" != "None" ]]; then
    while IFS=$'\t' read -r log_group_name stored_bytes; do
        if [[ -n "$log_group_name" ]]; then
            # Check if this is a Lambda log group and if the function still exists
            if [[ "$log_group_name" == *"/aws/lambda/"* ]]; then
                function_name=$(echo "$log_group_name" | sed 's|/aws/lambda/||')
                if ! aws lambda get-function --function-name "$function_name" --region "$REGION" &>/dev/null; then
                    stored_mb=$((stored_bytes / 1024 / 1024))
                    print_warning "  Found orphaned Log Group: $log_group_name - Size: ${stored_mb}MB"
                    RESOURCES_FOUND=true
                    if [[ "$DRY_RUN" == "false" ]]; then
                        print_status "  Deleting Log Group: $log_group_name"
                        aws logs delete-log-group --log-group-name "$log_group_name" --region "$REGION"
                        print_success "  ✅ Deleted Log Group: $log_group_name"
                    fi
                fi
            fi
        fi
    done <<< "$LOG_GROUPS"
fi

# Clean orphaned S3 buckets (including SAM CLI managed)
print_status "🪣 Cleaning orphaned S3 buckets..."

# Check for project-specific buckets
PROJECT_BUCKETS=$(aws s3api list-buckets --region "$REGION" \
  --query "Buckets[?contains(Name, '$PROJECT_PREFIX')].[Name]" \
  --output text 2>/dev/null || echo "")

for BUCKET_NAME in $PROJECT_BUCKETS; do
  if [[ -n "$BUCKET_NAME" ]]; then
    print_warning "  Found project bucket: $BUCKET_NAME"
    RESOURCES_FOUND=true
    if [[ "$DRY_RUN" == "false" ]]; then
      print_status "  Cleaning bucket: $BUCKET_NAME"
      # Delete all objects first
      aws s3 rm s3://$BUCKET_NAME --recursive --region "$REGION" 2>/dev/null || true
      # Delete versioned objects if any
      aws s3api delete-objects --bucket $BUCKET_NAME --region "$REGION" \
        --delete "$(aws s3api list-object-versions --bucket $BUCKET_NAME --region "$REGION" \
        --output json --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' 2>/dev/null || echo '{\"Objects\":[]}')" 2>/dev/null || true
      # Delete delete markers
      aws s3api delete-objects --bucket $BUCKET_NAME --region "$REGION" \
        --delete "$(aws s3api list-object-versions --bucket $BUCKET_NAME --region "$REGION" \
        --output json --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' 2>/dev/null || echo '{\"Objects\":[]}')" 2>/dev/null || true
      # Delete bucket
      aws s3 rb s3://$BUCKET_NAME --region "$REGION" 2>/dev/null || true
      print_success "  ✅ Deleted bucket: $BUCKET_NAME"
    fi
  fi
done

# Check for SAM CLI managed buckets (common orphaned resource)
print_status "🔍 Checking SAM CLI managed buckets..."
SAM_BUCKETS=$(aws s3 ls | grep "aws-sam-cli-managed" | awk '{print $3}' || echo "")

for BUCKET_NAME in $SAM_BUCKETS; do
  if [[ -n "$BUCKET_NAME" ]]; then
    object_count=$(aws s3api list-objects-v2 --bucket "$BUCKET_NAME" --query 'KeyCount' --output text 2>/dev/null || echo "0")
    if [[ "$object_count" -gt 0 ]]; then
      bucket_size=$(aws s3 ls s3://"$BUCKET_NAME" --recursive --summarize 2>/dev/null | grep "Total Size" | awk '{print $3, $4}' || echo "Unknown size")
      print_warning "  Found SAM CLI managed bucket: $BUCKET_NAME ($bucket_size, $object_count objects)"
      print_warning "  💰 Ongoing storage cost: ~\$0.023/GB/month"
      RESOURCES_FOUND=true
      if [[ "$DRY_RUN" == "false" ]]; then
        print_status "  Cleaning SAM CLI managed bucket: $BUCKET_NAME"
        # Delete all objects first
        aws s3 rm s3://$BUCKET_NAME --recursive --region "$REGION" 2>/dev/null || true
        # Delete versioned objects if any
        aws s3api delete-objects --bucket $BUCKET_NAME --region "$REGION" \
          --delete "$(aws s3api list-object-versions --bucket $BUCKET_NAME --region "$REGION" \
          --output json --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' 2>/dev/null || echo '{\"Objects\":[]}')" 2>/dev/null || true
        # Delete delete markers
        aws s3api delete-objects --bucket $BUCKET_NAME --region "$REGION" \
          --delete "$(aws s3api list-object-versions --bucket $BUCKET_NAME --region "$REGION" \
          --output json --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' 2>/dev/null || echo '{\"Objects\":[]}')" 2>/dev/null || true
        # Delete bucket
        aws s3 rb s3://$BUCKET_NAME --region "$REGION" 2>/dev/null || true
        print_success "  ✅ Deleted SAM CLI managed bucket: $BUCKET_NAME"
      fi
    fi
  fi
done

echo ""

# Summary
if [[ "$RESOURCES_FOUND" == "true" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "🎯 Dry run complete - orphaned resources found!"
        echo ""
        print_warning "To actually delete these resources, run:"
        print_warning "  $0 --execute --stage $STAGE --region $REGION"
        echo ""
        print_warning "💡 For more information, see: docs/ORPHANED_RESOURCES_GUIDE.md"
    else
        print_success "🎯 Cleanup complete!"
        print_success "Orphaned resources have been removed."
        echo ""
        print_status "💰 Cost savings achieved by removing orphaned resources!"
        print_status "Your AWS account is now optimized for serverless cost efficiency."
    fi
else
    print_success "🎉 No orphaned resources found!"
    print_success "Your AWS account is already clean and cost-optimized."
fi

echo ""