#!/bin/bash
# Delete everything
set -e

STAGE=${1:-dev}

# Navigate to infrastructure directory
cd "$(dirname "$0")/.."

# Get project name and region from parameter file
PARAM_FILE="parameters/${STAGE}.json"
if [[ -f "$PARAM_FILE" ]]; then
  PROJECT_NAME=$(jq -r '.Parameters.ProjectName // "serverless-crud-api"' "$PARAM_FILE")
  REGION_FROM_PARAMS=$(jq -r '.Parameters.Region // "us-east-1"' "$PARAM_FILE")
  REGION=${2:-$REGION_FROM_PARAMS}
else
  PROJECT_NAME="serverless-crud-api"
  REGION=${2:-us-east-1}
fi

echo "🗑️  Deleting $PROJECT_NAME from $STAGE environment in $REGION..."
echo "   Project: $PROJECT_NAME"
echo "   Region: $REGION"

# Delete API stack first (it depends on foundation)
API_STACK="$PROJECT_NAME-$STAGE-api"
FOUNDATION_STACK="$PROJECT_NAME-$STAGE-foundation"

echo "1. Deleting API stack: $API_STACK"
if aws cloudformation describe-stacks --stack-name "$API_STACK" --region "$REGION" > /dev/null 2>&1; then
  aws cloudformation delete-stack --stack-name "$API_STACK" --region "$REGION"
  echo "   Waiting for API stack deletion to complete..."
  aws cloudformation wait stack-delete-complete --stack-name "$API_STACK" --region "$REGION"
  echo "   ✅ API stack deleted"
else
  echo "   ⚠️  API stack not found, skipping"
fi

echo "2. Deleting Foundation stack: $FOUNDATION_STACK"
if aws cloudformation describe-stacks --stack-name "$FOUNDATION_STACK" --region "$REGION" > /dev/null 2>&1; then
  aws cloudformation delete-stack --stack-name "$FOUNDATION_STACK" --region "$REGION"
  echo "   Waiting for Foundation stack deletion to complete..."
  aws cloudformation wait stack-delete-complete --stack-name "$FOUNDATION_STACK" --region "$REGION"
  echo "   ✅ Foundation stack deleted"
else
  echo "   ⚠️  Foundation stack not found, skipping"
fi

echo "🎉 Cleanup complete! All resources deleted."