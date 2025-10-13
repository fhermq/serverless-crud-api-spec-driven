#!/bin/bash
# Simple CRUD API Deployment
set -e

STAGE=${1:-dev}
REGION=${2:-us-east-1}

# Validate stage
case $STAGE in
  dev|staging|prod)
    echo "🚀 Deploying CRUD API to $STAGE environment in $REGION..."
    ;;
  *)
    echo "❌ Invalid stage: $STAGE. Use: dev, staging, or prod"
    exit 1
    ;;
esac

# Navigate to infrastructure directory
cd "$(dirname "$0")/.."

# Check if parameter file exists and extract values
PARAM_FILE="parameters/${STAGE}.json"
if [[ -f "$PARAM_FILE" ]]; then
  echo "📋 Using parameter file: $PARAM_FILE"
  
  # Extract values from JSON parameter file
  PROJECT_NAME=$(jq -r '.Parameters.ProjectName // "serverless-crud-api"' "$PARAM_FILE")
  API_RATE_LIMIT=$(jq -r '.Parameters.ApiRateLimit // "10"' "$PARAM_FILE")
  API_BURST_LIMIT=$(jq -r '.Parameters.ApiBurstLimit // "20"' "$PARAM_FILE")
  API_DAILY_QUOTA=$(jq -r '.Parameters.ApiDailyQuota // "1000"' "$PARAM_FILE")
  PARAM_REGION=$(jq -r '.Parameters.Region // "us-east-1"' "$PARAM_FILE")
  GITHUB_REPOSITORY=$(jq -r '.Parameters.GitHubRepository // ""' "$PARAM_FILE")
  GITHUB_BRANCH=$(jq -r '.Parameters.GitHubBranch // "main"' "$PARAM_FILE")
  
  # Use parameter file region if no region specified in command line
  if [[ "$REGION" == "us-east-1" ]] && [[ "$PARAM_REGION" != "us-east-1" ]]; then
    REGION="$PARAM_REGION"
    echo "   Using region from parameter file: $REGION"
  fi
  
  echo "   Project: $PROJECT_NAME"
  echo "   Region: $REGION"
  echo "   Rate Limit: $API_RATE_LIMIT req/sec"
  echo "   Burst Limit: $API_BURST_LIMIT requests"
  echo "   Daily Quota: $API_DAILY_QUOTA requests/day"
else
  echo "⚠️  No parameter file found for stage '$STAGE', using defaults"
  PROJECT_NAME="serverless-crud-api"
  API_RATE_LIMIT=10
  API_BURST_LIMIT=20
  API_DAILY_QUOTA=1000
  GITHUB_REPOSITORY=""
  GITHUB_BRANCH="main"
fi

# Environment-specific S3 bucket
S3_BUCKET="$PROJECT_NAME-$STAGE-sam-deployments"

# Check if S3 bucket exists, create if not
if ! aws s3api head-bucket --bucket "$S3_BUCKET" --region "$REGION" > /dev/null 2>&1; then
  echo "📦 Creating S3 bucket: $S3_BUCKET"
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$S3_BUCKET" --region "$REGION"
  else
    aws s3api create-bucket --bucket "$S3_BUCKET" --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION"
  fi
  
  # Enable versioning
  aws s3api put-bucket-versioning --bucket "$S3_BUCKET" \
    --versioning-configuration Status=Enabled
  
  # Block public access
  aws s3api put-public-access-block --bucket "$S3_BUCKET" \
    --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
fi

# Deploy foundation (skip if no changes)
# Prepare parameter overrides
FOUNDATION_PARAMS="Stage=$STAGE ProjectName=$PROJECT_NAME Region=$REGION"
if [[ -n "$GITHUB_REPOSITORY" ]]; then
  FOUNDATION_PARAMS="$FOUNDATION_PARAMS GitHubRepository=$GITHUB_REPOSITORY GitHubBranch=$GITHUB_BRANCH"
fi

sam deploy --template-file stacks/01-foundation.yaml \
  --stack-name $PROJECT_NAME-$STAGE-foundation \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --parameter-overrides $FOUNDATION_PARAMS \
  --s3-bucket "$S3_BUCKET" \
  --region "$REGION" \
  --no-fail-on-empty-changeset

# Deploy API
sam build --template-file stacks/02-api-and-functions.yaml
sam deploy --template-file .aws-sam/build/template.yaml \
  --stack-name $PROJECT_NAME-$STAGE-api \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    FoundationStackName=$PROJECT_NAME-$STAGE-foundation \
    Region=$REGION \
    EnableApiKeyAuth=true \
    ApiRateLimit=$API_RATE_LIMIT \
    ApiBurstLimit=$API_BURST_LIMIT \
    ApiDailyQuota=$API_DAILY_QUOTA \
  --s3-bucket "$S3_BUCKET" \
  --region "$REGION" \
  --no-fail-on-empty-changeset

echo "✅ Deployment complete!"
echo "Run './scripts/get-api-key.sh $STAGE $REGION' to get your API key"