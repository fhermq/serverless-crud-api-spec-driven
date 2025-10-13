#!/bin/bash
# Get API key and URL
set -e

STAGE=${1:-dev}
REGION=${2:-us-east-1}

# Navigate to infrastructure directory
cd "$(dirname "$0")/.."

# Get project name from parameter file
PARAM_FILE="parameters/${STAGE}.json"
if [[ -f "$PARAM_FILE" ]]; then
  PROJECT_NAME=$(jq -r '.Parameters.ProjectName // "serverless-crud-api"' "$PARAM_FILE")
  PARAM_REGION=$(jq -r '.Parameters.Region // "us-east-1"' "$PARAM_FILE")
  # Use region from parameter file if not provided as argument
  if [[ "$REGION" == "us-east-1" ]] && [[ "$PARAM_REGION" != "us-east-1" ]]; then
    REGION="$PARAM_REGION"
  fi
else
  PROJECT_NAME="serverless-crud-api"
fi

STACK_NAME="$PROJECT_NAME-$STAGE-api"

# Validate stage
case $STAGE in
  dev|staging|prod)
    echo "🔑 Getting API details for $STAGE environment in $REGION..."
    ;;
  *)
    echo "❌ Invalid stage: $STAGE. Use: dev, staging, or prod"
    exit 1
    ;;
esac

API_URL=$(aws cloudformation describe-stacks --stack-name $STACK_NAME \
  --region "$REGION" \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' --output text)

API_KEY_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME \
  --region "$REGION" \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiKeyId`].OutputValue' --output text)

API_KEY=$(aws apigateway get-api-key --api-key $API_KEY_ID --include-value \
  --region "$REGION" --query 'value' --output text)

echo ""
echo "📡 API URL: $API_URL"
echo "🔑 API Key: $API_KEY"
echo ""
echo "Test with:"
echo "curl -X GET $API_URL/items/test-id -H 'X-API-Key: $API_KEY'"