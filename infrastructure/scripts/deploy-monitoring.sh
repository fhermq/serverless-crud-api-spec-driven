#!/bin/bash

# Deploy Monitoring Stack
set -e

# Default values
STAGE="dev"
REGION="us-east-1"
PROJECT_NAME="serverless-crud-api"

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
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  -s, --stage STAGE        Deployment stage (dev, staging, prod) [default: dev]"
      echo "  -r, --region REGION      AWS region [default: us-east-1]"
      echo "  -p, --project-name NAME  Project name [default: serverless-crud-api]"
      echo "  -h, --help               Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

STACK_NAME="$PROJECT_NAME-$STAGE-monitoring"
FOUNDATION_STACK="$PROJECT_NAME-$STAGE-foundation"
API_STACK="$PROJECT_NAME-$STAGE-api"

echo "📊 Deploying Monitoring Stack"
echo "Stack Name: $STACK_NAME"
echo "Foundation Stack: $FOUNDATION_STACK"
echo "API Stack: $API_STACK"
echo "Stage: $STAGE"
echo "Region: $REGION"
echo ""

# Check if prerequisite stacks exist
for stack in "$FOUNDATION_STACK" "$API_STACK"; do
  if ! aws cloudformation describe-stacks --stack-name "$stack" --region "$REGION" > /dev/null 2>&1; then
    echo "❌ Required stack '$stack' not found. Please deploy all prerequisite stacks first."
    exit 1
  fi
done

# Navigate to infrastructure directory
cd "$(dirname "$0")/.."

# Build and deploy monitoring stack
echo "🔨 Building Monitoring stack..."
sam build --template-file stacks/03-monitoring.yaml

echo "🚀 Deploying Monitoring stack..."
sam deploy \
  --template-file .aws-sam/build/template.yaml \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    "FoundationStackName=$FOUNDATION_STACK" \
    "ApiStackName=$API_STACK" \
  --no-confirm-changeset \
  --no-fail-on-empty-changeset \
  --tags \
    Project="$PROJECT_NAME" \
    Stage="$STAGE" \
    Component="Monitoring"

# Get stack outputs
echo ""
echo "📋 Monitoring Stack Outputs:"
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
  --output table

echo ""
echo "✅ Monitoring stack deployed successfully!"
echo "Stack Name: $STACK_NAME"