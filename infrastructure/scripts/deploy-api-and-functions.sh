#!/bin/bash

# Deploy API Gateway and Lambda Functions Stack (Combined)
set -e

# Default values
STAGE="dev"
REGION="us-east-1"
PROJECT_NAME="serverless-crud-api"
ENABLE_API_KEY="false"
API_KEY_NAME=""

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
    --enable-api-key)
      ENABLE_API_KEY="true"
      shift 1
      ;;
    --api-key-name)
      API_KEY_NAME="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  -s, --stage STAGE        Deployment stage (dev, staging, prod) [default: dev]"
      echo "  -r, --region REGION      AWS region [default: us-east-1]"
      echo "  -p, --project-name NAME  Project name [default: serverless-crud-api]"
      echo "  --enable-api-key         Enable API key authentication [default: false]"
      echo "  --api-key-name NAME      Custom API key name (optional)"
      echo "  -h, --help               Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

STACK_NAME="$PROJECT_NAME-$STAGE-api"
FOUNDATION_STACK="$PROJECT_NAME-$STAGE-foundation"

echo "🌐⚡ Deploying API Gateway and Lambda Functions Stack"
echo "Stack Name: $STACK_NAME"
echo "Foundation Stack: $FOUNDATION_STACK"
echo "Stage: $STAGE"
echo "Region: $REGION"
echo ""

# Check if foundation stack exists
if ! aws cloudformation describe-stacks --stack-name "$FOUNDATION_STACK" --region "$REGION" > /dev/null 2>&1; then
  echo "❌ Foundation stack '$FOUNDATION_STACK' not found. Please deploy it first:"
  echo "   ./deploy-foundation.sh --stage $STAGE --region $REGION"
  exit 1
fi

# Navigate to infrastructure directory
cd "$(dirname "$0")/.."

# Build Go functions
echo "🔨 Building Go functions..."
cd ../functions/create-item
go mod tidy
GOOS=linux GOARCH=amd64 go build -o bootstrap main.go logger.go
cd ../delete-item
go mod tidy
GOOS=linux GOARCH=amd64 go build -o bootstrap main.go logger.go

# Install Node.js dependencies
echo "📦 Installing Node.js dependencies..."
cd ../get-item
npm install --production
cd ../update-item
npm install --production

# Return to infrastructure directory
cd ../../infrastructure

# Build and deploy combined API and functions stack
echo "🔨 Building API and Functions stack..."
sam build --template-file stacks/02-api-and-functions.yaml

echo "🚀 Deploying API and Functions stack..."
# Prepare parameter overrides
PARAMETERS="FoundationStackName=$FOUNDATION_STACK EnableApiKeyAuth=$ENABLE_API_KEY"
if [[ -n "$API_KEY_NAME" ]]; then
  PARAMETERS="$PARAMETERS ApiKeyName=$API_KEY_NAME"
fi

sam deploy \
  --template-file .aws-sam/build/template.yaml \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    $PARAMETERS \
  --resolve-s3 \
  --no-confirm-changeset \
  --no-fail-on-empty-changeset \
  --tags \
    Project="$PROJECT_NAME" \
    Stage="$STAGE" \
    Component="API"

# Get stack outputs
echo ""
echo "📋 API and Functions Stack Outputs:"
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
  --output table

echo ""
echo "✅ API and Functions stack deployed successfully!"
echo "Stack Name: $STACK_NAME"